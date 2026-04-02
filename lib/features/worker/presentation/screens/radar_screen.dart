import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  final MapController _mapController = MapController();
  bool available = true;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _summary;
  LatLng? _workerLocation;
  double _workRadiusKm = 5;
  double _zoom = 13;

  @override
  void initState() {
    super.initState();
    _load();
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

    try {
      final deviceLocation = await _syncDeviceLocation(user.id);
      final response = await MobileBackendService.workerRadar(
        workerUserId: user.id,
      );
      final summary = response['summary'] as Map<String, dynamic>?;
      final location = response['location'] as Map<String, dynamic>?;
      final latitude = (location?['latitude'] as num?)?.toDouble();
      final longitude = (location?['longitude'] as num?)?.toDouble();

      setState(() {
        available = response['available'] as bool? ?? true;
        _summary = summary;
        _workRadiusKm = (location?['workRadiusKm'] as num?)?.toDouble() ?? 5;
        _workerLocation =
            deviceLocation ??
            (latitude != null && longitude != null
                ? LatLng(latitude, longitude)
                : const LatLng(-16.5002, -68.1342));
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _setAvailability(bool nextValue) async {
    final user = SessionStore.currentUser;
    if (user == null) {
      return;
    }

    setState(() => available = nextValue);

    try {
      await MobileBackendService.setAvailability(
        workerUserId: user.id,
        available: nextValue,
      );
      await _load();
    } catch (_) {
      setState(() => available = !nextValue);
    }
  }

  Future<LatLng?> _resolveCurrentLocation() async {
    try {
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
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

    try {
      await MobileBackendService.updateWorkerLocation(
        workerUserId: workerUserId,
        latitude: current.latitude,
        longitude: current.longitude,
      );
      return current;
    } catch (_) {
      return null;
    }
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
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Text(
                    'Radar de Trabajo',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                ],
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
                      value: '${_summary?['jobsToday'] ?? 0}',
                      subtitle: 'aceptados hoy',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.paid,
                      title: 'GANANCIAS',
                      value: 'Bs ${_summary?['earningsToday'] ?? 0}',
                      subtitle: '${_summary?['nearbyRequests'] ?? 0} cercanas',
                    ),
                  ),
                ],
              ),
            ],
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
            color: highlighted
                ? AppTheme.colorTextOnPurple
                : AppTheme.colorText,
          ),
        ),
      ),
    );
  }
}
