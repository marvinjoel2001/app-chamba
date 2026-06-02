import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/services/worker_background_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../messages/presentation/screens/messages_screen.dart';
import '../../../offers/presentation/screens/counter_offer_screen.dart';
import '../../../worker/presentation/screens/verification_checkpoint_screen.dart';
import '../state/request_dependencies.dart';
import 'job_in_progress_screen.dart';

class IncomingRequestScreen extends StatefulWidget {
  const IncomingRequestScreen({this.isActive = true, super.key});

  final bool isActive;

  @override
  State<IncomingRequestScreen> createState() => _IncomingRequestScreenState();
}

class _IncomingRequestScreenState extends State<IncomingRequestScreen>
    with SingleTickerProviderStateMixin {
  final RealtimeService _realtime = RealtimeService.instance;
  final MapController _mapController = MapController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];
  int _offerLifetimeSeconds = 120;
  Timer? _ticker;
  Timer? _pollTimer;
  LatLng? _workerLocation;
  StreamSubscription<Position>? _locationStreamSubscription;
  bool _available = true; // se actualiza desde la DB en _initLocation
  bool _togglingAvailability = false;

  // El cliente hizo una contraoferta al worker
  bool _clientCountered = false;

  // AnimaciÃ³n banner oferta aceptada
  bool _showAcceptedBanner = false;
  late final AnimationController _acceptedAnimCtrl;
  late final Animation<double> _acceptedScale;
  late final Animation<double> _acceptedOpacity;

  // DraggableScrollableController para el bottom sheet
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();

  // Filtros de bÃºsqueda
  String? _selectedCategory;
  String? _selectedModality; // 'hourly', 'daily', 'full'
  final List<String> _categories = [
    'Limpieza',
    'JardinerÃ­a',
    'PlomerÃ­a',
    'Electricidad',
    'Pintura',
    'Mudanza',
    'CarpinterÃ­a',
    'AlbaÃ±ilerÃ­a'
  ];
  final List<Map<String, String>> _modalities = [
    {'value': 'hourly', 'label': 'Por hora'},
    {'value': 'daily', 'label': 'Por dÃ­a'},
    {'value': 'full', 'label': 'Precio fijo'},
  ];

  bool get _isVerified {
    final user = SessionStore.currentUser;
    if (user == null) return false;
    return user.verificationStatus == 'verified' ||
        (user.idPhotoVerified == true && user.facePhotoVerified == true);
  }

  void _showVerificationRequired() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.colorBackgroundAccent,
        title: const Row(
          children: [
            Icon(Icons.verified_user, color: AppTheme.colorPrimary),
            SizedBox(width: 8),
            Text('VerificaciÃ³n requerida'),
          ],
        ),
        content: const Text(
          'Debes verificar tu identidad para poder aceptar o ofertar en solicitudes.',
          style: TextStyle(color: AppTheme.colorMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const VerificationCheckpointScreen(),
                ),
              );
            },
            child: const Text(
              'Verificar',
              style: TextStyle(color: AppTheme.colorPrimary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _acceptedAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _acceptedScale = CurvedAnimation(
      parent: _acceptedAnimCtrl,
      curve: Curves.elasticOut,
    );
    _acceptedOpacity = CurvedAnimation(
      parent: _acceptedAnimCtrl,
      curve: Curves.easeIn,
    );

    final userId = SessionStore.currentUser?.id;
    _realtime.connect(userId: userId);
    _realtime.on('request.new', _onNewRequest);
    _realtime.on('offer.updated', _onRequestUpdated);
    _realtime.on('offer.client_counter', _onClientCounter);
    _realtime.on('offer.accepted', _onOfferAccepted);
    _realtime.on('offer.rejected', _onOfferRejected);
    _realtime.on('offer.expired', _onOfferExpired);
    _realtime.on('job.completed', _onJobCompleted);
    _realtime.on('job.cancelled', _onJobCancelled);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.isActive) _tickOfferCountdown();
    });
    // Polling silencioso â€” no muestra spinner
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && widget.isActive) _load(silent: true);
    });

    _startLocationStream();
    _load();
  }

  @override
  void dispose() {
    _realtime.off('request.new', _onNewRequest);
    _realtime.off('offer.updated', _onRequestUpdated);
    _realtime.off('offer.client_counter', _onClientCounter);
    _realtime.off('offer.accepted', _onOfferAccepted);
    _realtime.off('offer.rejected', _onOfferRejected);
    _realtime.off('offer.expired', _onOfferExpired);
    _realtime.off('job.completed', _onJobCompleted);
    _realtime.off('job.cancelled', _onJobCancelled);
    _ticker?.cancel();
    _pollTimer?.cancel();
    _locationStreamSubscription?.cancel();
    _acceptedAnimCtrl.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(IncomingRequestScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _load(silent: true);
    }
  }

  Future<void> _startLocationStream() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      await _locationStreamSubscription?.cancel();

      _locationStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position pos) async {
        if (!mounted) return;

        final loc = LatLng(pos.latitude, pos.longitude);
        setState(() => _workerLocation = loc);

        try {
          _mapController.move(loc, 14);
        } catch (_) {}

        final user = SessionStore.currentUser;
        if (user != null) {
          (await RequestDependencies.updateWorkerLocation(
            workerUserId: user.id,
            latitude: pos.latitude,
            longitude: pos.longitude,
          ))
              .fold(
            onSuccess: (value) => value,
            onFailure: (failure) => throw Exception(failure.message),
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _toggleAvailability(bool value) async {
    final user = SessionStore.currentUser;
    if (user == null || _togglingAvailability) return;
    setState(() {
      _togglingAvailability = true;
      _available = value;
      if (!value) {
        // Al marcar OCUPADO ocultamos inmediatamente solicitudes/ofertas.
        _requests = [];
        _clientCountered = false;
        _showAcceptedBanner = false;
        _error = null;
      }
    });
    try {
      (await RequestDependencies.setAvailability(
        workerUserId: user.id,
        available: value,
      ))
          .fold(
        onSuccess: (value) => value,
        onFailure: (failure) => throw Exception(failure.message),
      );
      await WorkerBackgroundService.setEnabled(value);
      if (mounted && value) {
        await _load(silent: true);
      }
    } catch (_) {
      if (mounted) setState(() => _available = !value);
    } finally {
      if (mounted) setState(() => _togglingAvailability = false);
    }
  }

  void _showFilterModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.8,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0D1728),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.colorMuted.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // TÃ­tulo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filtrar trabajos',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedCategory = null;
                              _selectedModality = null;
                            });
                            setState(() {
                              _selectedCategory = null;
                              _selectedModality = null;
                            });
                            Navigator.of(context).pop();
                            _load(silent: true);
                          },
                          child: const Text(
                            'Limpiar',
                            style: TextStyle(color: AppTheme.colorHighlight),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // CategorÃ­as
                    const Text(
                      'CategorÃ­a',
                      style: TextStyle(
                        color: AppTheme.colorMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((category) {
                        final isSelected = _selectedCategory == category;
                        return ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              _selectedCategory = selected ? category : null;
                            });
                          },
                          selectedColor: AppTheme.colorPrimary.withOpacity(0.3),
                          backgroundColor: AppTheme.colorSurfaceSoft,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppTheme.colorPrimaryLight
                                : AppTheme.colorText,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Modalidad
                    const Text(
                      'Modalidad de pago',
                      style: TextStyle(
                        color: AppTheme.colorMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _modalities.map((modality) {
                        final value = modality['value']!;
                        final label = modality['label']!;
                        final isSelected = _selectedModality == value;
                        return ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              _selectedModality = selected ? value : null;
                            });
                          },
                          selectedColor:
                              AppTheme.colorHighlight.withOpacity(0.3),
                          backgroundColor: AppTheme.colorSurfaceSoft,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppTheme.colorHighlight
                                : AppTheme.colorText,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    // BotÃ³n aplicar
                    ChambaPrimaryButton(
                      label: 'Aplicar filtros',
                      icon: Icons.check,
                      onPressed: () {
                        setState(() {
                          // Apply filters to state
                        });
                        Navigator.of(context).pop();
                        _load(silent: true);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _onNewRequest(dynamic payload) => _load(silent: true);

  void _onJobCompleted(dynamic _) {
    SessionStore.activeRequestId = null;
    SessionStore.activeThreadId = null;
    if (mounted) {
      setState(() {
        _requests.removeWhere((r) => r['status'] == 'completed');
      });
    }
  }

  void _showJobDetails(Map<String, dynamic> req) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JobDetailsSheet(requestData: req),
    );
  }

  void _onJobCancelled(dynamic payload) {
    SessionStore.activeRequestId = null;
    SessionStore.activeThreadId = null;
    if (mounted) {
      setState(() {
        _requests.removeWhere((r) => r['status'] == 'cancelled');
      });
      // Banner rojo de cancelaciÃ³n
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.cancel, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'El cliente cancelÃ³ el trabajo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.colorError,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _onRequestUpdated(dynamic payload) {
    final userId = SessionStore.currentUser?.id;
    final map = payload is Map ? Map<String, dynamic>.from(payload) : const {};
    if (map['workerUserId'] != null &&
        map['workerUserId'].toString() != userId) {
      return;
    }
    _load(silent: true);
  }

  void _onClientCounter(dynamic payload) {
    final map = payload is Map ? Map<String, dynamic>.from(payload) : const {};
    final eventRequestId = map['requestId']?.toString();
    final newBudget = (map['newBudget'] as num?)?.toDouble();
    final currentRequestId = SessionStore.activeRequestId;
    if (eventRequestId != null &&
        currentRequestId != null &&
        eventRequestId != currentRequestId) {
      return;
    }
    if (mounted) {
      setState(() {
        _clientCountered = true;
        final currentIdx = _requests.indexWhere((r) => r['id']?.toString() == eventRequestId);
        if (currentIdx != -1) {
          if (newBudget != null) {
            _requests[currentIdx]['budget'] = newBudget;
          }
          _requests[currentIdx]['workerOffer'] = null;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El cliente enviÃ³ una contraoferta')),
      );
    }
    _load(silent: true);
  }

  void _onOfferAccepted(dynamic payload) {
    final userId = SessionStore.currentUser?.id;
    final map = payload is Map ? Map<String, dynamic>.from(payload) : const {};
    if (map['workerUserId'] != null &&
        map['workerUserId'].toString() != userId) {
      return;
    }
    if (mounted) {
      setState(() => _showAcceptedBanner = true);
      _acceptedAnimCtrl.forward(from: 0);
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _showAcceptedBanner = false);
      });
    }
    _load(silent: true);
  }

  void _onOfferRejected(dynamic payload) {
    final userId = SessionStore.currentUser?.id;
    final map = payload is Map ? Map<String, dynamic>.from(payload) : const {};
    if (map['workerUserId']?.toString() != userId) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu oferta no fue seleccionada. Puedes mejorarla.'),
        ),
      );
    }
    _load(silent: true);
  }

  void _onOfferExpired(dynamic payload) {
    final userId = SessionStore.currentUser?.id;
    final map = payload is Map ? Map<String, dynamic>.from(payload) : const {};
    if (map['workerUserId']?.toString() != userId) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu oferta expirÃ³. Puedes mejorarla.')),
      );
    }
    _load(silent: true);
  }

  void _tickOfferCountdown() {
    if (!mounted || !_available || _requests.isEmpty) return;
    
    bool changed = false;
    for (var request in _requests) {
      final offer = request['workerOffer'];
      if (offer is! Map<String, dynamic>) continue;
      if (offer['status']?.toString() != 'pending') continue;
      
      final remaining = (offer['secondsRemaining'] as num?)?.toInt();
      if (remaining == null) continue;
      
      if (remaining <= 1) {
        // Al menos una oferta expirÃ³, recargamos.
        _load();
        return;
      }
      
      offer['secondsRemaining'] = remaining - 1;
      changed = true;
    }
    
    if (changed) {
      setState(() {});
    }
  }

  Map<String, dynamic>? _toMutableRequest(dynamic request) {
    if (request is! Map) return null;
    final mapped = Map<String, dynamic>.from(request);
    final workerOffer = mapped['workerOffer'];
    if (workerOffer is Map) {
      mapped['workerOffer'] = Map<String, dynamic>.from(workerOffer);
    }
    return mapped;
  }

  Future<void> _load({bool silent = false}) async {
    final user = SessionStore.currentUser;
    if (user == null) {
      setState(() {
        _error = 'SesiÃ³n expirada';
        _loading = false;
      });
      return;
    }
    if (!_available) {
      if (mounted) {
        setState(() {
          _clientCountered = false;
          _loading = false;
          _error = null;
        });
      }
      return;
    }
    // Solo mostrar spinner en la carga inicial, no en polling silencioso
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response =
          (await RequestDependencies.getIncomingRequest(workerUserId: user.id))
              .fold(
                onSuccess: (value) => value,
                onFailure: (failure) => throw Exception(failure.message),
              )
              .payload;
              
      final rawRequests = response['requests'] as List<dynamic>? ?? [];
      final List<Map<String, dynamic>> fetchedRequests = [];
      
      for (final req in rawRequests) {
        final mutableReq = _toMutableRequest(req);
        if (mutableReq != null) {
          fetchedRequests.add(mutableReq);
        }
      }
      
      // Filtrar completados o cancelados
      fetchedRequests.removeWhere((r) {
        final st = r['status']?.toString();
        return st == 'completed' || st == 'cancelled';
      });
      
      // Chequear si alguna oferta fue aceptada
      bool anyAccepted = false;
      for (final req in fetchedRequests) {
        final offerStatus = (req['workerOffer'] as Map?)?['status']?.toString();
        if (offerStatus == 'accepted') {
          anyAccepted = true;
          SessionStore.activeRequestId = req['id']?.toString();
          break;
        }
      }
      
      if (anyAccepted && !_showAcceptedBanner && mounted) {
        setState(() => _showAcceptedBanner = true);
        _acceptedAnimCtrl.forward(from: 0);
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() => _showAcceptedBanner = false);
        });
      }
      
      if (anyAccepted && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _sheetCtrl.isAttached) {
            _sheetCtrl.animateTo(
              0.35,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
            );
          }
        });
      }
      
      if (mounted) {
        setState(() {
          _requests = fetchedRequests;
          _offerLifetimeSeconds =
              (response['offerLifetimeSeconds'] as num?)?.toInt() ?? 120;
          // _clientCountered logic has to be more specific, keeping it false here for simplicity unless handled by event
          _clientCountered = false; 
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _openJobInProgress(String requestId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JobInProgressScreen(requestId: requestId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapCenter = _workerLocation ?? const LatLng(-16.5002, -68.1342);

    return Scaffold(
      backgroundColor: AppTheme.colorBackground,
      body: Stack(
        children: [
          // â”€â”€ MAPA DE FONDO â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Positioned.fill(
            child: AppConfig.mapboxAccessToken.trim().isEmpty
                ? Container(
                    color: AppTheme.colorBackgroundAccent,
                    child: const Center(
                      child: Text(
                        'Configura MAPBOX_ACCESS_TOKEN\npara ver el mapa',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.colorMuted),
                      ),
                    ),
                  )
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: mapCenter,
                      initialZoom: 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
                        userAgentPackageName: 'com.example.mobile',
                        additionalOptions: {
                          'accessToken': AppConfig.mapboxAccessToken,
                        },
                      ),
                      // Marcador del worker (punto azul)
                      if (_workerLocation != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _workerLocation!,
                              width: 48,
                              height: 48,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blue.shade600,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withValues(alpha: 0.5),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),

          // â”€â”€ BARRA SUPERIOR: disponibilidad â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Toggle centrado
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.colorGlassDarkSoft,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: AppTheme.colorGlassBorderSoft,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _AvailabilityLabel(
                            label: 'DISPONIBLE',
                            active: _available,
                            activeColor: AppTheme.colorSuccess,
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: _togglingAvailability
                                ? null
                                : () => _toggleAvailability(!_available),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 44,
                              height: 26,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(13),
                                color: _available
                                    ? AppTheme.colorSuccess
                                    : AppTheme.colorMuted.withValues(
                                        alpha: 0.4,
                                      ),
                              ),
                              child: AnimatedAlign(
                                duration: const Duration(milliseconds: 250),
                                alignment: _available
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.all(3),
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          _AvailabilityLabel(
                            label: 'OCUPADO',
                            active: !_available,
                            activeColor: AppTheme.colorMuted,
                          ),
                        ],
                      ),
                    ),
                    // BotÃ³n filtros pegado a la derecha
                    Positioned(
                      right: 0,
                      child: Material(
                        color: (_selectedCategory != null ||
                                _selectedModality != null)
                            ? AppTheme.colorPrimary.withOpacity(0.3)
                            : AppTheme.colorGlassDarkSoft,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: _showFilterModal,
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Badge(
                              isLabelVisible: _selectedCategory != null ||
                                  _selectedModality != null,
                              smallSize: 8,
                              child: const Icon(
                                Icons.tune,
                                color: AppTheme.colorText,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // â”€â”€ BOTTOM SHEET DRAGGABLE con solicitudes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: 0.32,
            minChildSize: 0.12,
            maxChildSize: 0.85,
            snap: true,
            snapSizes: const [0.32, 0.85],
            builder: (context, scrollController) {
              final navPadding =
                  92.0 + MediaQuery.viewPaddingOf(context).bottom;
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0D1728),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                // Un Ãºnico ListView con el scrollController del sheet.
                // Esto hace que arrastrar desde cualquier parte expanda el sheet.
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  physics: const ClampingScrollPhysics(),
                  children: [
                    // â”€â”€ Handle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.colorMuted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // â”€â”€ Contenido â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    if (_loading && _requests.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null && _requests.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(child: Text(_error!)),
                      )
                    else if (_requests.isEmpty)
                      _buildEmptyContent(navPadding)
                    else
                      Padding(
                        padding: EdgeInsets.only(bottom: navPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              child: Row(
                                children: [
                                  const Text(
                                    'Solicitudes disponibles',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.colorPrimary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_requests.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _requests.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final req = _requests[index];
                                final workerOffer = req['workerOffer'] as Map<String, dynamic>?;
                                final offerStatus = workerOffer?['status']?.toString();
                                final secondsRemaining = (workerOffer?['secondsRemaining'] as num?)?.toInt();
                                final hasPendingOffer = offerStatus == 'pending';
                                final isAcceptedOffer = offerStatus == 'accepted';
                                return _buildRequestCard(
                                  req: req,
                                  workerOffer: workerOffer,
                                  offerStatus: offerStatus,
                                  secondsRemaining: secondsRemaining,
                                  hasPendingOffer: hasPendingOffer,
                                  isAcceptedOffer: isAcceptedOffer,
                                  clientCountered: false, // You can enhance this if needed
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // â”€â”€ BANNER OFERTA ACEPTADA â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (_showAcceptedBanner)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 70, 16, 0),
                  child: ScaleTransition(
                    scale: _acceptedScale,
                    child: FadeTransition(
                      opacity: _acceptedOpacity,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.colorSuccess,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.colorSuccess.withValues(
                                alpha: 0.45,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Â¡Oferta aceptada!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'El cliente aceptÃ³ tu oferta. DirÃ­gete a la ubicaciÃ³n.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                              onPressed: () =>
                                  setState(() => _showAcceptedBanner = false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyContent(double bottomPadding) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, color: AppTheme.colorMuted, size: 48),
          const SizedBox(height: 12),
          const Text(
            'No hay solicitudes cercanas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.colorText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _available
                ? 'EstÃ¡s disponible. Las solicitudes aparecerÃ¡n aquÃ­.'
                : 'EstÃ¡s ocupado. Activa disponibilidad para recibir trabajos.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.colorMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard({
    required Map<String, dynamic> req,
    required Map<String, dynamic>? workerOffer,
    required String? offerStatus,
    required int? secondsRemaining,
    required bool hasPendingOffer,
    required bool isAcceptedOffer,
    required bool clientCountered,
  }) {
    final offerProgress = secondsRemaining == null
        ? null
        : (secondsRemaining / _offerLifetimeSeconds).clamp(0.0, 1.0).toDouble();

    final distanceText = req['distanceKm'] == null
        ? null
        : '${(req['distanceKm'] as num).toStringAsFixed(1)} km';

    final currentBudget = (req['budget'] as num?)?.toDouble() ?? 0;
    final myOfferAmount = (workerOffer?['amount'] as num?)?.toDouble();

    final isDeclinedOffer = offerStatus == 'declined';

    final clientImproved = hasPendingOffer &&
        !isDeclinedOffer &&
        myOfferAmount != null &&
        currentBudget > myOfferAmount;
    
    final client = req['client'] as Map<String, dynamic>? ?? {};
    final clientName = client['name']?.toString() ?? 'Cliente';
    final clientPhoto = client['profilePhotoUrl']?.toString();
    final clientRating = (client['rating'] as num?)?.toDouble() ?? 0.0;
    final clientReviews = (client['reviews'] as num?)?.toInt() ?? 0;
    final isVerified = client['isVerified'] == true;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.colorSurfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.colorGlassBorderSoft),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.colorBackgroundAccent,
                backgroundImage: clientPhoto != null ? NetworkImage(clientPhoto) : null,
                child: clientPhoto == null
                    ? const Icon(Icons.person, color: AppTheme.colorMuted)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            clientName,
                            style: const TextStyle(
                              color: AppTheme.colorText,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: AppTheme.colorPrimary, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '$clientRating ($clientReviews)',
                          style: const TextStyle(color: AppTheme.colorMuted, fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isVerified ? '| Cliente verificado' : '| Nuevo cliente',
                          style: const TextStyle(color: AppTheme.colorMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppTheme.colorMuted),
                color: AppTheme.colorSurfaceSoft,
                onSelected: (val) {
                  final reqId = req['id'].toString();
                  final clientId = client['id'].toString();
                  if (val == 'dismiss') {
                    _dismissRequest(reqId);
                  } else if (val == 'block') {
                    _blockClient(clientId);
                  } else if (val == 'report') {
                    _reportRequest(reqId);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'dismiss',
                    child: Text('No me interesa', style: TextStyle(color: AppTheme.colorText)),
                  ),
                  const PopupMenuItem(
                    value: 'block',
                    child: Text('Bloquear cliente', style: TextStyle(color: AppTheme.colorText)),
                  ),
                  const PopupMenuItem(
                    value: 'report',
                    child: Text('Reportar publicaciÃ³n', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req['title']?.toString() ?? 'Sin tÃ­tulo',
                      style: const TextStyle(
                        color: AppTheme.colorText,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      req['description']?.toString() ?? 'Sin descripciÃ³n',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.colorMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Presupuesto',
                    style: TextStyle(color: AppTheme.colorMuted, fontSize: 12),
                  ),
                  Text(
                    'Bs. $currentBudget',
                    style: const TextStyle(
                      color: AppTheme.colorPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on, color: AppTheme.colorMuted, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  req['address']?.toString() ?? 'DirecciÃ³n no disponible',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.colorText, fontSize: 14),
                ),
              ),
              if (distanceText != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.colorBackgroundAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_walk, color: AppTheme.colorPrimary, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        distanceText,
                        style: const TextStyle(color: AppTheme.colorText, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showJobDetails(req),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.colorText,
                side: const BorderSide(color: AppTheme.colorGlassBorderSoft),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Ver detalles del trabajo'),
            ),
          ),
          if (isAcceptedOffer) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openJobInProgress(req['id'].toString()),
                icon: const Icon(Icons.directions_car),
                label: const Text('Ver Trabajo'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _openChat(req['id'].toString()),
                icon: const Icon(Icons.chat),
                label: const Text('Ir al Chat'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            if (hasPendingOffer && !clientImproved)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.colorBackgroundAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tu oferta', style: TextStyle(color: AppTheme.colorMuted)),
                        Text('Bs. $myOfferAmount', style: const TextStyle(color: AppTheme.colorText, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (offerProgress != null)
                      LinearProgressIndicator(
                        value: offerProgress,
                        backgroundColor: AppTheme.colorSurfaceSoft,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          offerProgress < 0.2 ? Colors.red : AppTheme.colorPrimary,
                        ),
                      ),
                  ],
                ),
              )
            else if (isDeclinedOffer)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Oferta declinada', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          Text('El cliente declinÃ³ tu oferta de Bs. $myOfferAmount', style: const TextStyle(color: AppTheme.colorMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showCounterOfferSheet(req['id'].toString()),
                      child: const Text('Reofertar', style: TextStyle(color: AppTheme.colorPrimary)),
                    ),
                  ],
                ),
              )
            else ...[
              if (clientImproved)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.colorPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.colorPrimary),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up, color: AppTheme.colorPrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Â¡El cliente subiÃ³ el presupuesto a Bs. $currentBudget!',
                          style: const TextStyle(color: AppTheme.colorPrimary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _dismissRequest(req['id'].toString()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                      child: const Text('No me interesa'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _acceptBudget(req['id'].toString(), currentBudget),
                      child: const Text('Aceptar trabajo'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _showCounterOfferSheet(req['id'].toString()),
                  icon: const Icon(Icons.handshake),
                  label: const Text('Proponer otro precio', style: TextStyle(color: AppTheme.colorPrimary)),
                ),
              ),
            ]
          ],
        ],
      ),
    );
  }

  void _dismissRequest(String requestId) async {
    final user = SessionStore.currentUser;
    if (user == null) return;
    try {
      await RequestDependencies.dismissRequest(
        requestId: requestId,
        workerUserId: user.id,
      );
      setState(() {
        _requests.removeWhere((r) => r['id'].toString() == requestId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud descartada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _blockClient(String clientUserId) async {
    final user = SessionStore.currentUser;
    if (user == null) return;
    try {
      await RequestDependencies.blockClient(
        workerUserId: user.id,
        clientUserId: clientUserId,
      );
      setState(() {
        _requests.removeWhere((r) => (r['client'] as Map?)?['id'].toString() == clientUserId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente bloqueado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _reportRequest(String requestId) {
    final TextEditingController reasonCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.colorSurfaceSoft,
        title: const Text('Reportar publicaciÃ³n', style: TextStyle(color: AppTheme.colorText)),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            hintText: 'Motivo del reporte...',
            filled: true,
            fillColor: AppTheme.colorBackgroundAccent,
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.colorMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final user = SessionStore.currentUser;
              if (user == null) return;
              try {
                await RequestDependencies.reportRequest(
                  requestId: requestId,
                  reporterUserId: user.id,
                  reason: reasonCtrl.text,
                );
                setState(() {
                  _requests.removeWhere((r) => r['id'].toString() == requestId);
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PublicaciÃ³n reportada')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Reportar'),
          ),
        ],
      ),
    );
  }

  void _acceptBudget(String requestId, double budget) async {
    if (!_isVerified) {
      _showVerificationRequired();
      return;
    }
    final user = SessionStore.currentUser;
    if (user == null) return;
    try {
      (await RequestDependencies.createCounterOffer(
        requestId: requestId,
        workerUserId: user.id,
        amount: budget,
        message: 'Acepto el precio ofertado.',
      ))
          .fold(
        onSuccess: (value) => value,
        onFailure: (failure) => throw Exception(failure.message),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oferta enviada')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  void _showCounterOfferSheet(String requestId) async {
    if (!_isVerified) {
      _showVerificationRequired();
      return;
    }
    final req = _requests.firstWhere((r) => r['id'].toString() == requestId);
    final currentBudget = (req['budget'] as num?)?.toDouble() ?? 0;
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CounterOfferScreen(
          requestId: requestId,
          originalBudget: currentBudget,
          requestData: req,
        ),
      ),
    );
    if (sent == true && mounted) {
      setState(() => _clientCountered = false);
      await _load(silent: true);
    }
  }

  void _openChat(String requestId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const MessagesScreen(),
      ),
    );
  }

}


class _AvailabilityLabel extends StatelessWidget {
  const _AvailabilityLabel({
    required this.label,
    required this.active,
    required this.activeColor,
  });

  final String label;
  final bool active;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        label,
        style: TextStyle(
          color:
              active ? activeColor : AppTheme.colorMuted.withValues(alpha: 0.5),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// â”€â”€ Modal de detalles del trabajo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _JobDetailsSheet extends StatelessWidget {
  const _JobDetailsSheet({required this.requestData});

  final Map<String, dynamic> requestData;

  @override
  Widget build(BuildContext context) {
    final title = requestData['title']?.toString() ?? 'Solicitud';
    final description = requestData['description']?.toString() ?? '';
    final address = requestData['address']?.toString() ?? '';
    final budget = requestData['budget'];
    final category = requestData['category']?.toString() ?? '';
    final photos = requestData['photos'] as List<dynamic>? ?? const [];
    final client = requestData['client'] as Map<String, dynamic>?;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1728),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.colorMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // TÃ­tulo
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),

              // CategorÃ­a + presupuesto
              Row(
                children: [
                  if (category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.colorPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: AppTheme.colorPrimaryLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (budget != null)
                    Text(
                      'Bs $budget',
                      style: const TextStyle(
                        color: AppTheme.colorHighlight,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // DescripciÃ³n
              if (description.isNotEmpty) ...[
                const Text(
                  'DescripciÃ³n',
                  style: TextStyle(
                    color: AppTheme.colorMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // DirecciÃ³n
              if (address.isNotEmpty) ...[
                const Text(
                  'DirecciÃ³n',
                  style: TextStyle(
                    color: AppTheme.colorMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: AppTheme.colorPrimary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Cliente
              if (client != null) ...[
                const Text(
                  'Cliente',
                  style: TextStyle(
                    color: AppTheme.colorMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: client['profilePhotoUrl'] != null
                          ? NetworkImage(client['profilePhotoUrl'] as String)
                          : null,
                      child: client['profilePhotoUrl'] == null
                          ? Text(
                              (client['firstName'] as String? ?? 'C')
                                  .substring(0, 1)
                                  .toUpperCase(),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${client['firstName'] ?? ''} ${client['lastName'] ?? ''}'
                          .trim(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Fotos
              if (photos.isNotEmpty) ...[
                const Text(
                  'Fotos',
                  style: TextStyle(
                    color: AppTheme.colorMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    itemBuilder: (context, index) {
                      final photo = photos[index] as Map<String, dynamic>?;
                      final url = photo?['url']?.toString();
                      if (url == null) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: () {
                          // Full screen view
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => Scaffold(
                                backgroundColor: Colors.black,
                                body: SafeArea(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      InteractiveViewer(
                                        child: Image.network(
                                          url,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: IconButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: NetworkImage(url),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
