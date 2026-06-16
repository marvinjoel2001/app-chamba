import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../core/config/app_config.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../state/explore_dependencies.dart';
import '../../../request/presentation/screens/incoming_request_screen.dart';
import '../../../worker/presentation/screens/verification_checkpoint_screen.dart';
import '../../../request/presentation/screens/request_modality_screen.dart';
import '../../../request/presentation/screens/request_status_screen.dart';
import '../../../tracking/presentation/screens/tracking_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({required this.role, super.key});

  final String role;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _promptController = TextEditingController();
  final RealtimeService _realtime = RealtimeService.instance;
  bool _loading = true;
  bool _analyzingPrompt = false;
  String? _error;
  String? _locationBlockMessage;
  bool _canOpenLocationSettings = false;
  bool _isListening = false;
  late stt.SpeechToText _speechToText;
  List<dynamic> _workers = const [];
  List<dynamic> _categories = const [];
  Map<String, dynamic>? _activeRequest;
  LatLng? _currentUserLocation;
  double _currentZoom = 13;
  static const double _workerPanelBottomOffset = 84;

  bool get _isClient => widget.role == 'client';

  bool get _isVerified {
    final user = SessionStore.currentUser;
    if (user == null) return false;
    return user.verificationStatus == 'verified' ||
        (user.idPhotoVerified == true && user.facePhotoVerified == true);
  }

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    // Escuchar eventos de trabajo completado/cancelado para limpiar el banner
    _realtime.on('job.completed', _onJobFinished);
    _realtime.on('job.cancelled', _onJobFinished);
    _realtime.on('offer.new', _onNewOffer);
    _load();
  }

  @override
  void dispose() {
    _realtime.off('job.completed', _onJobFinished);
    _realtime.off('job.cancelled', _onJobFinished);
    _realtime.off('offer.new', _onNewOffer);
    _promptController.dispose();
    super.dispose();
  }

  void _onNewOffer(dynamic data) {
    if (_activeRequest != null) {
      final current = _activeRequest!['pendingOffersCount'] as int? ?? 0;
      setState(() {
        _activeRequest!['pendingOffersCount'] = current + 1;
      });
    }
  }

  void _onJobFinished(dynamic _) {
    // Limpiar sesión y recargar para quitar el banner
    SessionStore.activeRequestId = null;
    SessionStore.activeThreadId = null;
    if (mounted) {
      setState(() => _activeRequest = null);
      _load();
    }
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

    final isInitialLoad = _categories.isEmpty;

    if (isInitialLoad) {
      setState(() {
        _loading = true;
        _error = null;
        _locationBlockMessage = null;
        _canOpenLocationSettings = false;
      });
    } else {
      setState(() {
        _error = null;
        _locationBlockMessage = null;
        _canOpenLocationSettings = false;
      });
    }

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

      final response = (await ExploreDependencies.explore(
        userId: user.id,
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
      ))
          .fold(
            onSuccess: (value) => value,
            onFailure: (failure) => throw Exception(failure.message),
          )
          .payload;
      final activeRequest = response['activeRequest'];
      if (activeRequest is Map<String, dynamic>) {
        SessionStore.activeRequestId = activeRequest['id'] as String?;
      }

      // Si la solicitud activa está cancelada o completada, limpiarla
      final activeStatus =
          (activeRequest as Map<String, dynamic>?)?['status']?.toString();
      final cleanedRequest =
          (activeStatus == 'cancelled' || activeStatus == 'completed')
              ? null
              : (activeRequest is Map<String, dynamic> ? activeRequest : null);

      if (cleanedRequest == null) {
        SessionStore.activeRequestId = null;
      }

      setState(() {
        _currentUserLocation = currentLocation;
        _workers = (response['nearbyWorkers'] as List<dynamic>? ?? const []);
        _categories = (response['categories'] as List<dynamic>? ?? const []);
        _activeRequest = cleanedRequest;
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
        try {
          permission = await Geolocator.requestPermission();
        } catch (_) {
          _locationBlockMessage = 'Debes activar el GPS para pedir permisos de ubicacion.';
          _canOpenLocationSettings = true;
          return null;
        }
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

      final preview = (await ExploreDependencies.previewRequestCategories(
        description: prompt,
      ))
          .fold(
            onSuccess: (value) => value,
            onFailure: (failure) => throw Exception(failure.message),
          )
          .payload;

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RequestModalityScreen(
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
    final activeStatus = _activeRequest?['status']?.toString();

    // Trabajo asignado (en curso) → banner verde → TrackingScreen
    if (activeStatus == 'assigned') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: GestureDetector(
          onTap: () {
            SessionStore.activeRequestId = _activeRequest?['id']?.toString();
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TrackingScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1F0D),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.colorSuccess.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.colorSuccess.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.colorSuccessSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.directions_run,
                    color: AppTheme.colorSuccess,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TRABAJO EN CURSO',
                        style: TextStyle(
                          color: AppTheme.colorSuccess,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _activeRequest?['title']?.toString() ?? 'Ver detalles',
                        style: const TextStyle(
                          color: AppTheme.colorText,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Toca para ver el seguimiento',
                        style: TextStyle(
                          color: AppTheme.colorMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.colorSuccess,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Solicitud buscando/negociando → banner morado → RequestStatusScreen
    if (activeStatus == 'searching' || activeStatus == 'negotiating') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: GestureDetector(
          onTap: () {
            SessionStore.activeRequestId = _activeRequest?['id']?.toString();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RequestStatusScreen(
                  latitude: _currentUserLocation?.latitude,
                  longitude: _currentUserLocation?.longitude,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1030),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.colorPrimary.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.colorPrimary.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.colorPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.radar,
                    color: AppTheme.colorPrimary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'SOLICITUD EN CURSO',
                            style: TextStyle(
                              color: AppTheme.colorPrimaryLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Badge de ofertas recibidas
                          if (_activeRequest?['pendingOffersCount'] != null &&
                              (_activeRequest!['pendingOffersCount'] as num) >
                                  0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.colorHighlight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_activeRequest!['pendingOffersCount']} oferta${(_activeRequest!['pendingOffersCount'] as num) != 1 ? 's' : ''}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _activeRequest?['title']?.toString() ?? 'Ver solicitud',
                        style: const TextStyle(
                          color: AppTheme.colorText,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Buscando trabajadores cerca de ti...',
                        style: TextStyle(
                          color: AppTheme.colorMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.colorPrimaryLight,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Estado normal: formulario para crear solicitud
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
              readOnly: _analyzingPrompt,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText:
                    'Aqui escriba lo que buscas. Ejemplo: necesito que alguien me pinte la casa.',
                suffixIcon: IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.red : AppTheme.colorMuted,
                  ),
                  onPressed: _listenToSpeech,
                ),
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

  void _listenToSpeech() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (val) {
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          onResult: (val) {
            if (mounted) {
              setState(() {
                _promptController.text = val.recognizedWords;
              });
            }
          },
          localeId: 'es_ES',
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reconocimiento de voz no disponible')),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speechToText.stop();
    }
  }

  Widget _buildWorkerPanel(BuildContext context) {
    final panelContent = GlassCard(
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
            child: _categories.isEmpty
                ? const ChambaChip(label: 'Sin categorias', selected: false)
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChambaChip(
                          label: _categories[i].toString(),
                          selected: i == 0,
                        ),
                      );
                    },
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

    // Si no está verificado, mostrar blur overlay con botón de verificación
    if (!_isVerified) {
      return Stack(
        children: [
          // Panel difuminado de fondo
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: panelContent,
            ),
          ),
          // Overlay con mensaje y botón
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 48,
                        color: AppTheme.colorPrimary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Verifica tu perfil para ver trabajos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Necesitamos verificar tu identidad antes de mostrarte solicitudes disponibles',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.colorMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ChambaPrimaryButton(
                        label: 'Verificar mi perfil',
                        icon: Icons.verified,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const VerificationCheckpointScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return panelContent;
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
                  additionalOptions: {
                    'accessToken': AppConfig.mapboxAccessToken,
                  },
                ),
                MarkerLayer(
                  markers: [
                    // Solo mostrar workers en el mapa del worker, no del cliente
                    if (!_isClient) ..._workerMarkers,
                    // Ubicación del usuario: cliente solo ve su ubicación, worker también
                    if (_currentUserLocation != null)
                      Marker(
                        point: _currentUserLocation!,
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.location_on,
                          color: AppTheme.colorHighlight,
                          size: 36,
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
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
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
                                  chambaInitial(user?.firstName,
                                      fallback: 'U'),
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
          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Conectando con el servidor...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Esto puede tomar hasta 30 segundos',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.colorHighlight.withOpacity(0.8),
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ),
            ),
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
                  ? MediaQuery.of(context).viewInsets.bottom + 8
                  : _workerPanelBottomOffset + 8,
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
  const _MapControl({required this.icon, this.highlighted = false, this.onTap});

  final IconData icon;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: highlighted
          ? AppTheme.colorPrimary
          : AppTheme.colorSurfaceSoft.withOpacity(0.5),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          color: highlighted
              ? AppTheme.colorTextOnPurple
              : const Color.fromARGB(255, 255, 255, 255),
        ),
      ),
    );
  }
}
