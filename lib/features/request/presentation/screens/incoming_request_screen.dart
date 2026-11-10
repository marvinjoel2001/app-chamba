import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/services/mobile_backend_service.dart';
import '../../../../core/services/toast_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/services/new_request_alert.dart';
import '../../../../core/services/volume_service.dart';
import '../../../../core/services/worker_background_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/start_date_label.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../../core/widgets/new_request_pulse.dart';
import '../../../offers/presentation/screens/counter_offer_screen.dart';
import '../../../worker/presentation/screens/verification_checkpoint_screen.dart';
import '../state/request_dependencies.dart';
import '../../../../core/utils/job_schedule_format.dart';
import '../widgets/request_extras_widgets.dart';
import 'job_in_progress_screen.dart';
import 'worker_agenda_screen.dart';
import 'worker_agenda_tab.dart';

String _priceTypeLabel(dynamic value) {
  final label = value?.toString().trim() ?? '';
  return switch (label.toLowerCase()) {
    'fixed' => 'Por trabajo',
    'hourly' => 'Por hora',
    'daily' => 'Por día',
    '' => 'Presupuesto',
    _ => label,
  };
}

class IncomingRequestScreen extends StatefulWidget {
  const IncomingRequestScreen(
      {this.isActive = true, this.focusRequestId, super.key});

  final String? focusRequestId;

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
  Timer? _ticker;
  Timer? _pollTimer;
  LatLng? _workerLocation;
  StreamSubscription<Position>? _locationStreamSubscription;
  bool _available = SessionStore.currentUser?.isAvailable ?? true;
  bool _togglingAvailability = false;
  bool _isMapInitialized = false;
  bool _mapReady = false;
  bool _locatingMe = false;

  // El cliente hizo una contraoferta al worker

  // Animación banner oferta aceptada
  bool _showAcceptedBanner = false;
  late final AnimationController _acceptedAnimCtrl;
  late final Animation<double> _acceptedScale;
  late final Animation<double> _acceptedOpacity;

  // DraggableScrollableController para el bottom sheet
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();

  // Filtros de búsqueda
  String? _selectedCategory;
  String? _selectedModality; // 'hourly', 'daily', 'full'

  final Set<String> _notifiedAcceptedRequests = {};
  final Set<String> _pendingDismissIds = {};

  /// Trabajos asignados para otro día (agenda). No bloquean la lista.
  List<Map<String, dynamic>> _scheduledJobs = [];

  /// Gastos de servicio de Chamba sobre la mano de obra (0 por ahora).
  double _serviceFeePercent = 0;

  Future<void> _loadServiceFee() async {
    try {
      final config = await MobileBackendService.instance.serviceFeeConfig();
      final percent = (config['serviceFeePercent'] as num?)?.toDouble() ?? 0;
      if (mounted) setState(() => _serviceFeePercent = percent);
    } catch (_) {
      // Sin dato se muestra como sin gastos; el backend es el que cobra.
    }
  }

  /// Lo que le llega al trabajador de un monto de mano de obra.
  double _netForWorker(double labor) =>
      labor - (labor * _serviceFeePercent / 100);

