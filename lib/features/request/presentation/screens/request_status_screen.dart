import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/navigation/app_flows.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../state/request_dependencies.dart';
import '../../../offers/presentation/state/offers_dependencies.dart';
import '../../../messages/presentation/state/messages_dependencies.dart';
import '../../../tracking/presentation/screens/tracking_screen.dart';
import '../../../support/presentation/screens/support_screen.dart';
import 'request_form_screen.dart';

class RequestStatusScreen extends StatefulWidget {
  const RequestStatusScreen({this.latitude, this.longitude, super.key});

  final double? latitude;
  final double? longitude;

  @override
  State<RequestStatusScreen> createState() => _RequestStatusScreenState();
}

class _RequestStatusScreenState extends State<RequestStatusScreen>
    with TickerProviderStateMixin {
  final RealtimeService _realtime = RealtimeService.instance;
  bool _loading = true;
  bool _updatingBudget = false;
  String? _error;
  String? _infoMessage;

  Map<String, dynamic>? _request;
  List<dynamic> _offers = const [];
  int _offerLifetimeSeconds = 120;

  double _currentBudget = 0;
  double _draftBudget = 0;
  String _sortBy = 'recent';

  // Animación de ondas radar
  late final AnimationController _radarCtrl;
  late final List<Animation<double>> _radarWaves;

  Timer? _ticker;

  // Animación de ruta ping
  late final AnimationController _routeCtrl;
  int _currentWorkerIndex = 0;
  bool _isWorkerThinking = false;
  List<LatLng> _workerLocations = [];
  List<LatLng> _currentRoutePoints = [];

  @override
  void initState() {
    super.initState();

    // Radar: 3 ondas con delay escalonado
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _radarWaves = List.generate(3, (i) {
      final start = i * 0.25;
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _radarCtrl,
          curve: Interval(
            start,
            (start + 0.75).clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        ),
      );
    });

    final userId = SessionStore.currentUser?.id;
    _realtime.connect(userId: userId);
    _realtime.on('offer.new', _onOfferEvent);
    _realtime.on('offer.updated', _onOfferEvent);
    _realtime.on('offer.expired', _onOfferEvent);
    _realtime.on('offer.accepted', _onOfferEvent);
    _realtime.on('offer.client_counter', _onOfferEvent);
    _realtime.on('job.completed', _onJobCompleted);
    _realtime.on('job.cancelled', _onJobCancelled);

    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickCountdown(),
    );

    _routeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    final baseLat = widget.latitude ?? -16.5002;
    final baseLng = widget.longitude ?? -68.1342;
    _workerLocations = [
      LatLng(baseLat + 0.005, baseLng + 0.005),
      LatLng(baseLat - 0.004, baseLng - 0.006),
      LatLng(baseLat - 0.008, baseLng + 0.003),
    ];

    _startPingLoop();
    _load();
  }

  @override
  void dispose() {
    _realtime.off('offer.new', _onOfferEvent);
    _realtime.off('offer.updated', _onOfferEvent);
    _realtime.off('offer.expired', _onOfferEvent);
    _realtime.off('offer.accepted', _onOfferEvent);
    _realtime.off('offer.client_counter', _onOfferEvent);
    _realtime.off('job.completed', _onJobCompleted);
    _realtime.off('job.cancelled', _onJobCancelled);
    _radarCtrl.dispose();
    _routeCtrl.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  Future<List<LatLng>> _fetchRoute(LatLng start, LatLng end) async {
    final token = AppConfig.mapboxAccessToken;
    if (token.isEmpty) return [start, end];
    try {
      final url = 'https://api.mapbox.com/directions/v5/mapbox/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&access_token=$token';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final geometry = routes[0]['geometry'];
          final coordinates = geometry['coordinates'] as List<dynamic>?;
          if (coordinates != null) {
            return coordinates.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
          }
        }
      }
    } catch (_) {}
    return [start, end];
  }

  Future<void> _startPingLoop() async {
    while (mounted) {
      if (_workerLocations.isEmpty) {
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }
      
      final lat = widget.latitude ?? -16.5002;
      final lng = widget.longitude ?? -68.1342;
      final mapCenter = LatLng(lat, lng);
      
      _currentRoutePoints = await _fetchRoute(mapCenter, _workerLocations[_currentWorkerIndex]);
      if (!mounted) return;

      _routeCtrl.reset();
      await _routeCtrl.forward();
      if (!mounted) return;
      setState(() {
        _isWorkerThinking = true;
      });
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return;
      setState(() {
        _isWorkerThinking = false;
        _currentRoutePoints = [];
        _currentWorkerIndex = (_currentWorkerIndex + 1) % _workerLocations.length;
      });
    }
  }

  void _onJobCompleted(dynamic _) {
    AppFlows.goToRating();
  }

  void _onJobCancelled(dynamic _) {
    AppFlows.goHomeAfterCancellation();
  }

  void _onOfferEvent(dynamic payload) => _load();

  void _tickCountdown() {
    if (!mounted || _offers.isEmpty) return;

    final hasPendingOffers = _offers.any((o) {
      final offer = o as Map<String, dynamic>;
      final status = offer['status']?.toString() ?? '';
      final remaining = (offer['secondsRemaining'] as num?)?.toInt();
      return status == 'pending' && remaining != null && remaining > 0;
    });
    if (!hasPendingOffers) return;

    setState(() {
      _offers = _offers
          .map(
            (item) => Map<String, dynamic>.from(item as Map<String, dynamic>),
          )
          .map((offer) {
            final status = offer['status']?.toString() ?? '';
            final remaining = (offer['secondsRemaining'] as num?)?.toInt();
            if (status == 'pending' && remaining != null) {
              offer['secondsRemaining'] = remaining - 1;
            }
            return offer;
          })
          .where((offer) {
            final status = offer['status']?.toString() ?? '';
            final remaining = (offer['secondsRemaining'] as num?)?.toInt();
            if (status != 'pending' || remaining == null) {
              return true;
            }
            return remaining > 0;
          })
          .toList();
    });
  }

  bool _isNoRequestError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('no request found') ||
        normalized.contains('requestid or clientuserid is required') ||
        normalized.contains('no se encontró la información solicitada');
  }

  Future<void> _syncActiveThreadForAcceptedOffer({
    required String userId,
    required String workerId,
    required String requestId,
  }) async {
    final result = await MessagesDependencies.getActiveThreads(userId: userId);
    final threads = result.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => [],
    );

    for (final thread in threads) {
      if (thread.jobId == requestId && thread.workerId == workerId) {
        SessionStore.activeThreadId = thread.id;
        return;
      }
    }
  }

  Future<void> _load() async {
    final user = SessionStore.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Sesion expirada';
        _loading = false;
      });
      return;
    }

    if (user.type == 'worker') {
      setState(() {
        _loading = false;
        _infoMessage = 'Esta pantalla aplica para clientes.';
        _request = null;
        _offers = const [];
      });
      return;
    }

    if (_request == null) {
      setState(() {
        _loading = true;
        _error = null;
        _infoMessage = null;
      });
    }

    try {
      final response = (await OffersDependencies.getOffers(
        requestId: SessionStore.activeRequestId,
        clientUserId: user.id,
      ))
          .fold(
            onSuccess: (value) => value,
            onFailure: (failure) => throw Exception(failure.message),
          )
          .payload;

      final request = response['request'] as Map<String, dynamic>?;
      if (request != null) {
        SessionStore.activeRequestId = request['id'] as String?;
      }

      final offersList = response['offers'] as List<dynamic>? ?? const [];
      final nearbyWorkers = response['nearbyWorkers'] as List<dynamic>? ?? [];
      final notifiedWorkers = request?['notifiedWorkers'] as List<dynamic>? ?? [];

      // Extraer locaciones reales de donde estén disponibles
      final allWorkers = [...offersList.map((o) => o['worker']), ...nearbyWorkers, ...notifiedWorkers];
      final realLocations = allWorkers.where((w) => w != null).map((w) {
        final loc = w['location'] as Map<String, dynamic>? ?? w;
        final lat = (loc['latitude'] as num?)?.toDouble() ?? (w['latitude'] as num?)?.toDouble();
        final lng = (loc['longitude'] as num?)?.toDouble() ?? (w['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) return LatLng(lat, lng);
        return null;
      }).whereType<LatLng>().toSet().toList(); // toSet() para evitar duplicados

      final currentBudget = (request?['budget'] as num?)?.toDouble() ?? 0;
      final shouldResetDraft =
          _draftBudget <= 0 || _draftBudget < currentBudget;

      if (mounted) {
        setState(() {
          _request = request;
          _offers = offersList;
          if (realLocations.isNotEmpty) {
            _workerLocations = realLocations;
          }
          _offerLifetimeSeconds =
              (response['offerLifetimeSeconds'] as num?)?.toInt() ?? 120;
          _currentBudget = currentBudget;
          if (shouldResetDraft) {
            _draftBudget = currentBudget;
          }
          _loading = false;
        });
      }
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      if (_isNoRequestError(message)) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = null;
            _infoMessage = 'Aun no tienes una solicitud activa.';
            _request = null;
            _offers = const [];
            SessionStore.activeRequestId = null;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _error = message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _acceptOffer({
    required Map<String, dynamic> item,
    required Map<String, dynamic> worker,
  }) async {
    final user = SessionStore.currentUser;
    if (user == null) return;

    (await OffersDependencies.acceptOffer(
      offerId: item['id'] as String,
      clientUserId: user.id,
    )).fold(
      onSuccess: (value) => value,
      onFailure: (failure) => throw Exception(failure.message),
    );

    final requestId = _request?['id']?.toString();
    final workerId = worker['id']?.toString();
    if (requestId != null && workerId != null) {
      SessionStore.activeRequestId = requestId;
      await _syncActiveThreadForAcceptedOffer(
        userId: user.id,
        workerId: workerId,
        requestId: requestId,
      );
    }

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Oferta aceptada')));

    await _load();

    if (!mounted) return;

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TrackingScreen()));
  }

  List<Map<String, dynamic>> _visibleOffers() {
    final list = _offers
        .where((o) {
          final offer = o as Map<String, dynamic>;
          final status = offer['status'] as String?;
          return status != 'declined';
        })
        .map((o) => Map<String, dynamic>.from(o as Map<String, dynamic>))
        .toList();

    if (_sortBy == 'lowest_price') {
      list.sort((a, b) => (double.tryParse(a['amount'].toString()) ?? 0)
          .compareTo(double.tryParse(b['amount'].toString()) ?? 0));
    } else if (_sortBy == 'highest_price') {
      list.sort((a, b) => (double.tryParse(b['amount'].toString()) ?? 0)
          .compareTo(double.tryParse(a['amount'].toString()) ?? 0));
    }
    return list;
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151D29),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Más recientes', style: TextStyle(color: Colors.white)),
                trailing: _sortBy == 'recent' ? const Icon(Icons.check, color: Color(0xFF8A2BE2)) : null,
                onTap: () {
                  setState(() => _sortBy = 'recent');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Menor precio', style: TextStyle(color: Colors.white)),
                trailing: _sortBy == 'lowest_price' ? const Icon(Icons.check, color: Color(0xFF8A2BE2)) : null,
                onTap: () {
                  setState(() => _sortBy = 'lowest_price');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Mayor precio', style: TextStyle(color: Colors.white)),
                trailing: _sortBy == 'highest_price' ? const Icon(Icons.check, color: Color(0xFF8A2BE2)) : null,
                onTap: () {
                  setState(() => _sortBy = 'highest_price');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendImproveOffer() async {
    final user = SessionStore.currentUser;
    final requestId = _request?['id']?.toString();
    if (user == null || requestId == null) return;

    if (_draftBudget <= _currentBudget) {
      final prevDraft = _draftBudget;
      await _editOfferAmount();
      if (_draftBudget == prevDraft) {
        // Usuario canceló o no cambió el valor
        return;
      }
      if (_draftBudget <= _currentBudget) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tu nueva oferta debe ser mayor a Bs ${_currentBudget.toStringAsFixed(0)}',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _updatingBudget = true);
    try {
      (await RequestDependencies.clientCounterOffer(
        requestId: requestId,
        clientUserId: user.id,
        amount: _draftBudget,
      )).fold(
        onSuccess: (_) {},
        onFailure: (failure) => throw Exception(failure.message),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oferta mejorada correctamente')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingBudget = false);
    }
  }

  Future<void> _editOfferAmount() async {
    final controller = TextEditingController(
      text: _draftBudget.toInt().toString(),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar oferta'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(prefixText: 'Bs '),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                Navigator.of(context).pop(parsed);
              },
              child: const Text('Aplicar'),
            ),
          ],
        );
      },
    );

    if (!mounted || value == null || value <= 0) return;

    setState(() {
      _draftBudget = value.floorToDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.latitude ?? -16.5002;
    final lng = widget.longitude ?? -68.1342;
    final mapCenter = LatLng(lat, lng);
    final offers = _visibleOffers();

    return Scaffold(
      backgroundColor: AppTheme.colorBackground,
      body: Stack(
        children: [
          // ── MAPA DE FONDO ──────────────────────────
          Positioned.fill(
            child: AppConfig.mapboxAccessToken.trim().isEmpty
                ? Container(color: AppTheme.colorBackgroundAccent)
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: mapCenter,
                      initialZoom: 14,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
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
                      AnimatedBuilder(
                        animation: _radarCtrl,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _RadarWavePainter(
                              center: mapCenter,
                              waves: _radarWaves.map((a) => a.value).toList(),
                              color: const Color(0xFF8A2BE2),
                            ),
                            size: Size.infinite,
                          );
                        },
                      ),
                      AnimatedBuilder(
                        animation: _routeCtrl,
                        builder: (context, child) {
                          if (_currentRoutePoints.isEmpty) return const SizedBox.shrink();
                          
                          final pointCount = (_currentRoutePoints.length * _routeCtrl.value).ceil();
                          if (pointCount < 2) return const SizedBox.shrink();
                          
                          final visiblePoints = _currentRoutePoints.sublist(0, pointCount);

                          return PolylineLayer(
                            polylines: [
                              Polyline(
                                points: visiblePoints,
                                color: const Color(0xFF8A2BE2),
                                strokeWidth: 3.0,
                              ),
                            ],
                          );
                        },
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: mapCenter,
                            width: 24,
                            height: 24,
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF8A2BE2),
                                ),
                              ),
                            ),
                          ),
                          // Fake worker avatars
                          if (_workerLocations.isNotEmpty)
                            ...List.generate(_workerLocations.length, (index) {
                              final isThisWorkerThinking = _isWorkerThinking && _currentWorkerIndex == index;
                              return Marker(
                                point: _workerLocations[index],
                                width: 44,
                                height: 44,
                                child: _buildMapAvatar('https://i.pravatar.cc/150?img=${11 + index}', isThisWorkerThinking),
                              );
                            }),
                        ],
                      ),
                    ],
                  ),
          ),

          // ── HEADER SUPERIOR ──────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF151D29).withValues(alpha: 0.8),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Buscando trabajadores...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Estamos conectando con los mejores\nperfiles cerca de ti',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SupportScreen(
                              requestId: SessionStore.activeRequestId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.help_outline, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF151D29).withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── BOTTOM SHEET CON LAS OFERTAS ──────────────────────────
          DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.2,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 70,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF151D29),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _loading && offers.isEmpty
                              ? const Center(child: CircularProgressIndicator())
                              : ListView(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'Ofertas recibidas',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8A2BE2)
                                                .withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${offers.length}',
                                            style: const TextStyle(
                                              color: Color(0xFF8A2BE2),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton.icon(
                                          onPressed: _showSortOptions,
                                          icon: const Icon(Icons.tune,
                                              color: Colors.white, size: 16),
                                          label: Text(
                                            _sortBy == 'lowest_price' ? 'Menor precio' : 
                                            _sortBy == 'highest_price' ? 'Mayor precio' : 'Más recientes',
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                          style: TextButton.styleFrom(
                                            backgroundColor: const Color(0xFF1A2436),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Responde y elige la mejor opción',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildBudgetCard(),
                                    const SizedBox(height: 16),
                                    if (offers.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 24),
                                        child: Center(
                                          child: Text(
                                            'Aún no hay ofertas de trabajadores.',
                                            style: TextStyle(color: AppTheme.colorMuted),
                                          ),
                                        ),
                                      )
                                    else
                                      ...offers.map((offer) => _buildOfferItem(offer)),
                                    const SizedBox(height: 24),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.lock_outline,
                                            color: Colors.white.withValues(alpha: 0.5),
                                            size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Tu información está protegida y solo los trabajadores interesados podrán ver tu solicitud.',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.5),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  ),

                  // ── TARJETA FLOTANTE (Sobre el bottom sheet) ──────────────────────────
                  Positioned(
                    top: 0,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2436),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Color(0xFF8A2BE2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.grid_view,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _request?['title']?.toString() ??
                                      'Cargando solicitud...',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_outlined,
                                        color: Colors.white.withValues(alpha: 0.6),
                                        size: 14),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _request?['address']?.toString() ??
                                            'Ubicación actual',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              final description = _request?['description']?.toString() ?? '';
                              final title = _request?['title']?.toString();
                              final address = _request?['address']?.toString();
                              
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => RequestFormScreen(
                                    initialPrompt: description,
                                    initialTitle: title,
                                    initialAddress: address,
                                    initialLatitude: widget.latitude,
                                    initialLongitude: widget.longitude,
                                  ),
                                ),
                              ).then((_) => _load());
                            },
                            icon: const Icon(Icons.edit,
                                size: 14, color: Colors.amber),
                            label: const Text('Editar',
                                style: TextStyle(color: Colors.amber)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF2D2347)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMapAvatar(String url, bool isThinking) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8A2BE2).withValues(alpha: 0.6),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CircleAvatar(
            backgroundImage: NetworkImage(url),
          ),
        ),
        if (isThinking)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: const Text(
                '...',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBudgetCard() {
    final displayBudget = _draftBudget;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2436),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF8A2BE2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu presupuesto',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                ),
                Text(
                  'Bs ${displayBudget.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _updatingBudget ? null : _sendImproveOffer,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.monetization_on_outlined, size: 18, color: Colors.white),
                Positioned(
                  right: -4,
                  top: -2,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF00D26A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
            label: Text(
              _updatingBudget ? '...' : 'Mejorar Oferta',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D26A),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF00D26A).withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferItem(dynamic offerData) {
    final offer = offerData as Map<String, dynamic>;
    final worker = offer['worker'] as Map<String, dynamic>? ?? {};
    final user = worker['user'] as Map<String, dynamic>? ?? {};
    final name = '${user['firstName'] ?? ''} ${(user['lastName']?.toString().isNotEmpty == true) ? user['lastName'].toString()[0] + '.' : ''}'.trim();
    final avatar = user['profileImage']?.toString();
    final amount = offer['amount']?.toString() ?? '0';
    final rating = (worker['rating'] as num?)?.toDouble() ?? 5.0;
    final ratingCount = (worker['ratingCount'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2436),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey[800],
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            child: avatar == null
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name.isEmpty ? 'Usuario' : name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, color: Color(0xFF8A2BE2), size: 16),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${rating.toStringAsFixed(1)} ($ratingCount)',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Puede comenzar hoy',
                  style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Bs $amount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF263346),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    child: const Text('Ver perfil',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _acceptOffer(item: offer, worker: worker),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8A2BE2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    child: const Text('Aceptar', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pinta las ondas de radar sobre el mapa usando coordenadas de pantalla
class _RadarWavePainter extends CustomPainter {
  _RadarWavePainter({
    required this.center,
    required this.waves,
    required this.color,
  });

  final LatLng center;
  final List<double> waves;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxRadius = size.width * 0.45;

    for (final t in waves) {
      if (t <= 0) continue;
      final radius = maxRadius * t;
      final opacity = (1 - t).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RadarWavePainter old) => true;
}
