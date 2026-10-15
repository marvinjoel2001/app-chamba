import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../state/explore_dependencies.dart';
import '../../../request/presentation/screens/request_modality_screen.dart';
import '../../../request/presentation/screens/request_status_screen.dart';
import '../../../tracking/presentation/screens/tracking_screen.dart';

/// Inicio del cliente: mapa y caja para pedir un servicio por voz o texto.
/// El trabajador tiene su propio inicio (IncomingRequestScreen).
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _promptController = TextEditingController();

  /// Avisa a la vista enfocada del compositor (otra ruta) que cambió el
  /// estado de esta pantalla: escucha de voz, nivel del micrófono, análisis.
  final ValueNotifier<int> _composerTick = ValueNotifier<int>(0);
  bool _focusedComposerOpen = false;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _composerTick.value++;
  }
  final RealtimeService _realtime = RealtimeService.instance;
  bool _loading = true;
  bool _refreshing = false;
  bool _locating = false;
  bool _analyzingPrompt = false;
  String? _error;
  String? _locationBlockMessage;
  String? _locationBlockType;
  bool _isListening = false;
  late stt.SpeechToText _speechToText;
  // Feedback del micrófono (tipo WhatsApp): pulso animado, vibración y beeps.
  late AnimationController _micPulseController;
  final AudioPlayer _micSoundPlayer = AudioPlayer();
  double _micSoundLevel = 0;
  List<dynamic> _categories = const [];
  Map<String, dynamic>? _activeRequest;
  LatLng? _currentUserLocation;
  double _currentZoom = 13;

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _micSoundPlayer.setPlayerMode(PlayerMode.lowLatency);
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
    _composerTick.dispose();
    _micPulseController.dispose();
    _micSoundPlayer.dispose();
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

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _load();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _load() async {
    final user = SessionStore.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Sesión expirada. Inicia sesión de nuevo.';
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
        _locationBlockType = null;
      });
    } else {
      setState(() {
        _error = null;
        _locationBlockMessage = null;
        _locationBlockType = null;
      });
    }

    try {
      final currentLocation = await _resolveCurrentLocationRequired();
      if (currentLocation == null) {
        setState(() {
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
      if (!mounted) return;
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
            'Activa la ubicación del teléfono para buscar trabajadores cercanos.';
        _locationBlockType = 'disabled';
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        try {
          permission = await Geolocator.requestPermission();
        } catch (_) {
          _locationBlockMessage = 'Debes activar el GPS para pedir permisos de ubicación.';
          _locationBlockType = 'denied';
          return null;
        }
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationBlockMessage = permission == LocationPermission.deniedForever
            ? 'El permiso de ubicación está bloqueado. Debes habilitarlo en ajustes para continuar.'
            : 'Debes permitir la ubicación para usar esta pantalla.';
        _locationBlockType =
            permission == LocationPermission.deniedForever ? 'deniedForever' : 'denied';
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
          'No se pudo obtener tu ubicación actual. Intenta nuevamente.';
      return null;
    }
  }

  LatLng get _mapCenter {
    // Sin ubicación todavía: centro de Santa Cruz de la Sierra.
    return _currentUserLocation ?? const LatLng(-17.7834, -63.1821);
  }

  Future<void> _centerOnMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final location = await _resolveCurrentLocationRequired();
      if (!mounted) return;
      if (location == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _locationBlockMessage ??
                  'No se pudo obtener tu ubicación actual.',
            ),
          ),
        );
        return;
      }
      setState(() => _currentUserLocation = location);
      _mapController.move(location, _currentZoom < 15 ? 15 : _currentZoom);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
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

  /// Abre el compositor a pantalla completa (fondo difuminado, sugerencias y
  /// micrófono grande) al tocar el campo de texto del inicio. Con [listen]
  /// (micrófono del inicio) empieza a escuchar apenas termina de abrirse.
  Future<void> _openFocusedComposer({bool listen = false}) async {
    if (_focusedComposerOpen || _analyzingPrompt) return;
    _focusedComposerOpen = true;
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();
    if (listen) {
      // Tras la animación de entrada, para que el beep coincida con la vista.
      Future<void>.delayed(const Duration(milliseconds: 340), () {
        if (mounted && _focusedComposerOpen && !_isListening) {
          _listenToSpeech();
        }
      });
    }
    final submit = await Navigator.of(context, rootNavigator: true).push<bool>(
      PageRouteBuilder<bool>(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, animation, __) =>
            _FocusedComposer(state: this, animation: animation),
      ),
    );
    _focusedComposerOpen = false;
    if (!mounted) return;
    if (submit == true) await _startRequestFlow();
  }

  Future<void> _startRequestFlow() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Describe primero lo que estás buscando.'),
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
                  'Necesitamos tu ubicación para crear la solicitud.',
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
                  'Cómo pedir ayuda',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Escribe lo que necesitas con un ejemplo claro, por ejemplo: necesito que alguien me pinte la casa.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'La app analizará tu texto, sugerirá categorías y luego te llevará al formulario para completar presupuesto y fotos.',
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
                Icons.location_off_rounded,
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
                label: _locationBlockType == 'disabled'
                    ? 'Activar ubicación'
                    : _locationBlockType == 'deniedForever'
                        ? 'Abrir Ajustes'
                        : 'Permitir ubicación',
                onPressed: () async {
                  if (_locationBlockType == 'disabled') {
                    final isEnabled = await Geolocator.isLocationServiceEnabled();
                    if (isEnabled) {
                      _load();
                    } else {
                      await Geolocator.openLocationSettings();
                    }
                  } else if (_locationBlockType == 'deniedForever') {
                    final perm = await Geolocator.checkPermission();
                    if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
                      _load();
                    } else {
                      await Geolocator.openAppSettings();
                    }
                  } else {
                    _load();
                  }
                },
              ),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.colorSuccess.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: AppTheme.shadowLg,
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
                    Icons.directions_run_rounded,
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
                  Icons.chevron_right_rounded,
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
      final title = _activeRequest?['title']?.toString() ?? 'Ver solicitud';
      final address = _activeRequest?['address']?.toString() ?? 'Ubicación no disponible';
      final pendingOffersCount = (_activeRequest?['pendingOffersCount'] as num?)?.toInt() ?? 0;
      final hasOffers = pendingOffersCount > 0;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.colorPrimary.withValues(alpha: 0.18),
                width: 1.5,
              ),
              boxShadow: AppTheme.shadowLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Section (Badge + Title + Address vs Icon)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Animated Badge EN CURSO
                          const PulseBadge(),
                          const SizedBox(height: 16),
                          Text(
                            title,
                            style: const TextStyle(
                              color: AppTheme.colorText,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, color: AppTheme.colorMuted, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  address,
                                  style: const TextStyle(color: AppTheme.colorMuted, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Circular Glowing Icon
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.colorPrimaryTint,
                        border: Border.all(color: AppTheme.colorPrimary.withValues(alpha: 0.12), width: 1),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/images/icon/list.png',
                          width: 105,
                          height: 105,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Divider line (simulating dashed visually with low opacity)
                const Divider(color: AppTheme.colorGlassBorderSoft, height: 1, thickness: 1),
                const SizedBox(height: 16),
                // Bottom section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: hasOffers ? AppTheme.colorSuccessSoft : AppTheme.colorPrimaryTint,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        hasOffers ? Icons.mark_email_unread_rounded : Icons.hourglass_bottom_rounded,
                        color: hasOffers ? AppTheme.colorSuccess : AppTheme.colorPrimary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasOffers ? '¡Tienes nuevas ofertas!' : 'Buscando trabajadores cerca de ti...',
                            style: const TextStyle(
                              color: AppTheme.colorText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasOffers 
                              ? 'Revisa los $pendingOffersCount trabajadores interesados'
                              : 'Te notificaremos cuando recibas nuevas ofertas',
                            style: const TextStyle(
                              color: AppTheme.colorMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
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

    // Estado normal: formulario para crear solicitud
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 32,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(left: 20, right: 16, top: 16, bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.colorGlassInputSoft,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.colorGlassBorderSoft),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SvgPicture.string(
                              '''
                              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                                <path d="M10 2.5L11.75 8.25L17.5 10L11.75 11.75L10 17.5L8.25 11.75L2.5 10L8.25 8.25L10 2.5Z" fill="#7C3AED"/>
                                <path d="M19 13L19.65 15.35L22 16L19.65 16.65L19 19L18.35 16.65L16 16L18.35 15.35L19 13Z" fill="#7C3AED"/>
                              </svg>
                              ''',
                              width: 20,
                              height: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Escribe lo que buscas...',
                              style: const TextStyle(
                                color: AppTheme.colorMuted,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _promptController,
                          minLines: 2,
                          maxLines: 4,
                          // Se escribe en la vista enfocada: aquí solo abre.
                          readOnly: true,
                          showCursor: false,
                          onTap: _openFocusedComposer,
                          textInputAction: TextInputAction.newline,
                          keyboardType: TextInputType.multiline,
                          style: const TextStyle(
                            color: AppTheme.colorText,
                            fontSize: 17,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: false,
                            fillColor: Colors.transparent,
                            hintText: _isListening
                                ? 'Te estamos escuchando…\nhabla con confianza.'
                                : 'Ejemplo: necesito que alguien\nme pinte la casa.',
                            hintStyle: TextStyle(
                              color: AppTheme.colorMuted.withValues(alpha: 0.85),
                              fontSize: 17,
                              height: 1.4,
                            ),
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    // Abre la vista enfocada y empieza a escuchar ahí.
                    onTap: () => _openFocusedComposer(listen: true),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Anillos que se expanden mientras la app escucha.
                          if (_isListening)
                            AnimatedBuilder(
                              animation: _micPulseController,
                              builder: (context, _) {
                                final t = _micPulseController.value;
                                final t2 = (t + 0.5) % 1.0;
                                Widget ring(double progress) => Container(
                                      width: 52 + progress * 34,
                                      height: 52 + progress * 34,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppTheme.colorError.withValues(
                                            alpha: (1 - progress) * 0.55,
                                          ),
                                          width: 2,
                                        ),
                                      ),
                                    );
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [ring(t), ring(t2)],
                                );
                              },
                            ),
                          // Botón del micrófono; late al ritmo de la voz.
                          AnimatedScale(
                            scale: _isListening
                                ? 1.0 + _micSoundLevel * 0.18
                                : 1.0,
                            duration: const Duration(milliseconds: 120),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: _isListening
                                      ? const [
                                          Color(0xFFE53950),
                                          Color(0xFFB01836),
                                        ]
                                      : const [
                                          Color(0xFF8B5CF6),
                                          Color(0xFF6D28D9),
                                        ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isListening
                                            ? AppTheme.colorError
                                            : AppTheme.colorPrimary)
                                        .withValues(alpha: 0.32),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF8B5CF6),
                    Color(0xFF6D28D9),
                  ],
                ),
                boxShadow: AppTheme.shadowPrimary,
              ),
              child: ElevatedButton.icon(
                onPressed: _analyzingPrompt ? null : _startRequestFlow,
                icon: _analyzingPrompt 
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white),
                label: Text(
                  _analyzingPrompt ? 'Analizando...' : 'Solicitar',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  overlayColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ).copyWith(
                  elevation: WidgetStateProperty.all(0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Feedback al empezar a escuchar: vibración + beep ascendente (tipo WhatsApp).
  void _playMicStartFeedback() {
    HapticFeedback.mediumImpact();
    _micSoundPlayer.play(AssetSource('sounds/mic_start.wav'), volume: 0.6);
  }

  /// Feedback al dejar de escuchar: vibración suave + beep descendente.
  void _playMicStopFeedback() {
    HapticFeedback.lightImpact();
    _micSoundPlayer.play(AssetSource('sounds/mic_stop.wav'), volume: 0.5);
  }

  void _setListening(bool listening) {
    if (!mounted) return;
    if (listening == _isListening) return;
    setState(() {
      _isListening = listening;
      if (!listening) _micSoundLevel = 0;
    });
    if (listening) {
      _micPulseController.repeat();
    } else {
      _micPulseController.stop();
      _micPulseController.reset();
      _playMicStopFeedback();
    }
  }

  void _listenToSpeech() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            _setListening(false);
          }
        },
        onError: (val) {
          _setListening(false);
        },
      );
      if (available) {
        _playMicStartFeedback();
        _setListening(true);
        _speechToText.listen(
          onResult: (val) {
            if (mounted) {
              setState(() {
                _promptController.text = val.recognizedWords;
              });
            }
          },
          onSoundLevelChange: (level) {
            // En Android el nivel llega aprox. entre -2 y 10 dB.
            if (mounted && _isListening) {
              setState(() {
                _micSoundLevel = ((level + 2) / 12).clamp(0.0, 1.0);
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
      _setListening(false);
      _speechToText.stop();
    }
  }

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: AppConfig.mapboxAccessToken.trim().isEmpty
          ? ColoredBox(
              color: AppTheme.colorSurfaceSoft,
              child: Center(
                child: Text(
                  'El mapa no está disponible en este momento',
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
                  userAgentPackageName: 'com.chambatrabajo.app',
                  additionalOptions: {
                    'accessToken': AppConfig.mapboxAccessToken,
                  },
                ),
                MarkerLayer(
                  markers: [
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
    return Scaffold(
      body: Stack(
        children: [
          const ChambaBackground(showGrid: true, child: SizedBox.expand()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  if (_locationBlockMessage != null)
                    Expanded(child: _buildLocationBlocked(context))
                  else
                    Expanded(child: _buildMap()),
                ],
              ),
            ),
          ),
          if (_loading)
            const Positioned.fill(child: _ExploreSkeleton()),
          if (_error != null)
            Positioned(
              left: 20,
              right: 20,
              top: 110,
              child: GlassCard(
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: AppTheme.colorWarning, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.colorText, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _load,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppTheme.colorPrimaryTint,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Reintentar',
                        style: TextStyle(
                          color: AppTheme.colorPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_locationBlockMessage == null) ...[
            Positioned(
              right: 16,
              bottom: 280,
              child: Column(
                children: [
                  _MapControl(
                    icon: _refreshing ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
                    onTap: _refreshing ? null : _refresh,
                  ),
                  const SizedBox(height: 12),
                  _MapControl(icon: Icons.add_rounded, onTap: _zoomIn),
                  const SizedBox(height: 12),
                  _MapControl(icon: Icons.remove_rounded, onTap: _zoomOut),
                  const SizedBox(height: 12),
                  _MapControl(
                    icon: _locating ? Icons.hourglass_top_rounded : Icons.my_location_rounded,
                    highlighted: true,
                    onTap: _locating ? null : _centerOnMyLocation,
                  ),
                ],
              ),
            ),
            Positioned(
                top: 60,
                right: 16,
                child: _MapControl(
                  icon: Icons.help_outline_rounded,
                  highlighted: false,
                  onTap: _showHelpSheet,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
              child: _buildClientComposer(),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: highlighted ? AppTheme.shadowPrimary : AppTheme.shadowMd,
      ),
      child: Material(
        color: highlighted ? AppTheme.colorPrimary : Colors.white,
        shape: CircleBorder(
          side: highlighted
              ? BorderSide.none
              : const BorderSide(color: AppTheme.colorGlassBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: highlighted
              ? Colors.white.withValues(alpha: 0.25)
              : AppTheme.colorPrimary.withValues(alpha: 0.12),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              icon,
              color: highlighted ? Colors.white : AppTheme.colorText,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton de la pantalla de inicio mientras conecta con el servidor.
class _ExploreSkeleton extends StatelessWidget {
  const _ExploreSkeleton();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.colorBackground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              const Expanded(
                child: ChambaShimmer(
                  child: SkeletonBox(radius: 28, height: double.infinity),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: AppTheme.colorGlassBorder),
                ),
                child: const ChambaShimmer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 170, height: 14),
                      SizedBox(height: 14),
                      SkeletonBox(height: 16),
                      SizedBox(height: 8),
                      SkeletonBox(width: 220, height: 16),
                      SizedBox(height: 20),
                      SkeletonBox(height: 54, radius: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PulseBadge extends StatefulWidget {
  const PulseBadge({super.key});

  @override
  State<PulseBadge> createState() => _PulseBadgeState();
}

class _PulseBadgeState extends State<PulseBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.1, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.colorPrimary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.colorPrimary.withValues(alpha: _animation.value * 0.35),
                blurRadius: 4 + (_animation.value * 10),
                spreadRadius: _animation.value * 1.5,
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 2 + (_animation.value * 6),
                      spreadRadius: _animation.value * 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'EN CURSO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compositor enfocado del inicio: fondo difuminado, saludo, tarjeta con el
/// campo y el micrófono, y sugerencias de qué pedir. Comparte el controlador,
/// la voz y el envío con [_ExploreScreenState].
class _FocusedComposer extends StatefulWidget {
  const _FocusedComposer({required this.state, required this.animation});

  final _ExploreScreenState state;
  final Animation<double> animation;

  static const suggestions = [
    'Necesito alguien que limpie mi casa',
    'Reparar un aire acondicionado',
    'Mudanza para este fin de semana',
    'Arreglar una fuga en el baño',
  ];

  @override
  State<_FocusedComposer> createState() => _FocusedComposerState();
}

class _FocusedComposerState extends State<_FocusedComposer> {
  final FocusNode _focus = FocusNode();

  _ExploreScreenState get _s => widget.state;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _close() {
    if (_s._isListening) _s._listenToSpeech();
    Navigator.of(context).pop(false);
  }

  void _submit() {
    if (_s._promptController.text.trim().isEmpty) {
      _focus.requestFocus();
      return;
    }
    if (_s._isListening) _s._listenToSpeech();
    Navigator.of(context).pop(true);
  }

  void _useSuggestion(String text) {
    HapticFeedback.selectionClick();
    final controller = _s._promptController;
    controller.text = text;
    controller.selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  Widget build(BuildContext context) {
    final rawName = SessionStore.currentUser?.firstName.trim() ?? '';
    final name = rawName.isEmpty
        ? ''
        : rawName[0].toUpperCase() + rawName.substring(1);
    final curved = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemOverlay,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) => BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 14 * curved.value,
            sigmaY: 14 * curved.value,
          ),
          child: ColoredBox(
            color: const Color(0xFFF7F6FC).withValues(alpha: 0.62 * curved.value),
            child: child,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                _s._composerTick,
                _s._promptController,
                _s._micPulseController,
              ]),
              builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _CloseButton(onTap: _close),
                        ),
                        const SizedBox(height: 32),
                        FadeTransition(
                          opacity: curved,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.06),
                              end: Offset.zero,
                            ).animate(curved),
                            child: Column(
                              children: [
                                Text(
                                  name.isEmpty ? 'Hola' : 'Hola, $name',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppTheme.colorText,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '¿Qué servicio necesitas hoy?',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.colorMuted,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                _buildCard(),
                                const SizedBox(height: 24),
                                for (final s in _FocusedComposer.suggestions)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _SuggestionChip(
                                      text: s,
                                      onTap: _s._analyzingPrompt
                                          ? null
                                          : () => _useSuggestion(s),
                                    ),
                                  ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final hasText = _s._promptController.text.trim().isNotEmpty;
    final listening = _s._isListening;
    final analyzing = _s._analyzingPrompt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF5F0FF)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E7C3AED),
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          SvgPicture.string(
            '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
            '<path d="M10 2.5L11.75 8.25L17.5 10L11.75 11.75L10 17.5L8.25 11.75L2.5 10L8.25 8.25L10 2.5Z" fill="#7C3AED"/>'
            '<path d="M19 13L19.65 15.35L22 16L19.65 16.65L19 19L18.35 16.65L16 16L18.35 15.35L19 13Z" fill="#7C3AED"/>'
            '</svg>',
            width: 30,
            height: 30,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _s._promptController,
            focusNode: _focus,
            readOnly: analyzing,
            minLines: 1,
            maxLines: 4,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(),
            style: const TextStyle(
              color: AppTheme.colorText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: listening ? 'Te escucho…' : 'Cuéntame qué necesitas...',
              hintStyle: TextStyle(
                color: AppTheme.colorMuted.withValues(alpha: 0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 22),
          _BigMicButton(
            listening: listening,
            level: _s._micSoundLevel,
            pulse: _s._micPulseController.value,
            onTap: analyzing ? null : _s._listenToSpeech,
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              listening ? 'Escuchando… toca para detener' : 'Toca para hablar',
              key: ValueKey(listening),
              style: TextStyle(
                color: listening ? AppTheme.colorError : AppTheme.colorMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: hasText
                ? Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: ChambaPrimaryButton(
                      label: analyzing ? 'Analizando...' : 'Solicitar',
                      icon: Icons.send_rounded,
                      onPressed: analyzing ? null : _submit,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cerrar',
      excludeSemantics: true,
      child: Material(
        color: AppTheme.colorText.withValues(alpha: 0.42),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.close_rounded, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

class _BigMicButton extends StatelessWidget {
  const _BigMicButton({
    required this.listening,
    required this.level,
    required this.pulse,
    required this.onTap,
  });

  final bool listening;
  final double level;
  final double pulse;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = listening ? AppTheme.colorError : AppTheme.colorPrimary;
    Widget ring(double progress) => Container(
          width: 80 + progress * 40,
          height: 80 + progress * 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: (1 - progress) * 0.45),
              width: 2,
            ),
          ),
        );

    return Semantics(
      button: true,
      label: listening ? 'Detener dictado' : 'Dictar por voz',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 124,
          height: 124,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Halo suave permanente.
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.08),
                ),
              ),
              if (listening) ...[ring(pulse), ring((pulse + 0.5) % 1.0)],
              AnimatedScale(
                scale: listening ? 1.0 + level * 0.15 : 1.0,
                duration: const Duration(milliseconds: 120),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: listening
                          ? const [Color(0xFFF0505F), Color(0xFFC81E3A)]
                          : const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.38),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.78),
      shape: StadiumBorder(
        side: BorderSide(color: AppTheme.colorPrimary.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: AppTheme.colorPrimary.withValues(alpha: 0.10),
        highlightColor: AppTheme.colorPrimary.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Text(
            '“$text”',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.colorText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
