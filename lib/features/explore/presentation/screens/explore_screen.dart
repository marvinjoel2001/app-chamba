import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';
import '../../../request/presentation/screens/incoming_request_screen.dart';
import '../../../request/presentation/screens/request_form_screen.dart';
import '../../../request/presentation/screens/request_status_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({required this.role, super.key});

  final String role;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final MapController _mapController = MapController();
  bool _loading = true;
  String? _error;
  List<dynamic> _workers = const [];
  List<dynamic> _categories = const [];
  Map<String, dynamic>? _activeRequest;
  LatLng? _currentUserLocation;
  double _currentZoom = 13;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = SessionStore.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Sesion expirada. Inicia sesion de nuevo.';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final currentLocation = await _resolveCurrentLocation();
      final response = await MobileBackendService.explore(
        userId: user.id,
        latitude: currentLocation?.latitude,
        longitude: currentLocation?.longitude,
      );
      final activeRequest = response['activeRequest'];
      if (activeRequest is Map<String, dynamic>) {
        SessionStore.activeRequestId = activeRequest['id'] as String?;
      }

      setState(() {
        _currentUserLocation = currentLocation;
        _workers = (response['nearbyWorkers'] as List<dynamic>? ?? const []);
        _categories = (response['categories'] as List<dynamic>? ?? const []);
        _activeRequest = activeRequest is Map<String, dynamic>
            ? activeRequest
            : null;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
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

  LatLng get _mapCenter {
    if (_currentUserLocation != null) {
      return _currentUserLocation!;
    }

    if (_workers.isNotEmpty) {
      final first = _workers.first as Map<String, dynamic>;
      final lat = (first['latitude'] as num?)?.toDouble();
      final lng = (first['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }

    return const LatLng(-16.5002, -68.1342);
  }

  List<Marker> get _workerMarkers {
    return _workers.map((raw) {
      final worker = raw as Map<String, dynamic>;
      final lat = (worker['latitude'] as num?)?.toDouble() ?? -16.5002;
      final lng = (worker['longitude'] as num?)?.toDouble() ?? -68.1342;
      return Marker(
        point: LatLng(lat, lng),
        width: 54,
        height: 54,
        child: CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.colorPrimary.withValues(alpha: 0.82),
          child: const Icon(Icons.handyman, color: Colors.white, size: 22),
        ),
      );
    }).toList();
  }

  void _zoomIn() {
    _currentZoom += 0.8;
    _mapController.move(_mapController.camera.center, _currentZoom);
    setState(() {});
  }

  void _zoomOut() {
    _currentZoom = (_currentZoom - 0.8).clamp(3, 20);
    _mapController.move(_mapController.camera.center, _currentZoom);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionStore.currentUser;

    return Scaffold(
      body: Stack(
        children: [
          const ChambaBackground(showGrid: true, child: SizedBox.expand()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0x1A6B2BBE),
                        child: const Icon(Icons.work_history),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        user == null ? 'Chamba' : 'Hola, ${user.firstName}',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: user?.profilePhotoUrl == null
                            ? null
                            : NetworkImage(user!.profilePhotoUrl!),
                        child: user?.profilePhotoUrl == null
                            ? Text(
                                (user?.firstName ?? 'U')
                                    .substring(0, 1)
                                    .toUpperCase(),
                              )
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: AppConfig.mapboxAccessToken.trim().isEmpty
                          ? const ColoredBox(
                              color: Color(0x22000000),
                              child: Center(
                                child: Text(
                                  'Falta MAPBOX_ACCESS_TOKEN para mostrar el mapa',
                                ),
                              ),
                            )
                          : FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _mapCenter,
                                initialZoom: _currentZoom,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.all,
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
                                  userAgentPackageName: 'com.example.mobile',
                                  additionalOptions: {
                                    'accessToken': AppConfig.mapboxAccessToken,
                                  },
                                ),
                                MarkerLayer(
                                  markers: [
                                    ..._workerMarkers,
                                    if (_currentUserLocation != null)
                                      Marker(
                                        point: _currentUserLocation!,
                                        width: 60,
                                        height: 60,
                                        child: CircleAvatar(
                                          radius: 26,
                                          backgroundColor:
                                              AppTheme.colorPrimary,
                                          child: const Icon(
                                            Icons.my_location,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    Marker(
                                      point: _mapCenter,
                                      width: 60,
                                      height: 60,
                                      child: CircleAvatar(
                                        radius: 26,
                                        backgroundColor:
                                            AppTheme.colorHighlight,
                                        child: Icon(
                                          Icons.location_on,
                                          color: Colors.black.withValues(
                                            alpha: 0.75,
                                          ),
                                        ),
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
            ),
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Positioned(
              left: 20,
              right: 20,
              top: 110,
              child: GlassCard(
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            ),
          Positioned(
            right: 12,
            bottom: 300,
            child: Column(
              children: [
                _MapControl(icon: Icons.add, onTap: _zoomIn),
                const SizedBox(height: 12),
                _MapControl(icon: Icons.remove, onTap: _zoomOut),
                const SizedBox(height: 12),
                _MapControl(
                  icon: Icons.navigation,
                  highlighted: true,
                  onTap: () {
                    _mapController.move(_mapCenter, _currentZoom);
                    _load();
                  },
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GlassCard(
              borderRadius: 32,
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCFD6E8),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _activeRequest == null
                              ? 'Sin solicitudes activas'
                              : 'Solicitud activa: ${_activeRequest!['title']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.colorHighlight,
                        child: IconButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RequestFormScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (var i = 0; i < _categories.length; i++) ...[
                          ChambaChip(
                            label: _categories[i].toString(),
                            selected: i == 0,
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (_categories.isEmpty)
                          const ChambaChip(
                            label: 'Sin categorias',
                            selected: false,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChambaPrimaryButton(
                          label: widget.role == 'worker'
                              ? 'Ver solicitudes cercanas'
                              : 'Estado solicitud',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => widget.role == 'worker'
                                    ? const IncomingRequestScreen()
                                    : const RequestStatusScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Trabajadores cercanos: ${_workers.length}'),
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

class _MapControl extends StatelessWidget {
  const _MapControl({required this.icon, this.highlighted = false, this.onTap});

  final IconData icon;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 30,
      backgroundColor: AppTheme.colorSurfaceSoft,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          color: highlighted ? AppTheme.colorHighlight : AppTheme.colorText,
        ),
      ),
    );
  }
}