  void _openAgenda() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkerAgendaScreen(
          jobs: [
            ..._requests.where((r) =>
                (r['workerOffer'] as Map?)?['status'] == 'accepted'),
            ..._scheduledJobs,
          ],
          onOpenJob: _openJobInProgress,
          onOpenChat: _openChat,
        ),
      ),
    );
  }

  bool get hasAcceptedRequest {
    for (final req in _requests) {
      final workerOffer = req['workerOffer'] as Map<String, dynamic>?;
      if (workerOffer?['status'] == 'accepted') return true;
    }
    return false;
  }

  /// Categorías de las solicitudes que el trabajador tiene en la lista. Así el
  /// filtro solo ofrece lo que existe (una lista fija no coincidía con el
  /// catálogo: "Plomería" vs "Plomeria" dejaba la lista vacía).
  List<String> get _categories {
    final byKey = <String, String>{};
    for (final req in _requests) {
      final name = req['category']?.toString().trim() ?? '';
      if (name.isNotEmpty) byKey.putIfAbsent(_categoryKey(name), () => name);
    }
    return byKey.values.toList()..sort();
  }

  /// Precio de la tarjeta: en "por hora" / "por día" la tarifa sale del
  /// presupuesto actual (el cliente pudo subirlo) dividido por horas o días.
  static String _unitPriceLabel(Map<String, dynamic> req, double budget) {
    String bs(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
    final hours = (req['estimatedHours'] as num?)?.toDouble() ?? 0;
    final days = (req['days'] as num?)?.toDouble() ?? 0;
    if (req['modality'] == 'hourly' && hours > 0) {
      return 'Bs. ${bs(budget / hours)}/h';
    }
    if (req['modality'] == 'daily' && days > 0) {
      return 'Bs. ${bs(budget / days)}/día';
    }
    return 'Bs. ${bs(budget)}';
  }

  /// Pestaña de la hoja: `false` = trabajos para hoy, `true` = programados
  /// para otros días.
  bool _showLater = false;

  /// Día en que el cliente quiere que empiece el trabajo (sin hora), o null
  /// si no puso fecha.
  static DateTime? _startDay(Map<String, dynamic> req) {
    final parsed = DateTime.tryParse(req['startDate']?.toString().trim() ?? '');
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// Programado: empieza mañana o después. Sin fecha, o con fecha de hoy o
  /// ya pasada, es un trabajo para hoy.
  static bool _isForLater(Map<String, dynamic> req) {
    final day = _startDay(req);
    if (day == null) return false;
    final now = DateTime.now();
    return day.isAfter(DateTime(now.year, now.month, now.day));
  }

  /// Solicitudes de una pestaña, con los filtros de categoría y modalidad.
  /// Las de hoy conservan el orden del servidor (más cerca primero); las
  /// programadas van por fecha, la más próxima arriba.
  List<Map<String, dynamic>> _requestsFor({required bool later}) {
    final list = _requests.where((req) {
      if (_isForLater(req) != later) return false;
      if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
        if (_categoryKey(req['category']?.toString()) !=
            _categoryKey(_selectedCategory)) {
          return false;
        }
      }
      final mod = req['modality']?.toString();
      if (_selectedModality == 'hourly' && mod != 'hourly') return false;
      if (_selectedModality == 'daily' && mod != 'daily') return false;
      if (_selectedModality == 'full' && mod != 'fixed') return false;
      return true;
    }).toList();
    if (later) {
      // Orden estable: a igual día se mantiene el orden del servidor.
      final order = {for (var i = 0; i < list.length; i++) list[i]: i};
      list.sort((a, b) {
        final byDay = _startDay(a)!.compareTo(_startDay(b)!);
        return byDay != 0 ? byDay : order[a]!.compareTo(order[b]!);
      });
    }
    return list;
  }

  /// La pestaña elegida no tiene solicitudes, pero la otra puede que sí.
  Widget _buildTabEmpty() {
    final other = _requestsFor(later: !_showLater).length;
    final String title;
    final String body;
    if (_showLater) {
      title = 'No hay trabajos programados';
      body =
          'Aquí verás ofertas nuevas para mañana o más adelante. Tus trabajos ya aceptados están en Agenda (arriba a la izquierda).';
    } else {
      title = 'No hay trabajos para hoy';
      body = other == 0
          ? 'Las solicitudes nuevas aparecerán aquí.'
          : other == 1
              ? 'Hay 1 trabajo programado para otro día.'
              : 'Hay $other trabajos programados para otros días.';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      child: Column(
        children: [
          Icon(
            _showLater ? Icons.event_available : Icons.bolt,
            color: AppTheme.colorMuted,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.colorText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.colorMuted, fontSize: 14),
          ),
          if (other > 0) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => setState(() => _showLater = !_showLater),
              child: Text(_showLater ? 'Ver los de hoy' : 'Ver programados'),
            ),
          ],
        ],
      ),
    );
  }

  /// Icono del oficio en la tarjeta. Lo que no se reconoce va con el
  /// genérico de herramientas.
  static IconData _categoryIcon(String? category) {
    final key = _categoryKey(category);
    if (key.contains('pint')) return Icons.format_paint;
    if (key.contains('plom') || key.contains('gasf')) return Icons.plumbing;
    if (key.contains('electr')) return Icons.electrical_services;
    if (key.contains('limp')) return Icons.cleaning_services;
    if (key.contains('jard')) return Icons.yard;
    if (key.contains('carp') || key.contains('mueble')) return Icons.carpenter;
    if (key.contains('mudan') || key.contains('carga')) {
      return Icons.local_shipping;
    }
    if (key.contains('alba') || key.contains('constr')) {
      return Icons.construction;
    }
    if (key.contains('cerraj')) return Icons.key;
    return Icons.handyman;
  }

  /// Hoja de solicitudes abierta del todo: la primera tarjeta entra con sus
  /// botones de ofertar.
  static const double _sheetExpandedSize = 0.85;

  static String _categoryKey(String? value) => (value ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
  final List<Map<String, String>> _modalities = [
    {'value': 'hourly', 'label': 'Por hora'},
    {'value': 'daily', 'label': 'Por día'},
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
            Text('Verificación requerida'),
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

    _loadServiceFee();
    final userId = SessionStore.currentUser?.id;
    _realtime.connect(userId: userId);
    _realtime.on('request.new', _onNewRequest);
    _realtime.reconnectCount.addListener(_onReconnect);
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
    // Polling silencioso — no muestra spinner
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && widget.isActive) _load(silent: true);
    });

    _startLocationStream();
    _load();
  }

  @override
  void dispose() {
    _realtime.reconnectCount.removeListener(_onReconnect);
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
    VolumeService.restoreVolume();
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
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isEnabled) return;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        try {
          perm = await Geolocator.requestPermission();
        } catch (_) {
          return;
        }
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      final initial = await Geolocator.getLastKnownPosition();
      if (!mounted) return;
      if (initial != null)
        setState(() =>
            _workerLocation = LatLng(initial.latitude, initial.longitude));
      _centerMapOnce();
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

        _centerMapOnce();

        final user = SessionStore.currentUser;
        if (user != null) {
          (await RequestDependencies.updateWorkerLocation(
            workerUserId: user.id,
            latitude: pos.latitude,
            longitude: pos.longitude,
          ))
              .fold(
            onSuccess: (value) => value,
            onFailure: (failure) {
              if (mounted) setState(() => _error = failure.message);
              return null;
            },
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _centerOnMyLocation() async {
    if (_locatingMe) return;
    setState(() => _locatingMe = true);
    try {
      LatLng? target = _workerLocation;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        target = LatLng(pos.latitude, pos.longitude);
      } catch (_) {
        // Sin GPS fresco: se usa la última posición conocida del stream.
      }
      if (!mounted) return;
      if (target == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activa el GPS para centrar tu ubicación'),
          ),
        );
        return;
      }
      setState(() => _workerLocation = target);
      _mapController.move(target, 15);
    } finally {
      if (mounted) setState(() => _locatingMe = false);
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    final user = SessionStore.currentUser;
    if (user == null || _togglingAvailability) return;
    if (value && !_isVerified) {
      _showVerificationRequired();
      return;
    }
    setState(() {
      _togglingAvailability = true;
      _available = value;
      if (!value) {
        // Al marcar OCUPADO ocultamos inmediatamente solicitudes/ofertas.
        _requests = [];
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
      SessionStore.currentUser = user.copyWith(isAvailable: value);
      unawaited(SessionStore.persistCurrentUser());
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
                  color: Colors.white,
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

                    // Título
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

                    // Categorías
                    const Text(
                      'Categoría',
                      style: TextStyle(
                        color: AppTheme.colorMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_categories.isEmpty)
                      const Text(
                        'Cuando tengas solicitudes podrás filtrarlas por categoría.',
                        style: TextStyle(
                            color: AppTheme.colorMuted, fontSize: 13),
                      )
                    else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((category) {
                        final isSelected = _selectedCategory == category;
                        return ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            final value = selected ? category : null;
                            setModalState(() => _selectedCategory = value);
                            setState(() => _selectedCategory = value);
                          },
                          selectedColor: AppTheme.colorPrimary.withValues(alpha: 0.3),
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
                            final v = selected ? value : null;
                            setModalState(() => _selectedModality = v);
                            setState(() => _selectedModality = v);
                          },
                          selectedColor:
                              AppTheme.colorHighlight.withValues(alpha: 0.3),
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

                    // Botón aplicar
                    ChambaPrimaryButton(
                      label: 'Aplicar filtros',
                      icon: Icons.check,
                      onPressed: () {
                        final cat = _selectedCategory;
                        final mod = _selectedModality;
                        Navigator.of(context).pop();
                        setState(() {
                          _selectedCategory = cat;
                          _selectedModality = mod;
                        });
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

  void _onReconnect() {
    if (mounted) _load(silent: true);
  }

  void _onNewRequest(dynamic payload) {
    // El banner lo muestra el shell (el worker puede estar en otra pestaña) y
    // el destello de la card lo maneja NewRequestAlert, que además descarta el
    // duplicado cuando la misma solicitud ya llegó por push.

    _load(silent: true);
  }

  String _timeAgo(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final parsed = DateTime.tryParse(isoDate);
      if (parsed == null) return '';
      final date = parsed.toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Hace un momento';
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
      return 'Hace ${diff.inDays} d';
    } catch (_) {
      return '';
    }
  }

  void _onJobCompleted(dynamic payload) {
    SessionStore.clearActiveJob(
        requestId: payload is Map ? payload['requestId']?.toString() : null);
    if (mounted) {
      setState(() {
        _requests.removeWhere((r) => r['status'] == 'completed');
      });
    }
  }

  void _showJobDetails(Map<String, dynamic> req) {
    final reqId = req['id']?.toString() ?? '';
    final budget = (req['budget'] as num?)?.toDouble() ?? 0;
    final workerOffer = req['workerOffer'] as Map<String, dynamic>?;
    final offerStatus = workerOffer?['status']?.toString();
    final canOffer =
        reqId.isNotEmpty && offerStatus != 'pending' && offerStatus != 'accepted';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => _JobDetailsSheet(
        requestData: req,
        onAcceptBudget: canOffer
            ? () {
                Navigator.of(modalCtx).pop();
                _acceptBudget(reqId, budget);
              }
            : null,
        onCounterOffer: canOffer
            ? () {
                Navigator.of(modalCtx).pop();
                _showCounterOfferSheet(reqId);
              }
            : null,
      ),
    );
  }

  void _onJobCancelled(dynamic payload) {
    SessionStore.clearActiveJob(
        requestId: payload is Map ? payload['requestId']?.toString() : null);
    if (mounted) {
      setState(() {
        _requests.removeWhere((r) => r['status'] == 'cancelled');
      });
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
      ToastService.show(
        title: '¡Presupuesto mejorado!',
        body: 'El cliente subió el presupuesto de la solicitud.',
        type: ToastType.info,
      );
      setState(() {
        final currentIdx =
            _requests.indexWhere((r) => r['id']?.toString() == eventRequestId);
        if (currentIdx != -1) {
          if (newBudget != null) {
            _requests[currentIdx]['budget'] = newBudget;
          }
          _requests[currentIdx]['workerOffer'] = null;
        }
      });
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
    // The shared notification presenter owns the acceptance alert. This listener only refreshes state.
    _load(silent: true);
  }

  void _onOfferRejected(dynamic payload) {
    final userId = SessionStore.currentUser?.id;
    final map = payload is Map ? Map<String, dynamic>.from(payload) : const {};
    if (map['workerUserId']?.toString() != userId) return;
    _load(silent: true);
  }

  void _onOfferExpired(dynamic payload) {
    final userId = SessionStore.currentUser?.id;
    final map = payload is Map ? Map<String, dynamic>.from(payload) : const {};
    if (map['workerUserId']?.toString() != userId) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu oferta expiró. Puedes mejorarla.')),
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
        // Al menos una oferta expiró, recargamos.
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

  bool _loadInFlight = false;

  /// Evita peticiones duplicadas: el polling, los eventos de socket y la
  /// reconexión llaman a _load casi a la vez; si ya hay una en curso, las
  /// recargas silenciosas se descartan.
  Future<void> _load({bool silent = false}) async {
    if (silent && _loadInFlight) return;
    _loadInFlight = true;
    try {
      await _loadImpl(silent: silent);
    } finally {
      _loadInFlight = false;
    }
  }

  Future<void> _loadImpl({bool silent = false}) async {
    final user = SessionStore.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Sesión expirada';
        _loading = false;
      });
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

      final backendAvailable =
          (response['isAvailable'] ?? response['available']) as bool?;
      if (backendAvailable != null && _available != backendAvailable) {
        if (mounted) {
          setState(() {
            _available = backendAvailable;
          });
        }
        if (SessionStore.currentUser != null) {
          SessionStore.currentUser =
              SessionStore.currentUser!.copyWith(isAvailable: backendAvailable);
          unawaited(SessionStore.persistCurrentUser());
        }
        unawaited(WorkerBackgroundService.setEnabled(backendAvailable));
      }

      final backendAgencyWorker = response['isAgencyWorker'] as bool?;
      final sessionUser = SessionStore.currentUser;
      if (backendAgencyWorker != null &&
          sessionUser != null &&
          sessionUser.isAgencyWorker != backendAgencyWorker) {
        SessionStore.currentUser =
            sessionUser.copyWith(isAgencyWorker: backendAgencyWorker);
        unawaited(SessionStore.persistCurrentUser());
        if (mounted) setState(() {});
      }

      final rawRequests = response['requests'] as List<dynamic>? ?? [];
      final List<Map<String, dynamic>> fetchedRequests = [];

      for (final req in rawRequests) {
        final mutableReq = _toMutableRequest(req);
        if (mutableReq != null) {
          fetchedRequests.add(mutableReq);
        }
      }

      // "No disponible" oculta las solicitudes nuevas, no los trabajos que ya
      // le asignaron (los de agencia nacen como no disponibles y no veían el
      // trabajo que su agencia les consiguió).
      if (!_available) {
        fetchedRequests.removeWhere((r) => r['status']?.toString() != 'assigned');
      }

      // Filtrar completados, cancelados o en espera de confirmación de descarte
      fetchedRequests.removeWhere((r) {
        final st = r['status']?.toString();
        final id = r['id']?.toString();
        return st == 'completed' ||
            st == 'cancelled' ||
            (id != null && _pendingDismissIds.contains(id));
      });

      // Los trabajos asignados para otro día van a la agenda: no ocupan la
      // lista ni bloquean nuevas solicitudes.
      final scheduled = fetchedRequests
          .where((r) => r['isScheduled'] == true)
          .toList();
      fetchedRequests.removeWhere((r) => r['isScheduled'] == true);
      final newScheduled = scheduled
          .map((r) => r['id']?.toString())
          .whereType<String>()
          .where((id) =>
              _scheduledJobs.isNotEmpty &&
              !_scheduledJobs.any((j) => j['id']?.toString() == id))
          .toList();
      if (newScheduled.isNotEmpty && mounted) {
        final job = scheduled.firstWhere(
            (r) => r['id']?.toString() == newScheduled.first);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Te eligieron para ${formatJobStart(job['startDate']?.toString())}. Quedó en tu agenda.'),
          action: SnackBarAction(label: 'Ver agenda', onPressed: _openAgenda),
        ));
      }
      _scheduledJobs = scheduled;

      // Chequear si alguna oferta fue aceptada
      bool newlyAccepted = false;
      for (final req in fetchedRequests) {
        final offerStatus = (req['workerOffer'] as Map?)?['status']?.toString();
        final reqId = req['id']?.toString();
        if (offerStatus == 'accepted' && reqId != null) {
          SessionStore.activeRequestId = reqId;
          if (!_notifiedAcceptedRequests.contains(reqId)) {
            _notifiedAcceptedRequests.add(reqId);
            newlyAccepted = true;
          }
          break;
        }
      }

      // Polling never repeats the acceptance alert when reopening the app.

      if (newlyAccepted && mounted) {
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

      // Cuando aparecen solicitudes para ofertar (antes no había ninguna), la
      // hoja se abre sola: en su posición de reposo los botones de ofertar
      // quedan bajo la barra inferior y la oferta caduca mientras tanto. Solo
      // en ese paso de "ninguna" a "alguna", para no pelear con el trabajador
      // si después la baja para ver el mapa.
      bool awaitsOffer(Map<String, dynamic> r) =>
          r['status']?.toString() != 'assigned' &&
          (r['workerOffer'] as Map?)?['status'] == null;
      final hasAccepted = fetchedRequests.any(
          (r) => (r['workerOffer'] as Map?)?['status']?.toString() == 'accepted');
      if (mounted &&
          !hasAccepted &&
          !_requests.any(awaitsOffer) &&
          fetchedRequests.any(awaitsOffer)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _sheetCtrl.isAttached &&
              _sheetCtrl.size < _sheetExpandedSize) {
            _sheetCtrl.animateTo(
              _sheetExpandedSize,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
            );
          }
        });
      }

      if (mounted) {
        setState(() {
          _requests = fetchedRequests;
          if (widget.focusRequestId != null)
            _requests.sort((a, b) =>
                (b['id'] == widget.focusRequestId ? 1 : 0) -
                (a['id'] == widget.focusRequestId ? 1 : 0));
          _loading = false;
          _error = null;
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

  void _centerMapOnce() {
    if (!_mapReady || _isMapInitialized || _workerLocation == null) return;
    _mapController.move(_workerLocation!, 14);
    _isMapInitialized = true;
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
    final mapCenter = _workerLocation ?? const LatLng(-17.7834, -63.1821);

    return Scaffold(
      backgroundColor: AppTheme.colorBackground,
      body: Stack(
        children: [
          // ── MAPA DE FONDO ──────────────────────────────────────────────
          Positioned.fill(
            child: AppConfig.mapboxAccessToken.trim().isEmpty
                ? Container(
                    color: AppTheme.colorBackgroundAccent,
                    child: const Center(
                      child: Text(
                        'El mapa no está disponible\nen este momento',
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
                      onMapReady: () {
                        _mapReady = true;
                        _centerMapOnce();
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
                        userAgentPackageName: 'com.chambatrabajo.app',
                        additionalOptions: {
                          'accessToken': AppConfig.mapboxAccessToken,
                        },
                      ),
                      // Pines de solicitudes cercanas
                      if (_requests.any((r) =>
                          r['latitude'] is num && r['longitude'] is num))
                        MarkerLayer(
                          markers: [
                            for (final req in _requests)
                              if (req['latitude'] is num &&
                                  req['longitude'] is num)
                                Marker(
                                  point: LatLng(
                                    (req['latitude'] as num).toDouble(),
                                    (req['longitude'] as num).toDouble(),
                                  ),
                                  width: 40,
                                  height: 40,
                                  child: GestureDetector(
                                    onTap: () => _showJobDetails(req),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppTheme.colorPrimary,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2.5,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x407C3AED),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        _categoryIcon(
                                            req['category']?.toString()),
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                          ],
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
                                  color: AppTheme.colorInfo,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.colorInfo.withValues(alpha: 0.5),
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

          // ── BARRA SUPERIOR: disponibilidad ────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    // Toggle centrado con pulso y tooltip cuando está ocupado
                    _PulsingAvailabilityToggle(
                      available: _available,
                      busy: hasAcceptedRequest,
                      toggling: _togglingAvailability || hasAcceptedRequest,
                      onToggle: () => _toggleAvailability(!_available),
                    ),
                    // Agenda pegada a la izquierda, con cuántos trabajos
                    // programados hay.
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Tooltip(
                        message: 'Mi agenda',
                        child: Material(
                          color: _scheduledJobs.isNotEmpty
                              ? AppTheme.colorPrimary.withValues(alpha: 0.3)
                              : AppTheme.colorGlassDarkSoft,
                          elevation: 2,
                          shadowColor: const Color(0x401E1B4B),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: _openAgenda,
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Badge(
                                isLabelVisible: _scheduledJobs.isNotEmpty,
                                label: Text('${_scheduledJobs.length}'),
                                backgroundColor: AppTheme.colorHighlight,
                                textColor: AppTheme.colorText,
                                child: const Icon(
                                  Icons.calendar_month_outlined,
                                  color: AppTheme.colorText,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Botón filtros pegado a la derecha
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Material(
                        color: (_selectedCategory != null ||
                                _selectedModality != null)
                            ? AppTheme.colorPrimary.withValues(alpha: 0.3)
                            : AppTheme.colorGlassDarkSoft,
                        elevation: 2,
                        shadowColor: const Color(0x401E1B4B),
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

          // ── BOTTOM SHEET DRAGGABLE con solicitudes ────────────────────
          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: 0.32,
            minChildSize: 0.15,
            maxChildSize: _sheetExpandedSize,
            snap: true,
            snapSizes: const [0.15, 0.32, _sheetExpandedSize],
            builder: (context, scrollController) {
              final navPadding =
                  92.0 + MediaQuery.viewPaddingOf(context).bottom;
              final screenHeight = MediaQuery.sizeOf(context).height;

              void toggleSheet() {
                if (!_sheetCtrl.isAttached) return;
                final current = _sheetCtrl.size;
                final target = current > 0.45 ? 0.32 : _sheetExpandedSize;
                _sheetCtrl.animateTo(
                  target,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                );
              }

              void onHeaderVerticalDragUpdate(DragUpdateDetails details) {
                if (!_sheetCtrl.isAttached || screenHeight <= 0) return;
                final delta = -(details.primaryDelta ?? 0) / screenHeight;
                final next = (_sheetCtrl.size + delta)
                    .clamp(0.15, _sheetExpandedSize);
                _sheetCtrl.jumpTo(next);
              }

              void onHeaderVerticalDragEnd(DragEndDetails details) {
                if (!_sheetCtrl.isAttached) return;
                final velocity = details.primaryVelocity ?? 0;
                final current = _sheetCtrl.size;
                const snaps = [0.15, 0.32, _sheetExpandedSize];
                double target;
                if (velocity < -350) {
                  target = snaps.firstWhere(
                    (s) => s > current + 0.02,
                    orElse: () => _sheetExpandedSize,
                  );
                } else if (velocity > 350) {
                  target = snaps.lastWhere(
                    (s) => s < current - 0.02,
                    orElse: () => 0.15,
                  );
                } else {
                  target = snaps.reduce((a, b) =>
                      (a - current).abs() < (b - current).abs() ? a : b);
                }
                _sheetCtrl.animateTo(
                  target,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                );
              }

              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: LayoutBuilder(
                  builder: (context, sheetConstraints) {
                    final showPinnedTabs = _requests.isNotEmpty &&
                        !hasAcceptedRequest &&
                        sheetConstraints.maxHeight >= 96;
                    return Column(
                      children: [
                        // ── Cabecera fija (Handle + Pestañas Para hoy / Programados) ──
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: toggleSheet,
                          onVerticalDragUpdate: onHeaderVerticalDragUpdate,
                          onVerticalDragEnd: onHeaderVerticalDragEnd,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.colorMuted
                                        .withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              if (showPinnedTabs)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 2, 16, 8),
                                  child: _WhenTabs(
                                    showLater: _showLater,
                                    todayCount:
                                        _requestsFor(later: false).length,
                                    laterCount:
                                        _requestsFor(later: true).length,
                                    onChanged: (later) {
                                      setState(() => _showLater = later);
                                      if (scrollController.hasClients) {
                                        scrollController.jumpTo(0);
                                      }
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // ── Contenido desplazable ────────────────────────────────────
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            padding: EdgeInsets.zero,
                            physics: const ClampingScrollPhysics(),
                            children: [
                              if (_loading && _requests.isEmpty)
                                const SkeletonList(
                                  count: 3,
                                  lines: 3,
                                  trailing: true,
                                  shrinkWrap: true,
                                  padding: EdgeInsets.only(top: 4),
                                )
                              else if (_error != null && _requests.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 32),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: AppTheme.colorError
                                                .withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                              Icons.cloud_off_rounded,
                                              color: AppTheme.colorError,
                                              size: 40),
                                        ),
                                        const SizedBox(height: 14),
                                        const Text(
                                          'Error de conexión',
                                          style: TextStyle(
                                            color: AppTheme.colorText,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _error!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppTheme.colorText
                                                .withValues(alpha: 0.7),
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        ChambaSecondaryButton(
                                          label: 'Reintentar',
                                          icon: Icons.refresh,
                                          onPressed: () => _load(),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else if (_requests.isEmpty)
                                Column(
                                  children: [
                                    if (_scheduledJobs.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 4, 16, 0),
                                        child: _ScheduledBanner(
                                          jobs: _scheduledJobs,
                                          onTap: _openAgenda,
                                        ),
                                      ),
                                    _buildEmptyContent(navPadding),
                                  ],
                                )
                              else
                                Padding(
                                  padding: EdgeInsets.only(bottom: navPadding),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (_error != null)
                                        Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 8),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppTheme.colorError
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: AppTheme.colorError
                                                    .withValues(alpha: 0.35)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                  Icons.warning_amber_rounded,
                                                  color: AppTheme.colorWarning,
                                                  size: 20),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  _error!,
                                                  style: const TextStyle(
                                                      color: AppTheme.colorText,
                                                      fontSize: 13),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () => _load(),
                                                child: const Text('Reintentar',
                                                    style: TextStyle(
                                                        color: AppTheme
                                                            .colorPrimary,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (_scheduledJobs.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              16, 4, 16, 4),
                                          child: _ScheduledBanner(
                                            jobs: _scheduledJobs,
                                            onTap: _openAgenda,
                                          ),
                                        ),
                                      Builder(builder: (context) {
                                        if (hasAcceptedRequest) {
                                          final acceptedReq =
                                              _requests.firstWhere((req) {
                                            final workerOffer =
                                                req['workerOffer']
                                                    as Map<String, dynamic>?;
                                            return workerOffer?['status'] ==
                                                'accepted';
                                          });
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                            child: _buildFloatingAcceptedCard(
                                                acceptedReq),
                                          );
                                        }

                                        final filtered =
                                            _requestsFor(later: _showLater);
                                        if (filtered.isEmpty) {
                                          return _buildTabEmpty();
                                        }
                                        // En "Programados" cada día lleva su título,
                                        // para que no se lean como trabajos de hoy.
                                        final entries = <Object>[];
                                        DateTime? lastDay;
                                        for (final req in filtered) {
                                          final day = _startDay(req);
                                          if (_showLater &&
                                              day != null &&
                                              day != lastDay) {
                                            entries.add(day);
                                            lastDay = day;
                                          }
                                          entries.add(req);
                                        }
                                        return ListView.separated(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                          itemCount: entries.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 16),
                                          itemBuilder: (context, index) {
                                            final entry = entries[index];
                                            if (entry is DateTime) {
                                              return _DayHeader(
                                                day: entry,
                                                count: filtered
                                                    .where((r) =>
                                                        _startDay(r) == entry)
                                                    .length,
                                              );
                                            }
                                            final req =
                                                entry as Map<String, dynamic>;
                                            final workerOffer =
                                                req['workerOffer']
                                                    as Map<String, dynamic>?;
                                            final offerStatus = workerOffer?[
                                                    'status']
                                                ?.toString();
                                            final secondsRemaining =
                                                (workerOffer?[
                                                            'secondsRemaining']
                                                        as num?)
                                                    ?.toInt();
                                            final hasPendingOffer =
                                                offerStatus == 'pending';
                                            final isAcceptedOffer =
                                                offerStatus == 'accepted';
                                            final card = _buildRequestCard(
                                              req: req,
                                              workerOffer: workerOffer,
                                              offerStatus: offerStatus,
                                              secondsRemaining:
                                                  secondsRemaining,
                                              hasPendingOffer: hasPendingOffer,
                                              isAcceptedOffer: isAcceptedOffer,
                                              clientCountered: false,
                                            );
                                            return ValueListenableBuilder<int>(
                                              valueListenable: NewRequestAlert
                                                  .instance.highlightRevision,
                                              builder: (context, _, child) =>
                                                  NewRequestPulse(
                                                active: NewRequestAlert.instance
                                                    .isHighlighted(
                                                        req['id']?.toString()),
                                                child: child!,
                                              ),
                                              child: card,
                                            );
                                          },
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),

          // ── BOTÓN CENTRAR MI UBICACIÓN (sigue el borde de la hoja) ─────
          if (AppConfig.mapboxAccessToken.trim().isNotEmpty)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return ListenableBuilder(
                    listenable: _sheetCtrl,
                    builder: (context, _) {
                      final sheetFraction =
                          _sheetCtrl.isAttached ? _sheetCtrl.size : 0.32;
                      final hideGpsButton = sheetFraction > 0.65;
                      return Stack(
                        children: [
                          Positioned(
                            right: 16,
                            bottom: (constraints.maxHeight * sheetFraction + 12)
                                .clamp(12.0, constraints.maxHeight - 130.0),
                            child: IgnorePointer(
                              ignoring: hideGpsButton,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 180),
                                opacity: hideGpsButton ? 0.0 : 1.0,
                                child: Material(
                                  color: AppTheme.colorPrimary,
                                  shape: const CircleBorder(),
                                  elevation: 4,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _centerOnMyLocation,
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: _locatingMe
                                          ? const Padding(
                                              padding: EdgeInsets.all(14),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.my_location,
                                              color: Colors.white,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

          // ── BANNER OFERTA ACEPTADA ─────────────────────────────────────
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
                                    '¡Oferta aceptada!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'El cliente aceptó tu oferta. Dirígete a la ubicación.',
                                    style: TextStyle(
                                      color: AppTheme.colorMuted,
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
    final isAgency = SessionStore.currentUser?.isAgencyWorker == true;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAgency ? Icons.business_center : Icons.search_off,
            color: AppTheme.colorMuted,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            isAgency ? 'Sin trabajos asignados' : 'No hay solicitudes cercanas',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.colorText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isAgency
                ? 'Espera a que tu agencia te asigne trabajos directamente.'
                : _available
                    ? 'Estás disponible. Las solicitudes aparecerán aquí.'
                    : 'Estás ocupado. Activa disponibilidad para recibir trabajos.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.colorMuted, fontSize: 14),
          ),
          if (!isAgency && !_available) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _togglingAvailability
                  ? null
                  : () => _toggleAvailability(true),
              icon: const Icon(Icons.power_settings_new, size: 18),
              label: const Text(
                'Ponerme disponible',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.colorSuccess,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFloatingAcceptedCard(Map<String, dynamic> req) {
    return GestureDetector(
      onTap: () {
        final reqId = req['id']?.toString();
        if (reqId != null) _openJobInProgress(reqId);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.colorPrimary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.colorPrimary.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.colorPrimary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.handyman,
                  color: AppTheme.colorPrimary, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trabajo en curso',
                    style: TextStyle(
                      color: AppTheme.colorPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Toca para ir al seguimiento',
                    style: TextStyle(color: AppTheme.colorMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppTheme.colorPrimary, size: 28),
          ],
        ),
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
    final lifetime = (req['offerLifetimeSeconds'] as num?)?.toInt() ?? 120;
    final offerProgress = secondsRemaining == null
        ? null
        : (secondsRemaining / lifetime).clamp(0.0, 1.0).toDouble();

    final distanceText = req['distanceKm'] == null
        ? null
        : '${(req['distanceKm'] as num).toStringAsFixed(1)} km';

    final currentBudget = (req['budget'] as num?)?.toDouble() ?? 0;
    final myOfferAmount = (workerOffer?['amount'] as num?)?.toDouble();
    final myOfferMaterials =
        (workerOffer?['materialsAmount'] as num?)?.toDouble() ?? 0;

    final isDeclinedOffer = offerStatus == 'declined';

    // El cliente subió su presupuesto después de mi oferta: aunque mi
    // contraoferta fuera mayor (pedí 150, él subió de 100 a 120), puedo
    // aceptar su precio nuevo o proponer otro.
    final clientImproved = hasPendingOffer &&
        !isDeclinedOffer &&
        myOfferAmount != null &&
        (currentBudget > myOfferAmount ||
            workerOffer?['clientRaisedBudget'] == true);

    final client = req['client'] as Map<String, dynamic>? ?? {};
    final clientName = client['name']?.toString() ?? 'Cliente';
    final clientPhoto = client['profilePhotoUrl']?.toString();
    final clientRating = (client['rating'] as num?)?.toDouble() ?? 0.0;
    final clientReviews = (client['reviews'] as num?)?.toInt() ?? 0;
    final isVerified = client['isVerified'] == true;
    final createdAt = req['createdAt']?.toString();
    final parsedDate =
        createdAt != null ? DateTime.tryParse(createdAt)?.toLocal() : null;
    final isNew = parsedDate != null &&
        DateTime.now().difference(parsedDate).inMinutes < 2;

    // Foto(s) y video del anuncio: primero el video, luego las fotos.
    final media = <_RequestMedia>[];
    final video = req['video'] is Map
        ? Map<String, dynamic>.from(req['video'] as Map)
        : null;
    final videoUrl = video?['url']?.toString() ?? '';
    if (videoUrl.isNotEmpty) {
      media.add(_RequestMedia(
        url: videoUrl,
        previewUrl: video?['thumbnailUrl']?.toString(),
        isVideo: true,
      ));
    }
    for (final photo in req['photos'] as List<dynamic>? ?? const []) {
      final url = photo is Map ? photo['url']?.toString() ?? '' : '';
      if (url.isNotEmpty) media.add(_RequestMedia(url: url));
    }
    final startLabel = startDateLabel(req['startDate']);
    final tagChips = requestTagChips(req);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isNew
              ? AppTheme.colorSuccess.withValues(alpha: 0.6)
              : AppTheme.colorGlassBorderSoft,
          width: isNew ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F7C3AED),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (media.isNotEmpty) ...[
            _RequestMediaHeader(media: media, isNew: isNew),
            const SizedBox(height: 12),
          ],
          // ── Cliente y precio ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.colorBackgroundAccent,
                  backgroundImage:
                      clientPhoto != null ? NetworkImage(clientPhoto) : null,
                  child: clientPhoto == null
                      ? const Icon(Icons.person, color: AppTheme.colorPrimary)
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
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified,
                                color: AppTheme.colorPrimary, size: 16),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: AppTheme.colorHighlight, size: 14),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '$clientRating ($clientReviews)  |  ${isVerified ? 'Cliente verificado' : 'Nuevo cliente'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppTheme.colorMuted, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _unitPriceLabel(req, currentBudget),
                      style: const TextStyle(
                        color: AppTheme.colorPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (req['modality'] != 'fixed' && req['modality'] != null)
                      Text(
                        'Total: Bs. ${formatBs(currentBudget)}',
                        style: const TextStyle(
                            color: AppTheme.colorMuted, fontSize: 11),
                      )
                    else
                      Text(
                        _priceTypeLabel(req['priceType']),
                        style: const TextStyle(
                            color: AppTheme.colorMuted, fontSize: 12),
                      ),
                    // Lo que le queda al trabajador, antes de aceptar.
                    const SizedBox(height: 2),
                    Text(
                      _serviceFeePercent > 0
                          ? 'Te llega Bs. ${_netForWorker(currentBudget).toStringAsFixed(0)}'
                          : 'Te llega todo',
                      style: const TextStyle(
                        color: AppTheme.colorSuccess,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 32,
                  child: PopupMenuButton<String>(
                    tooltip: 'Más opciones',
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert,
                        color: AppTheme.colorMuted),
                    color: Colors.white,
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
                      if (!hasPendingOffer && !isAcceptedOffer)
                        const PopupMenuItem(
                          value: 'dismiss',
                          child: Text('No me interesa',
                              style: TextStyle(color: AppTheme.colorText)),
                        ),
                      const PopupMenuItem(
                        value: 'block',
                        child: Text('Bloquear cliente',
                            style: TextStyle(color: AppTheme.colorText)),
                      ),
                      const PopupMenuItem(
                        value: 'report',
                        child: Text('Reportar publicación',
                            style: TextStyle(color: AppTheme.colorError)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ── Qué hay que hacer ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Builder(builder: (context) {
              final rawCat = req['category']?.toString().trim() ?? '';
              final rawTitle = req['title']?.toString().trim() ?? '';
              final rawDesc = req['description']?.toString().trim() ?? '';
              final isGeneralCat =
                  rawCat.isEmpty || _categoryKey(rawCat) == 'general';
              final headingText = isGeneralCat
                  ? (rawTitle.isNotEmpty
                      ? rawTitle
                      : (rawCat.isNotEmpty ? rawCat : 'Trabajo general'))
                  : rawCat;
              final showSubTitle = !isGeneralCat &&
                  rawTitle.isNotEmpty &&
                  _categoryKey(rawTitle) != _categoryKey(rawCat) &&
                  !rawDesc.toLowerCase().startsWith(rawTitle.toLowerCase());
              final showDesc = rawDesc.isNotEmpty &&
                  (!isGeneralCat ||
                      rawDesc.toLowerCase() != headingText.toLowerCase());

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _categoryIcon(rawCat.isNotEmpty ? rawCat : rawTitle),
                        color: AppTheme.colorPrimary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          headingText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.colorText,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _timeAgo(createdAt),
                          style: TextStyle(
                            color: isNew
                                ? AppTheme.colorSuccess
                                : AppTheme.colorMuted,
                            fontSize: 12,
                            fontWeight:
                                isNew ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (showSubTitle) ...[
                    const SizedBox(height: 4),
                    Text(
                      rawTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.colorText,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (showDesc) ...[
                    const SizedBox(height: 4),
                    Text(
                      rawDesc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.colorMuted,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                  ],
                if (tagChips.isNotEmpty || startLabel != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ...tagChips,
                      if (startLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.colorPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.event,
                                  size: 13, color: AppTheme.colorPrimary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  startLabel,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.colorPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: AppTheme.colorMuted, size: 18),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        req['address']?.toString() ??
                            'Dirección no disponible',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.colorText, fontSize: 14),
                      ),
                    ),
                    if (distanceText != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.colorBackgroundAccent,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.directions_walk,
                                color: AppTheme.colorPrimary, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              distanceText,
                              style: const TextStyle(
                                color: AppTheme.colorText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              );
            }),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showJobDetails(req),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.colorPrimary,
                backgroundColor:
                    AppTheme.colorBackgroundAccent.withValues(alpha: 0.5),
                side: BorderSide(
                    color: AppTheme.colorPrimary.withValues(alpha: 0.3)),
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 20),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.article_outlined, size: 20),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Ver detalles del trabajo',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20),
                ],
              ),
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
                        const Text('Tu oferta',
                            style: TextStyle(color: AppTheme.colorMuted)),
                        // Con materiales: la mano de obra y debajo los
                        // materiales, igual que lo ve el cliente.
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                                myOfferAmount == null
                                    ? 'Bs. -'
                                    : 'Bs. ${formatBs(myOfferAmount - myOfferMaterials)}',
                                style: const TextStyle(
                                    color: AppTheme.colorText,
                                    fontWeight: FontWeight.bold)),
                            if (myOfferMaterials > 0) ...[
                              const SizedBox(height: 4),
                              MaterialsPill(amount: myOfferMaterials),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (offerProgress != null)
                      LinearProgressIndicator(
                        value: offerProgress,
                        backgroundColor: AppTheme.colorSurfaceSoft,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          offerProgress < 0.2
                              ? AppTheme.colorError
                              : AppTheme.colorPrimary,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Esperando respuesta del cliente',
                          style: TextStyle(
                            color: AppTheme.colorMuted,
                            fontSize: 12,
                          ),
                        ),
                        if (secondsRemaining != null && secondsRemaining > 0)
                          Text(
                            'Tiempo restante: ${secondsRemaining}s',
                            style: const TextStyle(
                              color: AppTheme.colorPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              )
            else if (isDeclinedOffer)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.colorError.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.colorError.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel, color: AppTheme.colorError),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Oferta declinada',
                              style: TextStyle(
                                  color: AppTheme.colorError,
                                  fontWeight: FontWeight.bold)),
                          Text(
                              'El cliente declinó tu oferta de Bs. ${formatBs(myOfferAmount ?? 0)}',
                              style: const TextStyle(
                                  color: AppTheme.colorMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          _showCounterOfferSheet(req['id'].toString()),
                      child: const Text('Reofertar',
                          style: TextStyle(color: AppTheme.colorPrimary)),
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
                      const Icon(Icons.trending_up,
                          color: AppTheme.colorPrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '¡El cliente subió el presupuesto a Bs. $currentBudget!',
                          style: const TextStyle(
                              color: AppTheme.colorPrimary,
                              fontWeight: FontWeight.bold),
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
                        foregroundColor: AppTheme.colorError,
                        side: const BorderSide(color: AppTheme.colorError),
                      ),
                      child: const Text('No me interesa'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          _acceptBudget(req['id'].toString(), currentBudget),
                      child: req['materialsMode'] == 'worker'
                          ? const Text('Cotizar con materiales')
                          // Solo envía una oferta al precio del cliente:
                          // el trabajo es suyo cuando el cliente lo elige.
                          // Si no entra (monto largo, pantalla angosta)
                          // se achica entero en vez de cortar el precio.
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.handshake_outlined, size: 20),
                                const SizedBox(width: 6),
                                Text('Ofertar Bs. ${formatBs(currentBudget)}'),
                              ],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _showCounterOfferSheet(req['id'].toString()),
                  icon: const Icon(Icons.sell),
                  label: const Text(
                    'Proponer otro precio',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.colorHighlight,
                    foregroundColor: AppTheme.colorText,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
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
    final idx = _requests.indexWhere((r) => r['id'].toString() == requestId);
    if (idx < 0) return;
    final removedReq = _requests[idx];
    var undone = false;

    setState(() {
      _pendingDismissIds.add(requestId);
      _requests.removeAt(idx);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Solicitud descartada'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () {
              undone = true;
              if (!mounted) return;
              setState(() {
                _pendingDismissIds.remove(requestId);
                if (!_requests.any((r) => r['id'].toString() == requestId)) {
                  final insertAt = idx.clamp(0, _requests.length);
                  _requests.insert(insertAt, removedReq);
                }
              });
            },
          ),
        ),
      );
    }

    await Future<void>.delayed(const Duration(seconds: 5));
    if (undone || !_pendingDismissIds.contains(requestId)) return;

    try {
      await RequestDependencies.dismissRequest(
        requestId: requestId,
        workerUserId: user.id,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _pendingDismissIds.remove(requestId);
          if (!_requests.any((r) => r['id'].toString() == requestId)) {
            _requests.add(removedReq);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      _pendingDismissIds.remove(requestId);
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
        _requests.removeWhere(
            (r) => (r['client'] as Map?)?['id'].toString() == clientUserId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Cliente bloqueado. Puedes desbloquearlo desde tu perfil.'),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () async {
                try {
                  await MobileBackendService.instance.unblockUser(
                      userId: user.id, blockedUserId: clientUserId);
                  if (mounted) _load(silent: true);
                } catch (_) {}
              },
            ),
          ),
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
        title: const Text('Reportar publicación',
            style: TextStyle(color: AppTheme.colorText)),
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
            child: const Text('Cancelar',
                style: TextStyle(color: AppTheme.colorMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.colorError),
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
                    const SnackBar(content: Text('Publicación reportada')),
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
    // Si el cliente pidió que lleve los materiales, primero tiene que
    // cotizarlos: se abre la oferta con el precio del cliente ya puesto.
    final req = _requests.firstWhere((r) => r['id'].toString() == requestId,
        orElse: () => const {});
    if (req['materialsMode'] == 'worker') {
      _showCounterOfferSheet(requestId);
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
          serviceFeePercent: _serviceFeePercent,
        ),
      ),
    );
    if (sent == true && mounted) {
      await _load(silent: true);
    }
  }

  Future<void> _openChat(String requestId) => openJobChat(context, requestId);
}

/// "Tienes 2 trabajos programados · el próximo: mañana 08:00" sobre la
/// lista de solicitudes. Abre la agenda.
class _ScheduledBanner extends StatelessWidget {
  const _ScheduledBanner({required this.jobs, required this.onTap});

  final List<Map<String, dynamic>> jobs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final next = jobs.first;
    final count = jobs.length;
    return Material(
      color: AppTheme.colorPrimaryTint,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              const Icon(Icons.event_available_rounded,
                  color: AppTheme.colorPrimary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1
                          ? 'Tienes 1 trabajo programado'
                          : 'Tienes $count trabajos programados',
                      style: const TextStyle(
                        color: Color(0xFF4C1D95),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Próximo: ${formatJobStart(next['startDate']?.toString())} · ${next['title'] ?? next['category'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF6D28D9), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.colorPrimary),
            ],
          ),
        ),
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

// ── Modal de detalles del trabajo ─────────────────────────────────────────────
class _JobDetailsSheet extends StatelessWidget {
  const _JobDetailsSheet({
    required this.requestData,
    this.onAcceptBudget,
    this.onCounterOffer,
  });

  final Map<String, dynamic> requestData;
  final VoidCallback? onAcceptBudget;
  final VoidCallback? onCounterOffer;

  @override
  Widget build(BuildContext context) {
    final title = requestData['title']?.toString() ?? 'Solicitud';
    final description = requestData['description']?.toString() ?? '';
    final address = requestData['address']?.toString() ?? '';
    final budget = requestData['budget'];
    final currentBudget = (budget as num?)?.toDouble() ?? 0;
    final category = requestData['category']?.toString() ?? '';
    final photos = requestData['photos'] as List<dynamic>? ?? const [];
    final video = requestData['video'] is Map
        ? Map<String, dynamic>.from(requestData['video'] as Map)
        : null;
    final videoUrl = video?['url']?.toString() ?? '';
    final videoThumb = video?['thumbnailUrl']?.toString() ?? '';
    final client = requestData['client'] as Map<String, dynamic>?;
    final detailClientName = (client?['name']?.toString() ??
            '${client?['firstName'] ?? ''} ${client?['lastName'] ?? ''}')
        .trim();
    final priceType = _priceTypeLabel(requestData['priceType']);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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

                    // Título
                    Text(
                      title,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.colorText,
                              ),
                    ),
                    const SizedBox(height: 8),

                    // Categoría + presupuesto
                    Row(
                      children: [
                        if (category.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.colorPrimary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                color: AppTheme.colorPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (budget != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                requestData['modality'] == 'hourly' &&
                                        requestData['hourlyRate'] != null
                                    ? 'Bs. ${requestData['hourlyRate']} por hora'
                                    : requestData['modality'] == 'daily' &&
                                            requestData['dailyRate'] != null
                                        ? 'Bs. ${requestData['dailyRate']} por día'
                                        : 'Bs. ${formatBs(currentBudget)}',
                                style: const TextStyle(
                                  color: AppTheme.colorPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (requestData['modality'] == 'hourly' &&
                                  requestData['estimatedHours'] != null)
                                Text(
                                  'Total: Bs. $budget (${requestData['estimatedHours']} hrs)',
                                  style: const TextStyle(
                                      color: AppTheme.colorMuted, fontSize: 12),
                                )
                              else if (requestData['modality'] == 'daily' &&
                                  requestData['days'] != null)
                                Text(
                                  'Total: Bs. $budget (${requestData['days']} días)',
                                  style: const TextStyle(
                                      color: AppTheme.colorMuted, fontSize: 12),
                                )
                              else
                                Text(
                                  priceType,
                                  style: const TextStyle(
                                    color: AppTheme.colorMuted,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Cuándo empieza el trabajo (modalidad por día / programados)
                    if (startDateLabel(requestData['startDate']) != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.colorPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event,
                                size: 18, color: AppTheme.colorPrimary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                startDateLabel(requestData['startDate'])!,
                                style: const TextStyle(
                                  color: AppTheme.colorPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Descripción
                    if (description.isNotEmpty) ...[
                      const Text(
                        'Descripción',
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
                          color: AppTheme.colorText,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    JobExtrasSection(request: requestData),

                    // Dirección
                    if (address.isNotEmpty) ...[
                      const Text(
                        'Dirección',
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
                              style: const TextStyle(
                                color: AppTheme.colorText,
                                fontSize: 14,
                              ),
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
                                ? NetworkImage(
                                    client['profilePhotoUrl'] as String)
                                : null,
                            child: client['profilePhotoUrl'] == null
                                ? Text(
                                    chambaInitial(detailClientName,
                                        fallback: 'C'),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            detailClientName.isEmpty
                                ? 'Cliente'
                                : detailClientName,
                            style: const TextStyle(
                              color: AppTheme.colorText,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Video
                    if (videoUrl.isNotEmpty) ...[
                      const Text(
                        'Video',
                        style: TextStyle(
                          color: AppTheme.colorMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => showVideoPreview(context, videoUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            height: 150,
                            width: double.infinity,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (videoThumb.isNotEmpty)
                                  Image.network(
                                    videoThumb,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const ColoredBox(
                                      color: Color(0xFF2A2340),
                                    ),
                                  )
                                else
                                  const ColoredBox(color: Color(0xFF2A2340)),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xB31E1B4B),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.play_arrow_rounded,
                                            color: Colors.white, size: 22),
                                        SizedBox(width: 4),
                                        Text(
                                          'Reproducir video',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
                            final photo =
                                photos[index] as Map<String, dynamic>?;
                            final url = photo?['url']?.toString();
                            if (url == null) return const SizedBox.shrink();
                            return GestureDetector(
                              onTap: () {
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
              ),
              if (onAcceptBudget != null || onCounterOffer != null)
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: AppTheme.colorMuted.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (onCounterOffer != null)
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: onCounterOffer,
                              icon: const Icon(Icons.sell, size: 18),
                              label: const Text(
                                'Otro precio',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.colorHighlight,
                                foregroundColor: AppTheme.colorText,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                          ),
                        if (onCounterOffer != null && onAcceptBudget != null)
                          const SizedBox(width: 12),
                        if (onAcceptBudget != null)
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: onAcceptBudget,
                              icon: const Icon(Icons.handshake_outlined,
                                  size: 18),
                              label: Text(
                                requestData['materialsMode'] == 'worker'
                                    ? 'Cotizar'
                                    : 'Ofertar Bs. ${formatBs(currentBudget)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PulsingAvailabilityToggle extends StatefulWidget {
  const _PulsingAvailabilityToggle({
    required this.available,
    required this.toggling,
    required this.onToggle,
    this.busy = false,
  });

  final bool available;
  final bool toggling;
  final VoidCallback onToggle;
  final bool busy;

  @override
  State<_PulsingAvailabilityToggle> createState() =>
      _PulsingAvailabilityToggleState();
}

class _PulsingAvailabilityToggleState extends State<_PulsingAvailabilityToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseGlow;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseGlow = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (!widget.available) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _PulsingAvailabilityToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.available) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOcupado = !widget.available;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale = isOcupado ? _pulseScale.value : 1.0;
            final glow = isOcupado ? _pulseGlow.value : 0.0;
            return Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: isOcupado
                      ? [
                          BoxShadow(
                            color: AppTheme.colorSuccess
                                .withValues(alpha: glow * 0.5),
                            blurRadius: 14 * glow,
                            spreadRadius: 2 * glow,
                          ),
                          BoxShadow(
                            color: AppTheme.colorHighlight.withValues(alpha: glow * 0.3),
                            blurRadius: 8 * glow,
                          ),
                        ]
                      : [],
                ),
                child: child,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.colorGlassDarkSoft,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isOcupado
                    ? AppTheme.colorSuccess.withValues(alpha: 0.7)
                    : AppTheme.colorGlassBorderSoft,
                width: isOcupado ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AvailabilityLabel(
                  label: widget.busy ? 'EN TRABAJO' : 'DISPONIBLE',
                  active: widget.available && !widget.busy,
                  activeColor: AppTheme.colorSuccess,
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: widget.toggling ? null : widget.onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 44,
                    height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      color: widget.available
                          ? AppTheme.colorSuccess
                          : AppTheme.colorMuted.withValues(alpha: 0.4),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      alignment: widget.available
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
                  active: !widget.available,
                  activeColor: AppTheme.colorMuted,
                ),
              ],
            ),
          ),
        ),
        if (isOcupado) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: widget.toggling ? null : widget.onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.colorGlassDarkSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.colorSuccess.withValues(alpha: 0.6),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x1A1E1B4B),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_rounded,
                      color: AppTheme.colorSuccess, size: 15),
                  SizedBox(width: 6),
                  Text(
                    'Toca para ponerte DISPONIBLE y ver trabajos',
                    style: TextStyle(
                      color: AppTheme.colorText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Pestañas de la hoja de solicitudes: lo que se puede hacer hoy y lo que
/// está pedido para otros días. Cada una muestra cuántas hay.
class _WhenTabs extends StatelessWidget {
  const _WhenTabs({
    required this.showLater,
    required this.todayCount,
    required this.laterCount,
    required this.onChanged,
  });

  final bool showLater;
  final int todayCount;
  final int laterCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.colorBackgroundAccent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _tab(
            label: 'Para hoy',
            icon: Icons.bolt,
            count: todayCount,
            selected: !showLater,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 4),
          _tab(
            label: 'Programados',
            icon: Icons.event,
            count: laterCount,
            selected: showLater,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }

  Widget _tab({
    required String label,
    required IconData icon,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final color = selected ? AppTheme.colorPrimary : AppTheme.colorMuted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label, $count',
        excludeSemantics: true,
        child: Material(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          elevation: selected ? 1 : 0,
          shadowColor: const Color(0x401E1B4B),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? AppTheme.colorText : color,
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.colorPrimary
                          : AppTheme.colorMuted.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? Colors.white : AppTheme.colorText,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Título de un día en "Programados": "Mañana, mié 11 nov" o "Sáb 14 nov",
/// con cuánto falta y cuántos trabajos hay ese día.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.count});

  final DateTime day;
  final int count;

  static const _weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  static const _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysAway =
        day.difference(DateTime(now.year, now.month, now.day)).inDays;
    final date =
        '${_weekdays[day.weekday - 1]} ${day.day} ${_months[day.month - 1]}';
    final title = daysAway == 1
        ? 'Mañana, $date'
        : '${date[0].toUpperCase()}${date.substring(1)}';
    final jobs = count == 1 ? '1 trabajo' : '$count trabajos';
    final detail = daysAway == 1 ? jobs : 'En $daysAway días, $jobs';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          const Icon(Icons.event, size: 18, color: AppTheme.colorPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.colorText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            detail,
            style: const TextStyle(color: AppTheme.colorMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Una foto o el video de un anuncio de trabajo.
class _RequestMedia {
  const _RequestMedia({
    required this.url,
    this.previewUrl,
    this.isVideo = false,
  });

  final String url;

  /// Miniatura del video (las fotos se muestran con su propia url).
  final String? previewUrl;
  final bool isVideo;
}

/// Cabecera de la tarjeta con las fotos y el video del anuncio. Se desliza
/// de lado; tocar una foto la abre en grande y tocar el video lo reproduce.
class _RequestMediaHeader extends StatefulWidget {
  const _RequestMediaHeader({required this.media, required this.isNew});

  final List<_RequestMedia> media;
  final bool isNew;

  @override
  State<_RequestMediaHeader> createState() => _RequestMediaHeaderState();
}

class _RequestMediaHeaderState extends State<_RequestMediaHeader> {
  int _page = 0;

  void _open(_RequestMedia item) {
    if (item.isVideo) {
      showVideoPreview(context, item.url);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                InteractiveViewer(
                  child: Image.network(item.url, fit: BoxFit.contain),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _picture(_RequestMedia item) {
    final url = item.isVideo ? item.previewUrl ?? '' : item.url;
    const placeholder = ColoredBox(
      color: AppTheme.colorBackgroundAccent,
      child: Center(
        child: Icon(Icons.image_outlined,
            color: AppTheme.colorMuted, size: 36),
      ),
    );
    if (url.isEmpty) {
      return const ColoredBox(
        color: Color(0xFF2A2340),
        child: Center(
          child: Icon(Icons.videocam, color: Colors.white70, size: 40),
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
      errorBuilder: (context, _, __) => placeholder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final page = _page.clamp(0, media.length - 1);
    final current = media[page];
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        // Más ancha que alta: deja sitio a los botones de ofertar.
        aspectRatio: 2.15,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              itemCount: media.length,
              onPageChanged: (index) => setState(() => _page = index),
              itemBuilder: (context, index) {
                final item = media[index];
                return Semantics(
                  button: true,
                  label: item.isVideo
                      ? 'Reproducir video del trabajo'
                      : 'Ver foto ${index + 1} de ${media.length}',
                  child: GestureDetector(
                    onTap: () => _open(item),
                    child: _picture(item),
                  ),
                );
              },
            ),
            if (current.isVideo)
              const Positioned(
                top: 10,
                left: 10,
                child: IgnorePointer(
                  child: _MediaPill(
                    color: Color(0xB31E1B4B),
                    foreground: Colors.white,
                    icon: Icons.play_arrow_rounded,
                    label: 'Video',
                  ),
                ),
              ),
            if (widget.isNew)
              const Positioned(
                top: 10,
                right: 10,
                child: IgnorePointer(
                  child: _MediaPill(
                    color: Color(0xFFDDF5E4),
                    foreground: Color(0xFF14532D),
                    icon: Icons.check_circle,
                    iconColor: AppTheme.colorSuccess,
                    label: 'Nuevo',
                  ),
                ),
              ),
            if (media.length > 1)
              Positioned(
                right: 12,
                bottom: 10,
                child: IgnorePointer(
                  child: Row(
                    children: [
                      for (var i = 0; i < media.length; i++)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == page
                                ? AppTheme.colorPrimary
                                : Colors.white,
                            boxShadow: const [
                              BoxShadow(color: Color(0x40000000), blurRadius: 3),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta sobre la foto ("Video", "Nuevo").
class _MediaPill extends StatelessWidget {
  const _MediaPill({
    required this.color,
    required this.foreground,
    required this.icon,
    required this.label,
    this.iconColor,
  });

  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor ?? foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
