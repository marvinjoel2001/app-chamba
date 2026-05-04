import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../messages/presentation/screens/messages_screen.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';
import '../../../offers/presentation/screens/counter_offer_screen.dart';
import 'job_in_progress_screen.dart';

class IncomingRequestScreen extends StatefulWidget {
  const IncomingRequestScreen({super.key});

  @override
  State<IncomingRequestScreen> createState() => _IncomingRequestScreenState();
}

class _IncomingRequestScreenState extends State<IncomingRequestScreen>
    with SingleTickerProviderStateMixin {
  final RealtimeService _realtime = RealtimeService.instance;
  final MapController _mapController = MapController();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _request;
  int _offerLifetimeSeconds = 120;
  Timer? _ticker;
  Timer? _pollTimer;
  LatLng? _workerLocation;
  bool _available = true; // se actualiza desde la DB en _initLocation
  bool _togglingAvailability = false;

  // Animación banner oferta aceptada
  bool _showAcceptedBanner = false;
  late final AnimationController _acceptedAnimCtrl;
  late final Animation<double> _acceptedScale;
  late final Animation<double> _acceptedOpacity;

  // DraggableScrollableController para el bottom sheet
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();

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
    _realtime.on('offer.accepted', _onOfferAccepted);
    _realtime.on('offer.rejected', _onOfferRejected);
    _realtime.on('offer.expired', _onOfferExpired);
    _realtime.on('job.completed', _onJobCompleted);
    _realtime.on('job.cancelled', _onJobCancelled);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickOfferCountdown();
    });
    // Polling silencioso — no muestra spinner
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && _request == null) _load(silent: true);
    });

    _initLocation();
    _load();
  }

  @override
  void dispose() {
    _realtime.off('request.new', _onNewRequest);
    _realtime.off('offer.updated', _onRequestUpdated);
    _realtime.off('offer.accepted', _onOfferAccepted);
    _realtime.off('offer.rejected', _onOfferRejected);
    _realtime.off('offer.expired', _onOfferExpired);
    _realtime.off('job.completed', _onJobCompleted);
    _realtime.off('job.cancelled', _onJobCancelled);
    _ticker?.cancel();
    _pollTimer?.cancel();
    _acceptedAnimCtrl.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final loc = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _workerLocation = loc);
        // Mover el mapa a la ubicación real del dispositivo
        try {
          _mapController.move(loc, 14);
        } catch (_) {}
      }

      final user = SessionStore.currentUser;
      if (user != null) {
        await MobileBackendService.updateWorkerLocation(
          workerUserId: user.id,
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
      }
    } catch (_) {}
  }

  Future<void> _toggleAvailability(bool value) async {
    final user = SessionStore.currentUser;
    if (user == null || _togglingAvailability) return;
    setState(() {
      _togglingAvailability = true;
      _available = value;
    });
    try {
      await MobileBackendService.setAvailability(
        workerUserId: user.id,
        available: value,
      );
    } catch (_) {
      if (mounted) setState(() => _available = !value);
    } finally {
      if (mounted) setState(() => _togglingAvailability = false);
    }
  }

  void _onNewRequest(dynamic payload) => _load(silent: true);

  void _onJobCompleted(dynamic _) {
    SessionStore.activeRequestId = null;
    SessionStore.activeThreadId = null;
    if (mounted) {
      setState(() => _request = null);
    }
  }

  void _onJobCancelled(dynamic _) {
    SessionStore.activeRequestId = null;
    SessionStore.activeThreadId = null;
    if (mounted) {
      setState(() => _request = null);
      // Banner rojo de cancelación
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.cancel, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'El cliente canceló el trabajo',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: AppTheme.colorError,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        const SnackBar(content: Text('Tu oferta expiró. Puedes mejorarla.')),
      );
    }
    _load(silent: true);
  }

  void _tickOfferCountdown() {
    final request = _request;
    if (!mounted || request == null) return;
    final offer = request['workerOffer'];
    if (offer is! Map<String, dynamic>) return;
    if (offer['status']?.toString() != 'pending') return;
    final remaining = (offer['secondsRemaining'] as num?)?.toInt();
    if (remaining == null) return;
    if (remaining <= 1) {
      _load();
      return;
    }
    setState(() => offer['secondsRemaining'] = remaining - 1);
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
      final response = await MobileBackendService.incomingRequest(
        workerUserId: user.id,
      );
      final request = response['request'];
      final mutableRequest = _toMutableRequest(request);

      // Si la solicitud está completada o cancelada, limpiar y no mostrar
      final requestStatus = mutableRequest?['status']?.toString();
      if (requestStatus == 'completed' || requestStatus == 'cancelled') {
        SessionStore.activeRequestId = null;
        SessionStore.activeThreadId = null;
        if (mounted) {
          setState(() {
            _request = null;
            _loading = false;
          });
        }
        return;
      }

      SessionStore.activeRequestId = mutableRequest?['id']?.toString();

      final offerStatus = (mutableRequest?['workerOffer'] as Map?)?['status']
          ?.toString();
      if (offerStatus == 'accepted' && !_showAcceptedBanner && mounted) {
        setState(() => _showAcceptedBanner = true);
        _acceptedAnimCtrl.forward(from: 0);
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() => _showAcceptedBanner = false);
        });
      }

      // Cuando la oferta está aceptada, expandir el sheet para mostrar
      // ambos botones (VER TRABAJO + CHATEAR) sin que queden tapados
      if (offerStatus == 'accepted' && mounted) {
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
          _request = mutableRequest;
          _offerLifetimeSeconds =
              (response['offerLifetimeSeconds'] as num?)?.toInt() ?? 120;
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

  void _openJobInProgress() {
    final requestId = _request?['id']?.toString();
    if (requestId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JobInProgressScreen(requestId: requestId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final req = _request;
    final workerOffer = req?['workerOffer'] as Map<String, dynamic>?;
    final offerStatus = workerOffer?['status']?.toString();
    final secondsRemaining = (workerOffer?['secondsRemaining'] as num?)
        ?.toInt();
    final hasPendingOffer = offerStatus == 'pending';
    final isAcceptedOffer = offerStatus == 'accepted';
    final mapCenter = _workerLocation ?? const LatLng(-16.5002, -68.1342);

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

          // ── BARRA SUPERIOR: disponibilidad ────────────────────────────
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
                    // Botón ajustes pegado a la derecha
                    Positioned(
                      right: 0,
                      child: Material(
                        color: AppTheme.colorGlassDarkSoft,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: _load,
                          borderRadius: BorderRadius.circular(14),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              Icons.tune,
                              color: AppTheme.colorText,
                              size: 22,
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
                // Un único ListView con el scrollController del sheet.
                // Esto hace que arrastrar desde cualquier parte expanda el sheet.
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  physics: const ClampingScrollPhysics(),
                  children: [
                    // ── Handle ──────────────────────────────────────
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
                    // ── Contenido ────────────────────────────────────
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(child: Text(_error!)),
                      )
                    else if (req == null)
                      _buildEmptyContent(navPadding)
                    else
                      _buildRequestContent(
                        req,
                        workerOffer,
                        offerStatus,
                        secondsRemaining,
                        hasPendingOffer,
                        isAcceptedOffer,
                        navPadding,
                      ),
                  ],
                ),
              );
            },
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
                ? 'Estás disponible. Las solicitudes aparecerán aquí.'
                : 'Estás ocupado. Activa disponibilidad para recibir trabajos.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.colorMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestContent(
    Map<String, dynamic> req,
    Map<String, dynamic>? workerOffer,
    String? offerStatus,
    int? secondsRemaining,
    bool hasPendingOffer,
    bool isAcceptedOffer,
    double bottomPadding,
  ) {
    final offerProgress = secondsRemaining == null
        ? null
        : (secondsRemaining / _offerLifetimeSeconds).clamp(0.0, 1.0).toDouble();

    final distanceText = req['distanceKm'] == null
        ? null
        : '${(req['distanceKm'] as num).toStringAsFixed(1)} km';

    final currentBudget = (req['budget'] as num?)?.toDouble() ?? 0;
    final myOfferAmount = (workerOffer?['amount'] as num?)?.toDouble();

    // El cliente mejoró su oferta si el budget actual es mayor que mi oferta
    final clientImproved =
        hasPendingOffer &&
        myOfferAmount != null &&
        currentBudget > myOfferAmount;

    // Color del precio según estado
    final priceColor = clientImproved
        ? AppTheme.colorSuccess
        : hasPendingOffer
        ? AppTheme.colorMuted
        : AppTheme.colorText;

    final borderColor = isAcceptedOffer
        ? AppTheme.colorSuccess.withValues(alpha: 0.5)
        : clientImproved
        ? AppTheme.colorSuccess.withValues(alpha: 0.3)
        : AppTheme.colorGlassBorderSoft;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111C30),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Fila 1: precio + categoría + distancia + badge ────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Precio actual (puede ser el del cliente mejorado)
                Text(
                  'Bs ${currentBudget.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: priceColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.colorPrimary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    req['priceType']?.toString() ??
                        req['category']?.toString() ??
                        'General',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (distanceText != null) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.location_on,
                    color: AppTheme.colorMuted,
                    size: 12,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    distanceText,
                    style: const TextStyle(
                      color: AppTheme.colorMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
                const Spacer(),
                if (isAcceptedOffer)
                  _StatusBadge(label: 'ACEPTADA', color: AppTheme.colorSuccess)
                else if (clientImproved)
                  _StatusBadge(
                    label: '↑ MEJORADA',
                    color: AppTheme.colorSuccess,
                  )
                else if (hasPendingOffer)
                  _StatusBadge(
                    label: 'ENVIADA',
                    color: AppTheme.colorHighlight,
                  ),
              ],
            ),

            // ── Mi oferta (si existe) ──────────────────────────────
            if (myOfferAmount != null && !isAcceptedOffer) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Precio original: Bs ${myOfferAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppTheme.colorMuted,
                      fontSize: 11,
                    ),
                  ),
                  if (clientImproved) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_upward,
                      color: AppTheme.colorSuccess,
                      size: 12,
                    ),
                    Text(
                      ' El cliente subió su oferta',
                      style: const TextStyle(
                        color: AppTheme.colorSuccess,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],

            const SizedBox(height: 8),
            // ── Descripción ───────────────────────────────────────
            Text(
              req['description']?.toString() ?? '',
              style: const TextStyle(
                color: AppTheme.colorText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Estado de espera (oferta pendiente sin mejora) ────
            if (hasPendingOffer && !clientImproved && !isAcceptedOffer) ...[
              const SizedBox(height: 6),
              const Text(
                'Esperando que el cliente acepte tu oferta...',
                style: TextStyle(color: AppTheme.colorMuted, fontSize: 12),
              ),
            ],

            // ── Barra de tiempo ────────────────────────────────────
            if (offerProgress != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        value: offerProgress,
                        backgroundColor: AppTheme.colorPrimary.withValues(
                          alpha: 0.14,
                        ),
                        color: offerProgress > 0.3
                            ? AppTheme.colorPrimary
                            : AppTheme.colorError,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${secondsRemaining}s',
                    style: const TextStyle(
                      color: AppTheme.colorMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            const Divider(color: Color(0xFF1E2D45), height: 1, thickness: 1),
            const SizedBox(height: 12),

            // ── Botones según estado ───────────────────────────────
            if (isAcceptedOffer) ...[
              ChambaPrimaryButton(
                label: 'VER TRABAJO EN CURSO',
                icon: Icons.directions_run,
                isYellow: true,
                onPressed: _openJobInProgress,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MessagesScreen(),
                  ),
                ),
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  color: AppTheme.colorPrimary,
                  size: 16,
                ),
                label: const Text(
                  'Chatear con el cliente',
                  style: TextStyle(color: AppTheme.colorPrimary, fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppTheme.colorPrimary.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ] else if (hasPendingOffer && !clientImproved) ...[
              // Oferta enviada, esperando — solo mostrar info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.colorHighlight.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.colorHighlight.withValues(alpha: 0.3),
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.hourglass_top,
                      color: AppTheme.colorHighlight,
                      size: 20,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tu oferta fue enviada',
                      style: TextStyle(
                        color: AppTheme.colorHighlight,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Esperando respuesta del cliente',
                      style: TextStyle(
                        color: AppTheme.colorMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _request = null;
                    SessionStore.activeRequestId = null;
                  });
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 36),
                ),
                child: const Text(
                  'No me interesa',
                  style: TextStyle(color: AppTheme.colorMuted, fontSize: 13),
                ),
              ),
            ] else ...[
              // Sin oferta o cliente mejoró → mostrar botones de acción
              if (clientImproved)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.colorSuccess.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.colorSuccess.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.trending_up,
                          color: AppTheme.colorSuccess,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '¡El cliente subió su oferta a Bs ${currentBudget.toStringAsFixed(0)}!',
                          style: const TextStyle(
                            color: AppTheme.colorSuccess,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: ChambaPrimaryButton(
                      label: 'ACEPTAR',
                      icon: Icons.check_circle,
                      isYellow: true,
                      onPressed: () async {
                        final user = SessionStore.currentUser;
                        if (user == null) return;
                        try {
                          await MobileBackendService.counterOffer(
                            requestId: req['id'] as String,
                            workerUserId: user.id,
                            amount: currentBudget,
                            message: 'Acepto el precio ofertado.',
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Oferta enviada')),
                          );
                          await _load();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString().replaceFirst('Exception: ', ''),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChambaPrimaryButton(
                      label: 'OFERTAR',
                      icon: Icons.payments,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CounterOfferScreen(
                              requestId: req['id'] as String,
                              originalBudget: currentBudget,
                              requestData: req,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _request = null;
                    SessionStore.activeRequestId = null;
                  });
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 36),
                ),
                child: const Text(
                  'No me interesa',
                  style: TextStyle(color: AppTheme.colorMuted, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
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
          color: active
              ? activeColor
              : AppTheme.colorMuted.withValues(alpha: 0.5),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
