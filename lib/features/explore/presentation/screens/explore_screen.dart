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

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({required this.role, super.key});

  final String role;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _promptController = TextEditingController();
  bool _loading = true;
  bool _analyzingPrompt = false;
  String? _error;
  String? _locationBlockMessage;
  bool _canOpenLocationSettings = false;
  List<dynamic> _workers = const [];
  List<dynamic> _categories = const [];
  Map<String, dynamic>? _activeRequest;
  LatLng? _currentUserLocation;
  double _currentZoom = 13;
  static const double _clientComposerBottomOffset = 0;
  static const double _workerPanelBottomOffset = 84;

  bool get _isClient => widget.role == 'client';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
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
      _locationBlockMessage = null;
      _canOpenLocationSettings = false;
    });

    try {
      final currentLocation = await _resolveCurrentLocationRequired();
      if (currentLocation == null) {
        setState(() {
          _workers = const [];
          _categories = const [];
          _activeRequest = null;
          _currentUserLocation = null;
          _loading = false;
        });
        return;
      }

      final response = await MobileBackendService.explore(
        userId: user.id,
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _mapController.move(currentLocation, _currentZoom);
      });
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<LatLng?> _resolveCurrentLocationRequired() async {
    try {
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isEnabled) {
        _locationBlockMessage =
            'Activa la ubicacion del telefono para buscar trabajadores cercanos.';
        _canOpenLocationSettings = true;
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationBlockMessage = permission == LocationPermission.deniedForever
            ? 'El permiso de ubicacion esta bloqueado. Debes habilitarlo en ajustes para continuar.'
            : 'Debes permitir la ubicacion para usar esta pantalla.';
        _canOpenLocationSettings =
            permission == LocationPermission.deniedForever;
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
      _locationBlockMessage =
          'No se pudo obtener tu ubicacion actual. Intenta nuevamente.';
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

  // ignore: unused_element
  String _normalizeSearchText(String value) {
    const replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'Á': 'a',
      'É': 'e',
      'Í': 'i',
      'Ó': 'o',
      'Ú': 'u',
      'ñ': 'n',
      'Ñ': 'n',
    };
    var normalized = value.toLowerCase();
    replacements.forEach((source, target) {
      normalized = normalized.replaceAll(source, target);
    });
    return normalized.replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ');
  }

  Future<void> _startRequestFlow() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Describe primero lo que estas buscando.'),
        ),
      );
      return;
    }

    setState(() {
      _analyzingPrompt = true;
    });

    try {
      final currentLocation =
          _currentUserLocation ?? await _resolveCurrentLocationRequired();
      if (currentLocation == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _analyzingPrompt = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _locationBlockMessage ??
                  'Necesitamos tu ubicacion para crear la solicitud.',
            ),
          ),
        );
        return;
      }

      final preview = await MobileBackendService.previewRequestCategories(
        description: prompt,
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RequestFormScreen(
            initialPrompt: prompt,
            initialTitle: preview['title']?.toString(),
            suggestedCategories:
                (preview['aiCategories'] as List<dynamic>? ?? const [])
                    .whereType<Map<String, dynamic>>()
                    .toList(),
            initialLatitude: currentLocation.latitude,
            initialLongitude: currentLocation.longitude,
          ),
        ),
      );

      if (!mounted) {
        return;
      }
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
    } finally {
      if (mounted) {
        setState(() {
          _analyzingPrompt = false;
        });
      }
    }
  }

  void _showHelpSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.colorBackgroundAlt,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Como pedir ayuda',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Escribe lo que necesitas con un ejemplo claro, por ejemplo: necesito que alguien me pinte la casa.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'La app analizara tu texto, sugerira categorias y luego te llevara al formulario para completar presupuesto y fotos.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationBlocked(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_off,
                size: 34,
                color: AppTheme.colorText,
              ),
              const SizedBox(height: 12),
              Text(
                _locationBlockMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              ChambaPrimaryButton(
                label: 'Permitir ubicacion',
                onPressed: _load,
              ),
              if (_canOpenLocationSettings) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: Geolocator.openAppSettings,
                  child: const Text('Abrir ajustes'),
                ),
                TextButton(
                  onPressed: Geolocator.openLocationSettings,
                  child: const Text('Activar servicios de ubicacion'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientComposer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GlassCard(
        borderRadius: 32,
        child: Column(
          children: [
            TextField(
              controller: _promptController,
              minLines: 4,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText:
                    'Aqui escriba lo que buscas. Ejemplo: necesito que alguien me pinte la casa.',
              ),
            ),
            const SizedBox(height: 12),
            ChambaPrimaryButton(
              label: _analyzingPrompt ? 'Analizando...' : 'Solicitar',
              onPressed: _analyzingPrompt ? null : _startRequestFlow,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerPanel(BuildContext context) {
    return GlassCard(
      borderRadius: 32,
      child: Column(
        children: [
          Container(
            width: 90,
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.colorGlassBorderSoft,
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
                  const ChambaChip(label: 'Sin categorias', selected: false),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ChambaPrimaryButton(
            label: 'Ver solicitudes cercanas',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const IncomingRequestScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Trabajadores cercanos: ${_workers.length}'),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: AppConfig.mapboxAccessToken.trim().isEmpty
          ? ColoredBox(
              color: AppTheme.colorSurfaceSoft,
              child: Center(
                child: Text(
                  'Falta MAPBOX_ACCESS_TOKEN para mostrar el mapa',
                  style: Theme.of(context).textTheme.bodyMedium,
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
                  additionalOptions: {'accessToken': AppConfig.mapboxAccessToken},
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
                          backgroundColor: AppTheme.colorPrimary,
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
                        backgroundColor: AppTheme.colorHighlight,
                        child: Icon(
                          Icons.location_on,
                          color: AppTheme.colorText.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
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
                  if (!_isClient) ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.colorPrimary.withValues(
                            alpha: 0.16,
                          ),
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
                  ],
                  if (_locationBlockMessage != null)
                    Expanded(child: _buildLocationBlocked(context))
                  else
                    Expanded(child: _buildMap()),
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
          if (_locationBlockMessage == null) ...[
            Positioned(
              right: 16,
              bottom: _isClient ? 280 : 330,
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
            if (_isClient)
              Positioned(
                top: 60,
                right: 16,
                child: _MapControl(
                  icon: Icons.help_outline,
                  highlighted: false,
                  onTap: _showHelpSheet,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: _isClient
                  ? MediaQuery.of(context).viewInsets.bottom
                  : _workerPanelBottomOffset,
              child: _isClient
                  ? _buildClientComposer()
                  : _buildWorkerPanel(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    required this.icon,
    this.highlighted = false,
    this.onTap,
    this.customBackgroundColor,
    this.customIconColor,
    this.radius = 24,
  });

  final IconData icon;
  final bool highlighted;
  final VoidCallback? onTap;
  final Color? customBackgroundColor;
  final Color? customIconColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: customBackgroundColor ??
          (highlighted
              ? AppTheme.colorPrimary
              : AppTheme.colorSurfaceSoft.withOpacity(0.5)),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          color: customIconColor ??
              (highlighted
                  ? AppTheme.colorTextOnPurple
                  : const Color.fromARGB(255, 255, 255, 255)),
        ),
      ),
    );
  }
}
