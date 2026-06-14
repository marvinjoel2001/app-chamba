import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

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
import '../state/request_dependencies.dart';
import '../../../../core/services/mobile_backend_service.dart';

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

  List<LatLng> _routePoints = [];
  LatLng? _lastRouteFetchPos;

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
          perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final loc = LatLng(pos.latitude, pos.longitude);

      if (mounted) {
        setState(() => _deviceLocation = loc);
        // Mover el mapa a la nueva posición del worker
        try {
          _mapController.move(loc, _mapController.camera.zoom);
        } catch (_) {}
      }

      // Sincronizar con el backend
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
      // El aviso visual lo muestra IncomingRequestScreen (siempre montada en
      // el shell del worker); aquí solo volvemos al inicio para no duplicar.
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
      final res =
          (await RequestDependencies.getTracking(requestId: widget.requestId))
              .fold(
                onSuccess: (value) => value,
                onFailure: (failure) => throw Exception(failure.message),
              )
              .payload;
      if (mounted) {
        setState(() {
          _tracking = res;
          _loading = false;
        });
        
        final workerLat = (_tracking?['worker']?['latitude'] as num?)?.toDouble();
        final workerLng = (_tracking?['worker']?['longitude'] as num?)?.toDouble();
        final destLat = (_tracking?['destination']?['latitude'] as num?)?.toDouble();
        final destLng = (_tracking?['destination']?['longitude'] as num?)?.toDouble();

        final workerPos = _deviceLocation ?? (workerLat != null && workerLng != null ? LatLng(workerLat, workerLng) : null);
        if (workerPos != null && destLat != null && destLng != null) {
          final destPos = LatLng(destLat, destLng);
          if (_lastRouteFetchPos == null ||
              (workerPos.latitude - _lastRouteFetchPos!.latitude).abs() > 0.0005 ||
              (workerPos.longitude - _lastRouteFetchPos!.longitude).abs() > 0.0005) {
            _lastRouteFetchPos = workerPos;
            _fetchRoute(workerPos, destPos);
          }
        }
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

  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    final token = AppConfig.mapboxAccessToken.trim();
    if (token.isEmpty) return;
    try {
      final url = Uri.parse(
          'https://api.mapbox.com/directions/v5/mapbox/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&access_token=$token');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final coords = data['routes'][0]['geometry']['coordinates'] as List;
          final points = coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
          if (mounted) {
            setState(() {
              _routePoints = points;
            });
          }
        }
      }
    } catch (_) {}
  }

  /// Calcula la distancia en metros entre dos coordenadas usando la fórmula de Haversine
  double _calculateDistanceInMeters(LatLng pos1, LatLng pos2) {
    const earthRadius = 6371000.0; // Radio de la Tierra en metros
    final lat1Rad = pos1.latitude * pi / 180;
    final lat2Rad = pos2.latitude * pi / 180;
    final deltaLat = (pos2.latitude - pos1.latitude) * pi / 180;
    final deltaLng = (pos2.longitude - pos1.longitude) * pi / 180;

    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLng / 2) * sin(deltaLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Verifica si el worker está dentro del radio permitido (100m) para marcar llegada
  bool get _isWithinArrivalZone {
    final destLat =
        (_tracking?['destination']?['latitude'] as num?)?.toDouble();
    final destLng =
        (_tracking?['destination']?['longitude'] as num?)?.toDouble();

    if (destLat == null || destLng == null || _deviceLocation == null) {
      return false;
    }

    final destination = LatLng(destLat, destLng);
    final distance = _calculateDistanceInMeters(_deviceLocation!, destination);

    return distance <= 100; // 100 metros de tolerancia
  }

  /// Obtiene la distancia actual al destino en metros
  double? get _distanceToDestinationInMeters {
    final destLat =
        (_tracking?['destination']?['latitude'] as num?)?.toDouble();
    final destLng =
        (_tracking?['destination']?['longitude'] as num?)?.toDouble();

    if (destLat == null || destLng == null || _deviceLocation == null) {
      return null;
    }

    final destination = LatLng(destLat, destLng);
    return _calculateDistanceInMeters(_deviceLocation!, destination);
  }

  Future<void> _markArrived() async {
    final user = SessionStore.currentUser;
    if (user == null) return;

    // Validación de geofencing: debe estar a menos de 100m del destino
    if (!_isWithinArrivalZone) {
      final distance = _distanceToDestinationInMeters;
      final distanceText = distance != null
          ? '${(distance / 1000).toStringAsFixed(1)} km'
          : 'desconocida';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Debes estar a menos de 100m del destino para marcar llegada. Distancia actual: $distanceText',
          ),
          backgroundColor: AppTheme.colorError,
        ),
      );
      return;
    }

    try {
      (await RequestDependencies.workerMarkArrived(
        requestId: widget.requestId,
        workerUserId: user.id,
      ))
          .fold(
        onSuccess: (value) => value,
        onFailure: (failure) => throw Exception(failure.message),
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
      (await RequestDependencies.completeJob(
        requestId: widget.requestId,
        workerUserId: user.id,
      ))
          .fold(
        onSuccess: (value) => value,
        onFailure: (failure) => throw Exception(failure.message),
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
        final response =
            (await RequestDependencies.getMessages(userId: user.id))
                .fold(
                  onSuccess: (value) => value,
                  onFailure: (failure) => throw Exception(failure.message),
                )
                .payload;
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
            counterpartName: clientName.isEmpty ? 'Cliente' : clientName,
            counterpartAvatarUrl: client?['profilePhotoUrl'] as String?,
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
      (await RequestDependencies.cancelJob(
        requestId: widget.requestId,
        userId: user.id,
      ))
          .fold(
        onSuccess: (value) => value,
        onFailure: (failure) => throw Exception(failure.message),
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

  Future<void> _showReportDialog() async {
    final reasonCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool submitting = false;

    final isWorker = SessionStore.currentUser?.type == 'worker';
    final targetUser = isWorker ? _tracking?['client']?['id'] : _tracking?['worker']?['id'];
    if (targetUser == null) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: AppTheme.colorBackgroundAccent,
          title: const Text('Reportar Problema', style: TextStyle(color: AppTheme.colorError)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Razón (ej. Fraude, Inseguridad)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descripción detallada'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.colorMuted)),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (reasonCtrl.text.trim().isEmpty) return;
                      setStateDialog(() => submitting = true);
                      try {
                        await MobileBackendService.instance.createDispute(
                          requestId: widget.requestId,
                          reportedBy: SessionStore.currentUser!.id,
                          reportedUser: targetUser,
                          reason: reasonCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                        );
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reporte enviado con éxito.'), backgroundColor: AppTheme.colorSuccess),
                        );
                      } catch (e) {
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppTheme.colorError),
                        );
                        setStateDialog(() => submitting = false);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.colorError),
              child: submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enviar Reporte', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
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
    final priceType = _tracking?['priceType']?.toString();
    final workElapsedSeconds =
        (_tracking?['workElapsedSeconds'] as num?)?.toInt();

    final workerLat = (_tracking?['worker']?['latitude'] as num?)?.toDouble();
    final workerLng = (_tracking?['worker']?['longitude'] as num?)?.toDouble();
    final destLat =
        (_tracking?['destination']?['latitude'] as num?)?.toDouble();
    final destLng =
        (_tracking?['destination']?['longitude'] as num?)?.toDouble();

    // Worker: GPS del dispositivo → DB → fallback
    final workerPos = _deviceLocation ??
        (workerLat != null && workerLng != null
            ? LatLng(workerLat, workerLng)
            : const LatLng(-16.5002, -68.1342));

    // Destino (ubicación del trabajo)
    final destPos =
        destLat != null && destLng != null ? LatLng(destLat, destLng) : null;

    // Centro del mapa: punto medio entre worker y destino, o solo worker
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
                      // Línea de ruta entre worker y destino
                      if (_routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              color: AppTheme.colorPrimary.withValues(
                                alpha: 0.8,
                              ),
                              strokeWidth: 4,
                            ),
                          ],
                        )
                      else if (destPos != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [workerPos, destPos],
                              color: AppTheme.colorPrimary.withValues(
                                alpha: 0.8,
                              ),
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          // Marcador del worker (punto azul con navegación)
                          Marker(
                            point: workerPos,
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
                          // Marcador del destino (pin morado)
                          if (destPos != null)
                            Marker(
                              point: destPos,
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
                                  Icons.location_on,
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
                  icon: Icons.my_location,
                  highlighted: true,
                  onTap: () {
                    final center = _deviceLocation ?? mapCenter;
                    _mapController.move(center, 15);
                  },
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
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: AppTheme.colorMuted
                                      .withValues(alpha: 0.3),
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
                                  backgroundImage: client?['profilePhotoUrl'] !=
                                          null
                                      ? NetworkImage(
                                          client!['profilePhotoUrl'] as String,
                                        )
                                      : null,
                                  child: client?['profilePhotoUrl'] == null
                                      ? Text(
                                          chambaInitial(client?['firstName'],
                                              fallback: 'C'),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            : !_isWithinArrivalZone
                                                ? 'Acércate al destino'
                                                : 'LLEGUÉ AL SITIO',
                                    icon: clientConfirmed
                                        ? Icons.check_circle
                                        : workerArrived
                                            ? Icons.hourglass_top
                                            : !_isWithinArrivalZone
                                                ? Icons.location_disabled
                                                : Icons.location_on,
                                    isYellow: clientConfirmed,
                                    onPressed: workerArrived && !clientConfirmed
                                        ? null
                                        : clientConfirmed
                                            ? _completeJob
                                            : !_isWithinArrivalZone
                                                ? null // Deshabilitado fuera de zona
                                                : _markArrived,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Chat directo con el cliente + badge de no leídos
                                ValueListenableBuilder<int>(
                                  valueListenable:
                                      UnreadMessagesNotifier.instance,
                                  builder: (context, unread, _) {
                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        _ActionIconButton(
                                          icon: Icons.chat_bubble_outline,
                                          color: AppTheme.colorPrimary,
                                          onTap: () {
                                            UnreadMessagesNotifier.instance
                                                .reset();
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: _cancelJob,
                                  child: const Text(
                                    'Cancelar trabajo',
                                    style: TextStyle(color: AppTheme.colorError),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                TextButton(
                                  onPressed: _showReportDialog,
                                  child: const Text(
                                    'Reportar Problema',
                                    style: TextStyle(color: AppTheme.colorError, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
