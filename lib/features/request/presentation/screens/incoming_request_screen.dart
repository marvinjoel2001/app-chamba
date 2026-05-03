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
  bool _available = true;
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

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickOfferCountdown();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && _request == null) _load();
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
          perm == LocationPermission.deniedForever)
        return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final loc = LatLng(pos.latitude, pos.longitude);
      if (mounted) setState(() => _workerLocation = loc);

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

  void _onNewRequest(dynamic payload) => _load();

  void _onRequestUpdated(dynamic payload) {
    final userId = SessionStore.currentUser?.id;
    final map = payload is Map ? Map<String, dynamic>.from(payload) : const {};
    if (map['workerUserId'] != null && map['workerUserId'].toString() != userId)
      return;
    _load();
  }

  void _onOfferAccepted(dynamic payload) {
    final userId = SessionStore.currentUser?.id;
    final map = payload is Map ? Map<String, dynamic>.from(payload) : const {};
    if (map['workerUserId'] != null && map['workerUserId'].toString() != userId)
      return;
    if (mounted) {
      setState(() => _showAcceptedBanner = true);
      _acceptedAnimCtrl.forward(from: 0);
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _showAcceptedBanner = false);
      });
    }
    _load();
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
    _load();
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
    _load();
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

  Future<void> _load() async {
    final user = SessionStore.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Sesión expirada';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await MobileBackendService.incomingRequest(
        workerUserId: user.id,
      );
      final request = response['request'];
      final mutableRequest = _toMutableRequest(request);
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

      setState(() {
        _request = mutableRequest;
        _offerLifetimeSeconds =
            (response['offerLifetimeSeconds'] as num?)?.toInt() ?? 120;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
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
            snapSizes: const [0.12, 0.32, 0.85],
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0D1728),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    // Handle
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 6),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.colorMuted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Contenido scrollable
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                          ? Center(child: Text(_error!))
                          : req == null
                          ? _buildEmptyState(scrollController)
                          : _buildRequestCard(
                              scrollController,
                              req,
                              workerOffer,
                              offerStatus,
                              secondsRemaining,
                              hasPendingOffer,
                              isAcceptedOffer,
                            ),
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

  Widget _buildEmptyState(ScrollController sc) {
    return ListView(
      controller: sc,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        const SizedBox(height: 16),
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
    );
  }

  Widget _buildRequestCard(
    ScrollController sc,
    Map<String, dynamic> req,
    Map<String, dynamic>? workerOffer,
    String? offerStatus,
    int? secondsRemaining,
    bool hasPendingOffer,
    bool isAcceptedOffer,
  ) {
    final offerProgress = secondsRemaining == null
        ? null
        : (secondsRemaining / _offerLifetimeSeconds).clamp(0.0, 1.0).toDouble();

    return ListView(
      controller: sc,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // ── Card principal de la solicitud ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111C30),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.colorGlassBorderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Precio + badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Bs ${req['budget']}',
                    style: const TextStyle(
                      color: AppTheme.colorText,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.colorPrimary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      req['priceType']?.toString() ??
                          req['category']?.toString() ??
                          'General',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isAcceptedOffer)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.colorSuccessSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.colorSuccess.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Text(
                        'ACEPTADA',
                        style: TextStyle(
                          color: AppTheme.colorSuccess,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // Distancia
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppTheme.colorMuted,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    req['distanceKm'] == null
                        ? 'Distancia no disponible'
                        : 'A ${(req['distanceKm'] as num).toStringAsFixed(1)} km de tu ubicación',
                    style: const TextStyle(
                      color: AppTheme.colorMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Descripción
              Text(
                req['description']?.toString() ?? '',
                style: const TextStyle(color: AppTheme.colorText, fontSize: 15),
              ),
              // Barra de tiempo de oferta
              if (offerProgress != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 4,
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
                    const SizedBox(width: 8),
                    Text(
                      '${secondsRemaining}s',
                      style: const TextStyle(
                        color: AppTheme.colorMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Botones de acción ───────────────────────────────────────────
        if (isAcceptedOffer) ...[
          // Trabajo aceptado → ir a pantalla de trabajo en curso
          ChambaPrimaryButton(
            label: 'VER TRABAJO EN CURSO',
            icon: Icons.directions_run,
            isYellow: true,
            onPressed: _openJobInProgress,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MessagesScreen()),
            ),
            icon: const Icon(
              Icons.chat_bubble_outline,
              color: AppTheme.colorPrimary,
            ),
            label: const Text(
              'Chatear con el cliente',
              style: TextStyle(color: AppTheme.colorPrimary),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: AppTheme.colorPrimary.withValues(alpha: 0.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: ChambaPrimaryButton(
                  label: 'ACEPTAR',
                  icon: Icons.check_circle,
                  isYellow: true,
                  onPressed: hasPendingOffer
                      ? null
                      : () async {
                          final user = SessionStore.currentUser;
                          if (user == null) return;
                          try {
                            await MobileBackendService.counterOffer(
                              requestId: req['id'] as String,
                              workerUserId: user.id,
                              amount: (req['budget'] as num).toDouble(),
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
              const SizedBox(width: 10),
              Expanded(
                child: ChambaPrimaryButton(
                  label: 'OFERTAR',
                  icon: Icons.payments,
                  onPressed: hasPendingOffer
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CounterOfferScreen(
                                requestId: req['id'] as String,
                              ),
                            ),
                          );
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _request = null;
                SessionStore.activeRequestId = null;
              });
            },
            child: const Text(
              'No me interesa',
              style: TextStyle(color: AppTheme.colorMuted),
            ),
          ),
        ],
      ],
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
