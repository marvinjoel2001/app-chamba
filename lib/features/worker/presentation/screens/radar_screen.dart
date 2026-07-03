import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/services/worker_background_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../domain/entities/worker_radar_summary.dart';
import '../../domain/usecases/worker_usecases.dart';
import '../state/worker_dependencies.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({
    this.getWorkerRadarUseCase,
    this.setWorkerAvailabilityUseCase,
    this.updateWorkerLocationUseCase,
    super.key,
  });

  final GetWorkerRadarUseCase? getWorkerRadarUseCase;
  final SetWorkerAvailabilityUseCase? setWorkerAvailabilityUseCase;
  final UpdateWorkerLocationUseCase? updateWorkerLocationUseCase;

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  GetWorkerRadarUseCase get _getWorkerRadarUseCase =>
      widget.getWorkerRadarUseCase ?? WorkerDependencies.getWorkerRadar;
  SetWorkerAvailabilityUseCase get _setWorkerAvailabilityUseCase =>
      widget.setWorkerAvailabilityUseCase ??
      WorkerDependencies.setWorkerAvailability;
  UpdateWorkerLocationUseCase get _updateWorkerLocationUseCase =>
      widget.updateWorkerLocationUseCase ??
      WorkerDependencies.updateWorkerLocation;

  final MapController _mapController = MapController();
  bool available = true;
  bool _loading = true;
  bool _isOffline = false;
  bool _shouldRedirectToLogin = false;
  String? _error;
  WorkerRadarSummary? _summary;
  LatLng? _workerLocation;
  double _workRadiusKm = 5;
  double _zoom = 13;
  StreamSubscription<Position>? _locationStreamSubscription;

  @override
  void initState() {
    super.initState();
    _load().then((_) => _startLocationStream());
  }

  @override
  void dispose() {
    _locationStreamSubscription?.cancel();
    super.dispose();
  }

  void _startLocationStream() async {
    final user = SessionStore.currentUser;
    if (user == null) return;

    // Check if location service is enabled first
    final isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      return;
    }

    // Check permissions first
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      try {
        permission = await Geolocator.requestPermission();
      } catch (_) {
        return;
      }
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    // Cancel any existing subscription
    await _locationStreamSubscription?.cancel();

    // Start listening to position stream
    _locationStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      if (!mounted) return;

      final newLocation = LatLng(position.latitude, position.longitude);
      setState(() => _workerLocation = newLocation);

      // Update server with new location
      _updateWorkerLocationUseCase(
        workerUserId: user.id,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    });
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

    setState(() {
      _loading = true;
      _error = null;
    });

    final deviceLocation = await _syncDeviceLocation(user.id);
    final result = await _getWorkerRadarUseCase(workerUserId: user.id);
    result.fold(
      onSuccess: (summary) {
        if (!mounted) {
          return;
        }
        setState(() {
          available = summary.available;
          _summary = summary;
          _workRadiusKm = summary.workRadiusKm;
          _workerLocation = deviceLocation ??
              (summary.latitude != null && summary.longitude != null
                  ? LatLng(summary.latitude!, summary.longitude!)
                  : const LatLng(-16.5002, -68.1342));
          _isOffline = false;
          _shouldRedirectToLogin = false;
          _loading = false;
        });
      },
      onFailure: (failure) {
        if (!mounted) {
          return;
        }
        setState(() {
          _error = failure.message;
          _isOffline = failure is NetworkFailure;
          _shouldRedirectToLogin = failure is UnauthorizedFailure;
          _loading = false;
        });
      },
    );
  }

  Future<void> _setAvailability(bool nextValue) async {
    final user = SessionStore.currentUser;
    if (user == null) {
      return;
    }

    setState(() => available = nextValue);

    final result = await _setWorkerAvailabilityUseCase(
      workerUserId: user.id,
      available: nextValue,
    );
    result.fold(
      onSuccess: (data) async {
        if (!mounted) {
          return;
        }
        setState(() => available = data.available);
        await WorkerBackgroundService.setEnabled(data.available);
        await _load();
      },
      onFailure: (_) {
        if (!mounted) {
          return;
        }
        setState(() => available = !nextValue);
      },
    );
  }

  Future<LatLng?> _resolveCurrentLocation() async {
    try {
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        try {
          permission = await Geolocator.requestPermission();
        } catch (_) {
          return null;
        }
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<LatLng?> _syncDeviceLocation(String workerUserId) async {
    final current = await _resolveCurrentLocation();
    if (current == null) {
      return null;
    }

    final result = await _updateWorkerLocationUseCase(
      workerUserId: workerUserId,
      latitude: current.latitude,
      longitude: current.longitude,
    );
    return result.fold(onSuccess: (_) => current, onFailure: (_) => null);
  }

  Future<void> _updateLocationFromDevice() async {
    final user = SessionStore.currentUser;
    if (user == null) {
      return;
    }

    final current = await _syncDeviceLocation(user.id);
    if (current == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo obtener la ubicación actual del teléfono'),
        ),
      );
      return;
    }

    _mapController.move(current, _zoom);
    try {
      setState(() => _workerLocation = current);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación actual sincronizada')),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  void _zoomIn() {
    _zoom += 0.8;
    _mapController.move(_mapController.camera.center, _zoom);
    setState(() {});
  }

  void _zoomOut() {
    _zoom = (_zoom - 0.8).clamp(3, 19);
    _mapController.move(_mapController.camera.center, _zoom);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mapCenter = _workerLocation ?? const LatLng(-16.5002, -68.1342);

    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Text(
                    'Radar de Trabajo',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                ],
              ),
              if (_isOffline)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Sin conexión. Mostrando último estado disponible.',
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_shouldRedirectToLogin)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Tu sesión expiró. Inicia sesión nuevamente.',
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              const SizedBox(height: 10),
              GlassCard(
                borderRadius: 36,
                child: Row(
                  children: [
                    Expanded(
                      child: ChambaChip(
                        label: 'DISPONIBLE',
                        selected: available,
                        onTap: () => _setAvailability(true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChambaChip(
                        label: 'NO DISPONIBLE',
                        selected: !available,
                        onTap: () => _setAvailability(false),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 6,
                    backgroundColor: available
                        ? AppTheme.colorHighlight
                        : AppTheme.colorMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    available
                        ? 'Estas activo, recibiendo solicitudes'
                        : 'Estas pausado temporalmente',
                    style: const TextStyle(color: AppTheme.colorMuted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: SizedBox(
                  height: 360,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AppConfig.mapboxAccessToken.trim().isEmpty
                              ? Container(
                                  color: AppTheme.colorSurfaceSoft,
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'Configura MAPBOX_ACCESS_TOKEN',
                                  ),
                                )
                              : FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: mapCenter,
                                    initialZoom: _zoom,
                                    onPositionChanged: (position, hasGesture) {
                                      _zoom = position.zoom;
                                    },
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
                                      userAgentPackageName:
                                          'com.example.mobile',
                                      additionalOptions: {
                                        'accessToken':
                                            AppConfig.mapboxAccessToken,
                                      },
                                    ),
                                    CircleLayer(
                                      circles: [
                                        CircleMarker(
                                          point: mapCenter,
                                          radius: _workRadiusKm * 1000,
                                          useRadiusInMeter: true,
                                          color: AppTheme.colorPrimary
                                              .withValues(alpha: 0.10),
                                          borderColor: AppTheme.colorPrimary
                                              .withValues(alpha: 0.45),
                                          borderStrokeWidth: 2,
                                        ),
                                      ],
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: mapCenter,
                                          width: 56,
                                          height: 56,
                                          child: CircleAvatar(
                                            radius: 26,
                                            backgroundColor:
                                                AppTheme.colorPrimary,
                                            child: const Icon(
                                              Icons.location_pin,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                        ),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Column(
                            children: [
                              _MapControl(icon: Icons.add, onTap: _zoomIn),
                              const SizedBox(height: 10),
                              _MapControl(icon: Icons.remove, onTap: _zoomOut),
                              const SizedBox(height: 10),
                              _MapControl(
                                icon: Icons.my_location,
                                highlighted: true,
                                onTap: _updateLocationFromDevice,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Resumen de Hoy',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.work,
                      title: 'TRABAJOS',
                      value: '${_summary?.jobsToday ?? 0}',
                      subtitle: 'aceptados hoy',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.paid,
                      title: 'GANANCIAS',
                      value: 'Bs ${_summary?.earningsToday ?? 0}',
                      subtitle: '${_summary?.nearbyRequests ?? 0} cercanas',
                    ),
                  ),
                ],
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.colorHighlight),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: AppTheme.colorMuted)),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppTheme.colorSuccess)),
        ],
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({
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
      color: highlighted ? AppTheme.colorPrimary : AppTheme.colorSurfaceSoft,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icon,
            color:
                highlighted ? AppTheme.colorTextOnPurple : AppTheme.colorText,
          ),
        ),
      ),
    );
  }
}
