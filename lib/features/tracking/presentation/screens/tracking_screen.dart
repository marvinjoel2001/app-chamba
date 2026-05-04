import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../messages/presentation/screens/chat_screen.dart';
import '../../../messages/presentation/screens/messages_screen.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final RealtimeService _realtime = RealtimeService.instance;
  final MapController _mapController = MapController();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _tracking;
  Timer? _pollTimer;
  bool _confirmingArrival = false;

  @override
  void initState() {
    super.initState();
    _realtime.on('job.worker_arrived', _onWorkerArrived);
    _realtime.on('job.completed', _onJobCompleted);
    _realtime.on('job.cancelled', _onJobCancelled);
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
    _load();
  }

  @override
  void dispose() {
    _realtime.off('job.worker_arrived', _onWorkerArrived);
    _realtime.off('job.completed', _onJobCompleted);
    _realtime.off('job.cancelled', _onJobCancelled);
    _pollTimer?.cancel();
    super.dispose();
  }

  void _onWorkerArrived(dynamic _) {
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡El trabajador ha llegado! Confirma su llegada.'),
          backgroundColor: AppTheme.colorSuccess,
        ),
      );
    }
  }

  void _onJobCompleted(dynamic _) {
    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.colorBackgroundAccent,
          title: const Text(
            '¡Trabajo completado!',
            style: TextStyle(color: AppTheme.colorSuccess),
          ),
          content: const Text(
            'El trabajador marcó el trabajo como completado.',
            style: TextStyle(color: AppTheme.colorMuted),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    }
  }

  void _onJobCancelled(dynamic _) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El trabajo fue cancelado.')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _ensureActiveThread() async {
    final user = SessionStore.currentUser;
    final requestId = SessionStore.activeRequestId;
    final workerId = _tracking?['worker']?['id']?.toString();
    if (user == null || requestId == null || workerId == null) return;

    final response = await MobileBackendService.messages(userId: user.id);
    final threads = response['threads'] as List<dynamic>? ?? const [];
    for (final thread in threads) {
      final map = thread as Map<String, dynamic>;
      final counterpart = map['counterpart'] as Map<String, dynamic>? ?? {};
      if (map['requestId']?.toString() == requestId &&
          counterpart['id']?.toString() == workerId) {
        SessionStore.activeThreadId = map['id']?.toString();
        return;
      }
    }
  }

  Future<void> _load() async {
    final requestId = SessionStore.activeRequestId;
    if (requestId == null) {
      setState(() {
        _error = 'No hay solicitud activa para rastrear.';
        _loading = false;
      });
      return;
    }
    // Solo spinner en carga inicial
    if (_tracking == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await MobileBackendService.tracking(
        requestId: requestId,
      );
      _tracking = response;
      if (SessionStore.activeThreadId == null) {
        await _ensureActiveThread();
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _confirmArrival() async {
    final user = SessionStore.currentUser;
    final requestId = SessionStore.activeRequestId;
    if (user == null || requestId == null) return;

    setState(() => _confirmingArrival = true);
    try {
      await MobileBackendService.clientConfirmArrival(
        requestId: requestId,
        clientUserId: user.id,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Llegada confirmada. El trabajador puede iniciar.'),
          backgroundColor: AppTheme.colorSuccess,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _confirmingArrival = false);
    }
  }

  Future<void> _cancelJob() async {
    final user = SessionStore.currentUser;
    final requestId = SessionStore.activeRequestId;
    if (user == null || requestId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.colorBackgroundAccent,
        title: const Text('Cancelar trabajo'),
        content: const Text('¿Estás seguro de que deseas cancelar?'),
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
      await MobileBackendService.cancelJob(
        requestId: requestId,
        userId: user.id,
      );
      if (!mounted) return;
      // Limpiar sesión del cliente
      SessionStore.activeRequestId = null;
      SessionStore.activeThreadId = null;
      // Volver al inicio (no solo pop — evita pantalla negra)
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final worker = _tracking?['worker'] as Map<String, dynamic>?;
    final workerArrived = _tracking?['workerArrived'] as bool? ?? false;
    final clientConfirmed =
        _tracking?['clientConfirmedArrival'] as bool? ?? false;
    final etaMinutes = _tracking?['etaMinutes'];
    final distanceKm = _tracking?['distanceKm'];
    final address = _tracking?['address']?.toString() ?? '';
    final title = _tracking?['title']?.toString() ?? 'Servicio en curso';
    final amount = _tracking?['agreedAmount'];

    final workerLat = (worker?['latitude'] as num?)?.toDouble();
    final workerLng = (worker?['longitude'] as num?)?.toDouble();
    final destLat = (_tracking?['destination']?['latitude'] as num?)
        ?.toDouble();
    final destLng = (_tracking?['destination']?['longitude'] as num?)
        ?.toDouble();

    // Posición del worker (se actualiza con el polling)
    final workerPos = workerLat != null && workerLng != null
        ? LatLng(workerLat, workerLng)
        : const LatLng(-16.5002, -68.1342);

    // Destino (ubicación del trabajo = donde está el cliente)
    final destPos = destLat != null && destLng != null
        ? LatLng(destLat, destLng)
        : null;

    // Centro: punto medio entre worker y destino
    final mapCenter = destPos != null
        ? LatLng(
            (workerPos.latitude + destPos.latitude) / 2,
            (workerPos.longitude + destPos.longitude) / 2,
          )
        : workerPos;

    return Scaffold(
      backgroundColor: AppTheme.colorBackground,
      body: Stack(
        children: [
          // ── MAPA ──────────────────────────────────────────────────────
          Positioned.fill(
            bottom: 320,
            child: AppConfig.mapboxAccessToken.trim().isEmpty
                ? Container(
                    color: AppTheme.colorBackgroundAccent,
                    child: const Center(
                      child: Icon(
                        Icons.map,
                        color: AppTheme.colorMuted,
                        size: 64,
                      ),
                    ),
                  )
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: mapCenter,
                      initialZoom: destPos != null ? 13 : 15,
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
                      // Línea de ruta worker → destino
                      if (destPos != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [workerPos, destPos],
                              color: AppTheme.colorSuccess.withValues(
                                alpha: 0.8,
                              ),
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          // Marcador del worker (en movimiento)
                          Marker(
                            point: workerPos,
                            width: 48,
                            height: 48,
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
                                    color: AppTheme.colorPrimary.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.engineering,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          // Marcador del destino (tu ubicación = cliente)
                          if (destPos != null)
                            Marker(
                              point: destPos,
                              width: 52,
                              height: 52,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.colorSuccess,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.colorSuccess.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 14,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.home,
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

          // ── ETA BADGE ─────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2A1A),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AppTheme.colorSuccess.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.navigation,
                        color: AppTheme.colorSuccess,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            etaMinutes != null ? '$etaMinutes min' : '--',
                            style: const TextStyle(
                              color: AppTheme.colorText,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            'LLEGADA\nESTIMADA',
                            style: TextStyle(
                              color: AppTheme.colorSuccess,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── BACK BUTTON ───────────────────────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.colorGlassDarkSoft,
                  ),
                ),
              ),
            ),
          ),

          // ── CONTROLES DE MAPA ─────────────────────────────────────────
          Positioned(
            right: 12,
            top: MediaQuery.of(context).padding.top + 12,
            child: Column(
              children: [
                _MapBtn(
                  icon: Icons.add,
                  onTap: () {
                    final z = (_mapController.camera.zoom + 1).clamp(3.0, 20.0);
                    _mapController.move(_mapController.camera.center, z);
                  },
                ),
                const SizedBox(height: 8),
                _MapBtn(
                  icon: Icons.remove,
                  onTap: () {
                    final z = (_mapController.camera.zoom - 1).clamp(3.0, 20.0);
                    _mapController.move(_mapController.camera.center, z);
                  },
                ),
                const SizedBox(height: 8),
                _MapBtn(
                  icon: Icons.center_focus_strong,
                  highlighted: true,
                  onTap: () => _mapController.move(mapCenter, 13),
                ),
              ],
            ),
          ),

          // ── BOTTOM CARD ───────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0D1728),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Text(
                      _error!,
                      style: const TextStyle(color: AppTheme.colorError),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.colorMuted.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        // Status + monto
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.colorSuccessSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                workerArrived
                                    ? clientConfirmed
                                          ? 'EN TRABAJO'
                                          : '¡LLEGÓ!'
                                    : 'EN CAMINO',
                                style: const TextStyle(
                                  color: AppTheme.colorSuccess,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              amount != null ? 'Bs $amount' : '',
                              style: const TextStyle(
                                color: AppTheme.colorText,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppTheme.colorText,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Info del worker
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppTheme.colorSurfaceSoft,
                              backgroundImage:
                                  worker?['profilePhotoUrl'] != null
                                  ? NetworkImage(
                                      worker!['profilePhotoUrl'] as String,
                                    )
                                  : null,
                              child: worker?['profilePhotoUrl'] == null
                                  ? Text(
                                      (worker?['firstName'] ?? 'W')
                                          .toString()
                                          .substring(0, 1),
                                      style: const TextStyle(
                                        color: AppTheme.colorText,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${worker?['firstName'] ?? ''} ${worker?['lastName'] ?? ''}'
                                        .trim(),
                                    style: const TextStyle(
                                      color: AppTheme.colorText,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: AppTheme.colorMuted,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          address,
                                          style: const TextStyle(
                                            color: AppTheme.colorMuted,
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
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Distancia
                        if (distanceKm != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.colorSurfaceSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.straighten,
                                  color: AppTheme.colorMuted,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${(distanceKm as num).toStringAsFixed(1)} km de distancia',
                                  style: const TextStyle(
                                    color: AppTheme.colorMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        // Botones
                        Row(
                          children: [
                            // Confirmar llegada (solo si el worker llegó y no se confirmó aún)
                            Expanded(
                              flex: 3,
                              child: ChambaPrimaryButton(
                                label: clientConfirmed
                                    ? 'Llegada confirmada ✓'
                                    : workerArrived
                                    ? 'CONFIRMAR LLEGADA'
                                    : 'Esperando al trabajador...',
                                icon: clientConfirmed
                                    ? Icons.check_circle
                                    : workerArrived
                                    ? Icons.where_to_vote
                                    : Icons.hourglass_top,
                                isYellow: workerArrived && !clientConfirmed,
                                onPressed: workerArrived && !clientConfirmed
                                    ? (_confirmingArrival
                                          ? null
                                          : _confirmArrival)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Chat
                            _ActionIconButton(
                              icon: Icons.chat_bubble_outline,
                              color: AppTheme.colorPrimary,
                              onTap: () async {
                                if (SessionStore.activeThreadId == null) {
                                  await _ensureActiveThread();
                                }
                                final threadId = SessionStore.activeThreadId;
                                if (threadId == null) {
                                  if (!context.mounted) return;
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const MessagesScreen(),
                                    ),
                                  );
                                  return;
                                }
                                if (!context.mounted) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ChatScreen(
                                      threadId: threadId,
                                      title:
                                          '${worker?['firstName'] ?? ''} ${worker?['lastName'] ?? ''}'
                                              .trim(),
                                      avatarUrl:
                                          worker?['profilePhotoUrl'] as String?,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _cancelJob,
                          child: const Text(
                            'Cancelar trabajo',
                            style: TextStyle(color: AppTheme.colorError),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _MapBtn extends StatelessWidget {
  const _MapBtn({
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? AppTheme.colorPrimary : AppTheme.colorGlassDarkSoft,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            color: highlighted ? Colors.white : AppTheme.colorText,
            size: 20,
          ),
        ),
      ),
    );
  }
}
