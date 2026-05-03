import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/session/unread_messages_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../messages/presentation/screens/chat_screen.dart';
import '../../../messages/presentation/screens/messages_screen.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';

class JobInProgressScreen extends StatefulWidget {
  const JobInProgressScreen({required this.requestId, super.key});

  final String requestId;

  @override
  State<JobInProgressScreen> createState() => _JobInProgressScreenState();
}

class _JobInProgressScreenState extends State<JobInProgressScreen> {
  final RealtimeService _realtime = RealtimeService.instance;
  final MapController _mapController = MapController();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _tracking;
  Timer? _pollTimer;
  Timer? _locationTimer;
  LatLng? _deviceLocation; // ubicación real del GPS

  @override
  void initState() {
    super.initState();
    _realtime.on('job.client_confirmed', _onClientConfirmed);
    _realtime.on('job.completed', _onJobCompleted);
    _realtime.on('job.cancelled', _onJobCancelled);
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
    // Actualizar ubicación GPS cada 5 segundos
    _locationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _updateDeviceLocation(),
    );
    _load();
    _updateDeviceLocation();
  }

  @override
  void dispose() {
    _realtime.off('job.client_confirmed', _onClientConfirmed);
    _realtime.off('job.completed', _onJobCompleted);
    _realtime.off('job.cancelled', _onJobCancelled);
    _pollTimer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateDeviceLocation() async {
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
          timeLimit: Duration(seconds: 8),
        ),
      );
      final loc = LatLng(pos.latitude, pos.longitude);

      if (mounted) {
        setState(() => _deviceLocation = loc);
      }

      // Sincronizar con el backend
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

  void _onClientConfirmed(dynamic _) => _load();

  void _onJobCompleted(dynamic _) {
    if (mounted) {
      // Limpiar sesión del trabajo activo
      SessionStore.activeRequestId = null;
      SessionStore.activeThreadId = null;

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
            'El trabajo ha sido marcado como completado. ¡Buen trabajo!',
            style: TextStyle(color: AppTheme.colorMuted),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Cerrar diálogo y volver al inicio (pop hasta la raíz)
                Navigator.of(context).popUntil((route) => route.isFirst);
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
      SessionStore.activeRequestId = null;
      SessionStore.activeThreadId = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El trabajo fue cancelado.')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _load() async {
    if (_tracking == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final res = await MobileBackendService.tracking(
        requestId: widget.requestId,
      );
      if (mounted) {
        setState(() {
          _tracking = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _markArrived() async {
    final user = SessionStore.currentUser;
    if (user == null) return;
    try {
      await MobileBackendService.workerMarkArrived(
        requestId: widget.requestId,
        workerUserId: user.id,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Llegada marcada. Esperando confirmación del cliente.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _completeJob() async {
    final user = SessionStore.currentUser;
    if (user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.colorBackgroundAccent,
        title: const Text('Marcar como completado'),
        content: const Text(
          '¿Confirmas que el trabajo fue completado satisfactoriamente?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Confirmar',
              style: TextStyle(color: AppTheme.colorSuccess),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await MobileBackendService.completeJob(
        requestId: widget.requestId,
        workerUserId: user.id,
      );
      if (!mounted) return;

      // Limpiar sesión del trabajo activo
      SessionStore.activeRequestId = null;
      SessionStore.activeThreadId = null;

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
            '¡Excelente trabajo!',
            style: TextStyle(color: AppTheme.colorMuted),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Cerrar diálogo y volver al inicio
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  /// Abre el chat directo con el cliente del trabajo en curso
  Future<void> _openChat() async {
    final user = SessionStore.currentUser;
    if (user == null) return;

    String? threadId = SessionStore.activeThreadId;
    final client = _tracking?['client'] as Map<String, dynamic>?;

    if (threadId == null) {
      try {
        final response = await MobileBackendService.messages(userId: user.id);
        final threads = response['threads'] as List<dynamic>? ?? [];
        for (final t in threads) {
          final map = t as Map<String, dynamic>;
          if (map['requestId']?.toString() == widget.requestId) {
            threadId = map['id']?.toString();
            SessionStore.activeThreadId = threadId;
            break;
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;

    if (threadId != null) {
      final clientName =
          '${client?['firstName'] ?? ''} ${client?['lastName'] ?? ''}'.trim();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            threadId: threadId!,
            title: clientName.isEmpty ? 'Cliente' : clientName,
            avatarUrl: client?['profilePhotoUrl'] as String?,
          ),
        ),
      );
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const MessagesScreen()));
    }
  }

  Future<void> _cancelJob() async {
    final user = SessionStore.currentUser;
    if (user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.colorBackgroundAccent,
        title: const Text('Cancelar trabajo'),
        content: const Text(
          '¿Estás seguro de que deseas cancelar este trabajo?',
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
      await MobileBackendService.cancelJob(
        requestId: widget.requestId,
        userId: user.id,
      );
      if (!mounted) return;
      SessionStore.activeRequestId = null;
      SessionStore.activeThreadId = null;
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
    final client = _tracking?['client'] as Map<String, dynamic>?;
    final workerArrived = _tracking?['workerArrived'] as bool? ?? false;
    final clientConfirmed =
        _tracking?['clientConfirmedArrival'] as bool? ?? false;
    final etaMinutes = _tracking?['etaMinutes'];
    final distanceKm = _tracking?['distanceKm'];
    final address = _tracking?['address']?.toString() ?? '';
    final title = _tracking?['title']?.toString() ?? 'Trabajo en curso';
    final amount = _tracking?['agreedAmount'];

    final workerLat = (_tracking?['worker']?['latitude'] as num?)?.toDouble();
    final workerLng = (_tracking?['worker']?['longitude'] as num?)?.toDouble();
    // Prioridad: GPS del dispositivo → ubicación guardada en DB → fallback
    final mapCenter =
        _deviceLocation ??
        (workerLat != null && workerLng != null
            ? LatLng(workerLat, workerLng)
            : const LatLng(-16.5002, -68.1342));

    return Scaffold(
      backgroundColor: AppTheme.colorBackground,
      body: Stack(
        children: [
          // ── MAPA ──────────────────────────────────────────────────────
          Positioned.fill(
            bottom: 300,
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
                      initialZoom: 15,
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
                      MarkerLayer(
                        markers: [
                          // Punto azul = ubicación actual del dispositivo
                          Marker(
                            point: mapCenter,
                            width: 52,
                            height: 52,
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
                                    blurRadius: 14,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.navigation,
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
                                          : 'LLEGASTE'
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
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppTheme.colorSurfaceSoft,
                              backgroundImage:
                                  client?['profilePhotoUrl'] != null
                                  ? NetworkImage(
                                      client!['profilePhotoUrl'] as String,
                                    )
                                  : null,
                              child: client?['profilePhotoUrl'] == null
                                  ? Text(
                                      (client?['firstName'] ?? 'C')
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
                                    '${client?['firstName'] ?? ''} ${client?['lastName'] ?? ''}'
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
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: ChambaPrimaryButton(
                                label: clientConfirmed
                                    ? 'TRABAJO TERMINADO'
                                    : workerArrived
                                    ? 'Esperando cliente...'
                                    : 'LLEGUÉ AL SITIO',
                                icon: clientConfirmed
                                    ? Icons.check_circle
                                    : workerArrived
                                    ? Icons.hourglass_top
                                    : Icons.location_on,
                                isYellow: clientConfirmed,
                                onPressed: workerArrived && !clientConfirmed
                                    ? null
                                    : clientConfirmed
                                    ? _completeJob
                                    : _markArrived,
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Chat directo con el cliente + badge de no leídos
                            ValueListenableBuilder<int>(
                              valueListenable: UnreadMessagesNotifier.instance,
                              builder: (context, unread, _) {
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _ActionIconButton(
                                      icon: Icons.chat_bubble_outline,
                                      color: AppTheme.colorPrimary,
                                      onTap: () {
                                        UnreadMessagesNotifier.instance.reset();
                                        _openChat();
                                      },
                                    ),
                                    if (unread > 0)
                                      Positioned(
                                        top: -4,
                                        right: -4,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          constraints: const BoxConstraints(
                                            minWidth: 18,
                                            minHeight: 18,
                                          ),
                                          decoration: const BoxDecoration(
                                            color: AppTheme.colorError,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            unread > 99 ? '99+' : '$unread',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
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
