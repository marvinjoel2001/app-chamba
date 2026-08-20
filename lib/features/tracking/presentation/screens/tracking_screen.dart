import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/navigation/app_flows.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/services/sound_effect_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../messages/presentation/state/messages_dependencies.dart';
import '../../../messages/presentation/screens/chat_screen.dart';
import '../../../messages/presentation/screens/messages_screen.dart';
import '../../../shell/presentation/screens/main_shell_screen.dart';
import '../state/tracking_dependencies.dart';
import '../../../support/presentation/screens/support_screen.dart';

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

  Timer? _workLiveTimer;
  int _workElapsedSeconds = 0;
  bool _isWorkPaused = false;

  List<LatLng> _routePoints = [];
  LatLng? _lastRouteFetchPos;
  int _unreadMessages = 0;

  @override
  void initState() {
    super.initState();
    _realtime.on('job.worker_arrived', _onWorkerArrived);
    _realtime.on('job.completed', _onJobCompleted);
    _realtime.on('job.cancelled', _onJobCancelled);
    _realtime.on('message.new', _onChatMessage);
    _realtime.on('worker.location.updated', _onWorkerLocation);
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
    _load();
  }

  /// Posición del worker en vivo (el worker la emite cada ~5 s). Solo mueve
  /// el marcador: nunca toca la cámara, así el zoom/encuadre del usuario
  /// se respeta siempre.
  void _onWorkerLocation(dynamic data) {
    final msg =
        data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final trackedWorkerId = _tracking?['worker']?['id']?.toString();
    if (trackedWorkerId == null ||
        msg['workerId']?.toString() != trackedWorkerId) {
      return;
    }
    final lat = (msg['latitude'] as num?)?.toDouble();
    final lng = (msg['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null || !mounted) return;
    setState(() {
      final worker = _tracking?['worker'];
      if (worker is Map) {
        worker['latitude'] = lat;
        worker['longitude'] = lng;
      }
    });
  }

  void _onChatMessage(dynamic data) {
    // El payload del socket puede llegar como Map<dynamic, dynamic>;
    // un cast directo a Map<String, dynamic> lanza TypeError.
    final msg = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

    // El backend emite 'message.new' con la forma
    // { threadId, requestId, message: { id, senderUserId, content, createdAt } }.
    // Antes se leía msg['senderId'], que no existe en ese payload: el contador
    // habría subido incluso con los mensajes propios.
    final requestId = msg['requestId']?.toString();
    if (requestId != null && requestId != SessionStore.activeRequestId) {
      // Mensaje de otra conversación: no afecta el contador de esta pantalla.
      return;
    }

    final message = msg['message'];
    final senderId = message is Map ? message['senderUserId']?.toString() : null;
    if (senderId != SessionStore.currentUser?.id) {
      if (mounted) setState(() => _unreadMessages++);
    }
  }

  @override
  void dispose() {
    _realtime.off('job.worker_arrived', _onWorkerArrived);
    _realtime.off('job.completed', _onJobCompleted);
    _realtime.off('job.cancelled', _onJobCancelled);
    _realtime.off('message.new', _onChatMessage);
    _realtime.off('worker.location.updated', _onWorkerLocation);
    _pollTimer?.cancel();
    _workLiveTimer?.cancel();
    super.dispose();
  }

  void _startWorkTimer() {
    _workLiveTimer?.cancel();
    _workLiveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isWorkPaused && mounted) {
        setState(() => _workElapsedSeconds++);
      }
    });
  }

  void _toggleWorkPause() {
    if (_isWorkPaused) {
      SoundEffectService.playTimerStartSound();
    } else {
      SoundEffectService.playTimerStopSound();
    }
    setState(() => _isWorkPaused = !_isWorkPaused);
  }

  void _onWorkerArrived(dynamic _) {
    _load();
    SoundEffectService.playRadarAlert();
    HapticFeedback.heavyImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 ¡El trabajador ha llegado! Confirma su llegada.'),
          backgroundColor: AppTheme.colorSuccess,
        ),
      );
    }
  }

  void _onJobCompleted(dynamic _) {
    _workLiveTimer?.cancel();
    SoundEffectService.playCashSound();
    AppFlows.goToRating();
  }

  void _onJobCancelled(dynamic _) {
    _workLiveTimer?.cancel();
    AppFlows.goHomeAfterCancellation();
  }

  Future<void> _ensureActiveThread() async {
    final user = SessionStore.currentUser;
    final requestId = SessionStore.activeRequestId;
    final workerId = _tracking?['worker']?['id']?.toString();
    if (user == null || requestId == null || workerId == null) return;

    final result = await MessagesDependencies.getActiveThreads(userId: user.id);
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
      final response =
          (await TrackingDependencies.getTracking(requestId: requestId))
              .fold(
                onSuccess: (value) => value,
                onFailure: (failure) => throw Exception(failure.message),
              )
              .payload;
      _tracking = response;
      if (SessionStore.activeThreadId == null) {
        await _ensureActiveThread();
      }

      final workerLat = (_tracking?['worker']?['latitude'] as num?)?.toDouble();
      final workerLng = (_tracking?['worker']?['longitude'] as num?)?.toDouble();
      final destLat = (_tracking?['destination']?['latitude'] as num?)?.toDouble();
      final destLng = (_tracking?['destination']?['longitude'] as num?)?.toDouble();

      if (workerLat != null && workerLng != null && destLat != null && destLng != null) {
        final workerPos = LatLng(workerLat, workerLng);
        final destPos = LatLng(destLat, destLng);
        if (_lastRouteFetchPos == null ||
            (workerPos.latitude - _lastRouteFetchPos!.latitude).abs() > 0.0005 ||
            (workerPos.longitude - _lastRouteFetchPos!.longitude).abs() > 0.0005) {
          _lastRouteFetchPos = workerPos;
          _fetchRoute(workerPos, destPos);
        }
      }

      final clientConfirmed =
          _tracking?['clientConfirmedArrival'] as bool? ?? false;
      if (clientConfirmed && _workLiveTimer == null) {
        _startWorkTimer();
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

  Future<void> _confirmArrival() async {
    final user = SessionStore.currentUser;
    final requestId = SessionStore.activeRequestId;
    if (user == null || requestId == null) return;

    setState(() => _confirmingArrival = true);
    try {
      (await TrackingDependencies.clientConfirmArrival(
        requestId: requestId,
        clientUserId: user.id,
      ))
          .fold(
        onSuccess: (value) => value,
        onFailure: (failure) => throw Exception(failure.message),
      );
      SoundEffectService.playTimerStartSound();
      _startWorkTimer();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Llegada confirmada. El cronómetro ha iniciado.'),
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
      (await TrackingDependencies.cancelJob(
        requestId: requestId,
        userId: user.id,
      ))
          .fold(
        onSuccess: (value) => value,
        onFailure: (failure) => throw Exception(failure.message),
      );
      if (!mounted) return;
      // Limpiar sesión del cliente
      SessionStore.activeRequestId = null;
      SessionStore.activeThreadId = null;
      // Volver al inicio usando AppFlows para evitar doble pop (y pantalla negra) al recibir el socket
      AppFlows.goHomeAfterCancellation(message: 'Trabajo cancelado exitosamente');
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

    // Desglose de la modalidad bajo el monto: el total siempre manda y el
    // detalle (horas/días × tarifa) evita dudas sobre qué se está pagando.
    final modality = _tracking?['modality']?.toString() ?? 'fixed';
    final estimatedHours =
        (_tracking?['estimatedHours'] as num?)?.toDouble() ?? 0;
    final days = (_tracking?['days'] as num?)?.toDouble() ?? 0;
    final totalAmount = (amount as num?)?.toDouble();
    String? modalityLabel;
    if (totalAmount != null) {
      String rateOf(double units) {
        final rate = totalAmount / units;
        return rate % 1 == 0
            ? rate.toStringAsFixed(0)
            : rate.toStringAsFixed(2);
      }

      if (modality == 'hourly' && estimatedHours > 0) {
        modalityLabel =
            'Por hora · ${estimatedHours.toStringAsFixed(0)}h × Bs ${rateOf(estimatedHours)}';
      } else if (modality == 'daily' && days > 0) {
        modalityLabel =
            'Por día · ${days.toStringAsFixed(0)} días × Bs ${rateOf(days)}';
      } else {
        modalityLabel = 'Precio fijo';
      }
    }

    final workerLat = (worker?['latitude'] as num?)?.toDouble();
    final workerLng = (worker?['longitude'] as num?)?.toDouble();
    final destLat =
        (_tracking?['destination']?['latitude'] as num?)?.toDouble();
    final destLng =
        (_tracking?['destination']?['longitude'] as num?)?.toDouble();

    // Posición del worker (se actualiza con el polling)
    final workerPos = workerLat != null && workerLng != null
        ? LatLng(workerLat, workerLng)
        : const LatLng(-16.5002, -68.1342);

    // Destino (ubicación del trabajo = donde está el cliente)
    final destPos =
        destLat != null && destLng != null ? LatLng(destLat, destLng) : null;

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
          // Ocupa toda la pantalla; el bottom sheet arrastrable lo cubre
          // parcialmente según cuánto lo suba el usuario.
          Positioned.fill(
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
                      if (_routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              color: AppTheme.colorSuccess.withValues(
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

          // ── BOTTOM SHEET ARRASTRABLE ──────────────────────────────────
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.18,
            maxChildSize: 0.85,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0D1728),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
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
                                  color: AppTheme.colorMuted
                                      .withValues(alpha: 0.3),
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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      amount != null ? 'Bs $amount' : '',
                                      style: const TextStyle(
                                        color: AppTheme.colorText,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (modalityLabel != null)
                                      Text(
                                        modalityLabel,
                                        style: const TextStyle(
                                          color: AppTheme.colorMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
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
                                  backgroundImage: worker?['profilePhotoUrl'] !=
                                          null
                                      ? NetworkImage(
                                          worker!['profilePhotoUrl'] as String,
                                        )
                                      : null,
                                  child: worker?['profilePhotoUrl'] == null
                                      ? Text(
                                          chambaInitial(worker?['firstName'],
                                              fallback: 'W'),
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
                            
                            // Tarjeta de Seguimiento en Vivo por Modalidad (Cronómetro/Jornada)
                            _LiveModalityTrackingCard(
                              modality: modality,
                              elapsedSeconds: _workElapsedSeconds,
                              isPaused: _isWorkPaused,
                              onTogglePause: _toggleWorkPause,
                              totalAmount: totalAmount,
                              estimatedHours: estimatedHours,
                              days: days,
                              clientConfirmed: clientConfirmed,
                            ),

                            const SizedBox(height: 16),
                            // Botones
                            Row(
                              children: [
                                // Confirmar llegada: botón real solo cuando se
                                // puede tocar; mientras tanto, un indicador de
                                // estado (un botón deshabilitado parece roto).
                                Expanded(
                                  flex: 3,
                                  child: workerArrived && !clientConfirmed
                                      ? ChambaPrimaryButton(
                                          label: 'CONFIRMAR LLEGADA',
                                          icon: Icons.where_to_vote,
                                          isYellow: true,
                                          onPressed: _confirmingArrival
                                              ? null
                                              : _confirmArrival,
                                        )
                                      : _ArrivalStatusBanner(
                                          confirmed: clientConfirmed,
                                        ),
                                ),
                                const SizedBox(width: 10),
                                // Chat
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _ActionIconButton(
                                      icon: Icons.chat_bubble_outline,
                                      color: AppTheme.colorPrimary,
                                      onTap: () async {
                                        setState(() => _unreadMessages = 0);
                                        if (SessionStore.activeThreadId == null) {
                                          await _ensureActiveThread();
                                        }
                                        final threadId =
                                            SessionStore.activeThreadId;
                                        if (threadId == null) {
                                          if (!context.mounted) return;
                                          Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  const MessagesScreen(),
                                            ),
                                          );
                                          return;
                                        }
                                        if (!context.mounted) return;
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => ChatScreen(
                                              threadId: threadId,
                                              counterpartName:
                                                  '${worker?['firstName'] ?? ''} ${worker?['lastName'] ?? ''}'
                                                      .trim(),
                                              counterpartId:
                                                  worker?['id']?.toString(),
                                              counterpartAvatarUrl:
                                                  worker?['profilePhotoUrl']
                                                      as String?,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    if (_unreadMessages > 0)
                                      Positioned(
                                        top: -5,
                                        right: -5,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: AppTheme.colorError,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            _unreadMessages.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Ocultar botón cancelar si el worker ya llegó
                                if (!workerArrived)
                                  TextButton(
                                    onPressed: _cancelJob,
                                    child: const Text(
                                      'Cancelar trabajo',
                                      style:
                                          TextStyle(color: AppTheme.colorError),
                                    ),
                                  ),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => SupportScreen(
                                          requestId:
                                              SessionStore.activeRequestId,
                                          reportedUserId:
                                              worker?['id']?.toString(),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.flag_outlined,
                                      size: 16, color: AppTheme.colorMuted),
                                  label: const Text(
                                    'Reportar problema',
                                    style: TextStyle(
                                        color: AppTheme.colorMuted,
                                        fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado de la llegada del trabajador: "en camino" o "confirmada".
/// Informativo, no interactivo — por eso no es un botón.
class _ArrivalStatusBanner extends StatelessWidget {
  const _ArrivalStatusBanner({required this.confirmed});

  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    final color = confirmed ? AppTheme.colorSuccess : AppTheme.colorMuted;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: confirmed
            ? AppTheme.colorSuccessSoft
            : AppTheme.colorSurfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            confirmed ? Icons.check_circle : Icons.hourglass_top,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              confirmed
                  ? 'Llegada confirmada'
                  : 'El trabajador está en camino…',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
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

/// Tarjeta de seguimiento en vivo adaptada a la modalidad (Cronómetro / Jornadas / Fijo)
class _LiveModalityTrackingCard extends StatelessWidget {
  const _LiveModalityTrackingCard({
    required this.modality,
    required this.elapsedSeconds,
    required this.isPaused,
    required this.onTogglePause,
    required this.totalAmount,
    required this.estimatedHours,
    required this.days,
    required this.clientConfirmed,
  });

  final String modality;
  final int elapsedSeconds;
  final bool isPaused;
  final VoidCallback onTogglePause;
  final double? totalAmount;
  final double estimatedHours;
  final double days;
  final bool clientConfirmed;

  String _formatTimer(int totalSecs) {
    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;
    final s = totalSecs % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!clientConfirmed) {
      return const SizedBox.shrink();
    }

    if (modality == 'hourly') {
      final hourlyRate = estimatedHours > 0 && totalAmount != null ? totalAmount! / estimatedHours : 40.0;
      final currentCost = hourlyRate * (elapsedSeconds / 3600.0);
      final estimatedSecs = (estimatedHours * 3600).toInt();
      final progress = estimatedSecs > 0 ? (elapsedSeconds / estimatedSecs).clamp(0.0, 1.0) : 0.0;
      final isOvertime = estimatedSecs > 0 && elapsedSeconds > estimatedSecs;

      return Container(
        margin: const EdgeInsets.only(top: 16, bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141F32),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOvertime
                ? AppTheme.colorWarning.withValues(alpha: 0.5)
                : AppTheme.colorPrimary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isOvertime ? AppTheme.colorWarning : AppTheme.colorPrimary)
                  .withValues(alpha: 0.15),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.colorPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.timer,
                    color: AppTheme.colorPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CRONÓMETRO EN VIVO',
                        style: TextStyle(
                          color: AppTheme.colorPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        isPaused ? 'En pausa (descanso)' : 'Trabajando activamente',
                        style: TextStyle(
                          color: isPaused ? AppTheme.colorWarning : AppTheme.colorSuccess,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Botón Pausar / Reanudar
                InkWell(
                  onTap: onTogglePause,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPaused
                          ? AppTheme.colorSuccessSoft
                          : AppTheme.colorWarningSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPaused
                            ? AppTheme.colorSuccess.withValues(alpha: 0.4)
                            : AppTheme.colorWarning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPaused ? Icons.play_arrow : Icons.pause,
                          size: 16,
                          color: isPaused ? AppTheme.colorSuccess : AppTheme.colorWarning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPaused ? 'Reanudar' : 'Pausar',
                          style: TextStyle(
                            color: isPaused ? AppTheme.colorSuccess : AppTheme.colorWarning,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Contador grande
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TIEMPO TRANSCURRIDO',
                      style: TextStyle(
                        color: AppTheme.colorMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTimer(elapsedSeconds),
                      style: const TextStyle(
                        color: AppTheme.colorText,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'COSTO ACUMULADO',
                      style: TextStyle(
                        color: AppTheme.colorMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bs ${currentCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppTheme.colorSuccess,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Barra de progreso hacia horas estimadas
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOvertime ? AppTheme.colorWarning : AppTheme.colorPrimary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tarifa: Bs ${hourlyRate.toStringAsFixed(0)}/hr',
                  style: const TextStyle(color: AppTheme.colorMuted, fontSize: 10),
                ),
                Text(
                  estimatedHours > 0 ? 'Estimado: ${estimatedHours.toStringAsFixed(0)}h' : '',
                  style: TextStyle(
                    color: isOvertime ? AppTheme.colorWarning : AppTheme.colorMuted,
                    fontSize: 10,
                    fontWeight: isOvertime ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            if (isOvertime) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.colorWarningSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppTheme.colorWarning, size: 14),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Se superó el tiempo estimado. El costo se ajusta por minuto extra.',
                        style: TextStyle(color: AppTheme.colorWarning, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (modality == 'daily') {
      final daysCount = days > 0 ? days.toInt() : 1;
      final dailyRate = daysCount > 0 && totalAmount != null ? totalAmount! / daysCount : 150.0;

      return Container(
        margin: const EdgeInsets.only(top: 16, bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141F32),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.colorPrimary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.colorPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: AppTheme.colorPrimary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TRABAJO POR JORNADA DIARIA',
                        style: TextStyle(
                          color: AppTheme.colorPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'Jornada 1 de $daysCount en progreso',
                        style: const TextStyle(
                          color: AppTheme.colorText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.colorSuccessSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Bs ${dailyRate.toStringAsFixed(0)}/día',
                    style: const TextStyle(
                      color: AppTheme.colorSuccess,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Pasos de días
            Row(
              children: List.generate(daysCount, (index) {
                final isCurrent = index == 0;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index < daysCount - 1 ? 6 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppTheme.colorPrimary.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCurrent
                            ? AppTheme.colorPrimary
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          isCurrent ? Icons.play_circle_fill : Icons.schedule,
                          size: 16,
                          color: isCurrent ? AppTheme.colorPrimary : AppTheme.colorMuted,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Día ${index + 1}',
                          style: TextStyle(
                            color: isCurrent ? AppTheme.colorText : AppTheme.colorMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      );
    }

    // Modalidad Precio Fijo
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141F32),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.colorSuccess.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.colorSuccessSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.verified,
              color: AppTheme.colorSuccess,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PRECIO FIJO GARANTIZADO',
                  style: TextStyle(
                    color: AppTheme.colorSuccess,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'Monto final acordado: Bs ${(totalAmount ?? 0).toStringAsFixed(2)}',
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
      ),
    );
  }
}
