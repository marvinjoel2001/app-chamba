import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/navigation/app_flows.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../state/request_dependencies.dart';
import '../../../../../features/offers/presentation/screens/offers_screen.dart';

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
  String? _error;
  String? _infoMessage;
  Map<String, dynamic>? _status;

  // Animación de ondas radar
  late final AnimationController _radarCtrl;
  late final List<Animation<double>> _radarWaves;

  // Animación de puntos "Buscando..."
  int _dotsCount = 0;
  Timer? _dotsTimer;

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

    // Dots: 0 → 1 → 2 → 3 → 0 cada 500ms
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dotsCount = (_dotsCount + 1) % 4);
    });

    final userId = SessionStore.currentUser?.id;
    _realtime.connect(userId: userId);
    _realtime.on('offer.new', _onOfferEvent);
    _realtime.on('offer.accepted', _onOfferEvent);
    _realtime.on('job.completed', _onJobCompleted);
    _realtime.on('job.cancelled', _onJobCancelled);
    _load();
  }

  @override
  void dispose() {
    _realtime.off('offer.new', _onOfferEvent);
    _realtime.off('offer.accepted', _onOfferEvent);
    _realtime.off('job.completed', _onJobCompleted);
    _realtime.off('job.cancelled', _onJobCancelled);
    _radarCtrl.dispose();
    _dotsTimer?.cancel();
    super.dispose();
  }

  void _onJobCompleted(dynamic _) {
    // Navegación centralizada: evita que varias pantallas del stack
    // abran la calificación a la vez.
    AppFlows.goToRating();
  }

  void _onJobCancelled(dynamic _) {
    AppFlows.goHomeAfterCancellation();
  }

  void _onOfferEvent(dynamic payload) => _load();

  bool _isNoRequestError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('no request found') ||
        normalized.contains('requestid or clientuserid is required') ||
        normalized.contains('no se encontró la información solicitada');
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
        _status = null;
      });
      return;
    }

    // Solo spinner en carga inicial
    if (_status == null) {
      setState(() {
        _loading = true;
        _error = null;
        _infoMessage = null;
      });
    }

    try {
      final response = (await RequestDependencies.getRequestStatus(
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
      if (mounted) {
        setState(() {
          _status = response;
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
            _status = null;
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

  @override
  Widget build(BuildContext context) {
    final request = _status?['request'] as Map<String, dynamic>?;
    final metrics = _status?['metrics'] as Map<String, dynamic>?;
    final offers = _status?['topOffers'] as List<dynamic>? ?? const [];

    final lat = widget.latitude ?? -16.5002;
    final lng = widget.longitude ?? -68.1342;
    final mapCenter = LatLng(lat, lng);

    final dots = '.' * _dotsCount;
    final dotsPlaceholder = '   ';

    return Scaffold(
      backgroundColor: AppTheme.colorBackground,
      body: Column(
        children: [
          // ── MAPA (ocupa el espacio restante) ──────────────────────────
          Expanded(
            child: Stack(
              children: [
                // Mapa de fondo
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
                                    waves: _radarWaves
                                        .map((a) => a.value)
                                        .toList(),
                                    color: AppTheme.colorPrimary,
                                  ),
                                  size: Size.infinite,
                                );
                              },
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: mapCenter,
                                  width: 52,
                                  height: 52,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.colorPrimary,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.colorPrimary
                                              .withValues(alpha: 0.6),
                                          blurRadius: 16,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.my_location,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
                // Header sobre el mapa
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.colorGlassDarkSoft,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.colorGlassDarkSoft,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.colorGlassBorderSoft,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.colorPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Notificando trabajadores$dots${dotsPlaceholder.substring(dots.length)}',
                                style: const TextStyle(
                                  color: AppTheme.colorText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.colorGlassDarkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── BOTTOM CARD (altura fija, siempre visible) ────────────────
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D1728),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.colorMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.colorPrimary.withValues(alpha: 0.15),
                    border: Border.all(
                      color: AppTheme.colorPrimary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.radar,
                    color: AppTheme.colorPrimary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  request == null
                      ? 'Sin solicitud activa'
                      : 'Solicitud: ${request['title']}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ??
                      _infoMessage ??
                      'Estamos conectando con los mejores perfiles cerca de ti',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.colorMuted),
                ),
                const SizedBox(height: 20),
                if (_loading && _status == null)
                  const SizedBox(
                    height: 48,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          value: '${metrics?['offersCount'] ?? 0}',
                          label: 'Ofertas',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          value: metrics?['estimatedMinutes'] == null
                              ? '--'
                              : '~${metrics!['estimatedMinutes']} min',
                          label: 'Tiempo est.',
                        ),
                      ),
                    ],
                  ),
                if (offers.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.colorPrimary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      'Mejor oferta: Bs ${offers.first['amount']}',
                      style: const TextStyle(color: AppTheme.colorPrimaryLight),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    final user = SessionStore.currentUser;
                    final requestId = SessionStore.activeRequestId;
                    if (user == null || requestId == null) {
                      Navigator.of(context).pop();
                      return;
                    }
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppTheme.colorBackgroundAccent,
                        title: const Text('Cancelar solicitud'),
                        content: const Text(
                          '¿Estás seguro de que deseas cancelar esta solicitud?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('No'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Sí, cancelar',
                              style: TextStyle(color: AppTheme.colorError),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    try {
                      (await RequestDependencies.cancelJob(
                        requestId: requestId,
                        userId: user.id,
                      ))
                          .fold(
                        onSuccess: (value) => value,
                        onFailure: (failure) =>
                            throw Exception(failure.message),
                      );
                    } catch (_) {}
                    // Limpiar sesión independientemente del resultado
                    SessionStore.activeRequestId = null;
                    SessionStore.activeThreadId = null;
                    if (!context.mounted) return;
                    AppFlows.goHomeAfterCancellation(message: 'Solicitud cancelada');
                  },
                  child: const Text(
                    'Cancelar solicitud',
                    style: TextStyle(color: AppTheme.colorMuted),
                  ),
                ),
                const SizedBox(height: 8),
                ChambaPrimaryButton(
                  label: 'Ver ofertas',
                  onPressed: request == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const OffersScreen(),
                            ),
                          );
                        },
                ),
              ],
            ),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.colorSurfaceSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.colorPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(label, style: const TextStyle(color: AppTheme.colorMuted)),
        ],
      ),
    );
  }
}
