import 'dart:convert';
import '../../../../core/session/session_credentials.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/cloudinary_upload_service.dart';
import '../../../../core/services/mobile_backend_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../payment/domain/entities/payment_method.dart';
import '../state/request_dependencies.dart';
import 'request_status_screen.dart';
import '../widgets/request_form_widgets.dart';

class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({
    required this.initialPrompt,
    required this.modality,
    this.initialTitle,
    this.suggestedCategories = const [],
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    this.preselectedCategory,
    this.preselectedWorkerId,
    super.key,
  });

  final String modality;

  final String initialPrompt;
  final String? initialTitle;
  final List<Map<String, dynamic>> suggestedCategories;
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;
  final String? preselectedCategory;
  final String? preselectedWorkerId;

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  late String priceType;
  late final TextEditingController _descriptionController;
  final _budgetController = TextEditingController(text: '100');
  final _estimatedHoursController = TextEditingController(text: '2');
  final _hourlyRateController = TextEditingController(text: '20');
  final _daysController = TextEditingController(text: '1');
  final _dailyRateController = TextEditingController(text: '100');
  String? _startDate;
  TimeOfDay? _startTime;

  String _formatTimeOfDay(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Fecha de inicio a enviar al backend: 'YYYY-MM-DD' o, si el cliente
  /// eligió hora, 'YYYY-MM-DDTHH:mm:00'.
  String? get _startDateForBackend {
    if (_startDate == null) return null;
    if (_startTime == null) return _startDate;
    return '${_startDate}T${_formatTimeOfDay(_startTime!)}:00';
  }

  final ImagePicker _imagePicker = ImagePicker();
  final List<_PendingImage> _pendingImages = [];
  late final List<Map<String, dynamic>> _suggestedCategories;
  bool _loading = false;
  bool _checkingLocation = true;
  String? _locationBlockMessage;
  String? _locationBlockType;
  double? _latitude;
  double? _longitude;
  String? _resolvedAddress;
  static final http.Client _client = http.Client();

  // Payment methods
  List<PaymentMethod> _paymentMethods = [];
  PaymentMethod? _selectedPaymentMethod;
  bool _loadingPaymentMethods = true;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.modality == 'hourly') {
      priceType = 'Por hora';
    } else if (widget.modality == 'daily') {
      priceType = 'Por día';
    } else {
      priceType = 'Precio fijo';
    }
    _descriptionController = TextEditingController(text: widget.initialPrompt);
    _suggestedCategories = widget.suggestedCategories
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    _initializeLocation();
    _loadPaymentMethods();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _budgetController.dispose();
    _estimatedHoursController.dispose();
    _hourlyRateController.dispose();
    _daysController.dispose();
    _dailyRateController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _firstSuggestedCategory {
    if (_suggestedCategories.isEmpty) {
      return null;
    }
    return _suggestedCategories.first;
  }

  String get _primaryCategoryName {
    final name = _firstSuggestedCategory?['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    return 'General';
  }

  Future<void> _initializeLocation() async {
    setState(() {
      _checkingLocation = true;
      _locationBlockMessage = null;
      _locationBlockType = null;
    });

    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _latitude = widget.initialLatitude;
      _longitude = widget.initialLongitude;
      _resolvedAddress = widget.initialAddress;
      if (_resolvedAddress == null || _resolvedAddress!.trim().isEmpty) {
        _resolvedAddress = await _reverseGeocode(
          widget.initialLatitude!,
          widget.initialLongitude!,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _checkingLocation = false;
      });
      return;
    }

    try {
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isEnabled) {
        if (!mounted) {
          return;
        }
        setState(() {
          _locationBlockMessage =
              'Activa la ubicacion del telefono para crear una solicitud.';
          _locationBlockType = 'disabled';
          _checkingLocation = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        try {
          permission = await Geolocator.requestPermission();
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _locationBlockMessage = 'Debes activar el GPS para dar permisos.';
            _locationBlockType = 'denied';
            _checkingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }
        setState(() {
          _locationBlockMessage = permission == LocationPermission.deniedForever
              ? 'El permiso de ubicacion esta bloqueado. Habilitalo en ajustes.'
              : 'Debes permitir ubicacion para continuar.';
          _locationBlockType = permission == LocationPermission.deniedForever
              ? 'deniedForever'
              : 'denied';
          _checkingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;
      _resolvedAddress = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _checkingLocation = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationBlockMessage = 'No se pudo obtener tu ubicacion actual.';
        _checkingLocation = false;
      });
    }
  }

  Future<String> _reverseGeocode(double latitude, double longitude) async {
    final token = AppConfig.mapboxAccessToken.trim();
    if (token.isEmpty) {
      return 'Ubicacion actual';
    }

    try {
      final endpoint = Uri.https(
        'api.mapbox.com',
        '/geocoding/v5/mapbox.places/$longitude,$latitude.json',
        {'access_token': token, 'limit': '1', 'language': 'es'},
      );

      final response =
          await _client.get(endpoint).timeout(const Duration(seconds: 8));
      if (response.statusCode >= 400) {
        return 'Ubicacion actual';
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final features = decoded['features'] as List<dynamic>? ?? const [];
      final first =
          features.isEmpty ? null : features.first as Map<String, dynamic>?;
      final placeName = first?['place_name_es']?.toString().trim();
      if (placeName != null && placeName.isNotEmpty) {
        return placeName;
      }
      final fallback = first?['place_name']?.toString().trim();
      if (fallback != null && fallback.isNotEmpty) {
        return fallback;
      }
    } catch (_) {}

    return 'Ubicacion actual';
  }

  Future<void> _showLocationMap() async {
    if (_latitude == null || _longitude == null) {
      await _initializeLocation();
      if (_latitude == null || _longitude == null) return;
    }

    final mapController = MapController();
    bool isUpdating = false;

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tu ubicación actual',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(
                      'Esta es la ubicación donde se realizará el trabajo. Solo usamos tu ubicación real para evitar solicitudes falsas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        if (AppConfig.mapboxAccessToken.isNotEmpty)
                          FlutterMap(
                            mapController: mapController,
                            options: MapOptions(
                              initialCenter: LatLng(_latitude!, _longitude!),
                              initialZoom: 15,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.all &
                                    ~InteractiveFlag.rotate,
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
                                  Marker(
                                    point: LatLng(_latitude!, _longitude!),
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: AppTheme.colorPrimary,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          const Center(child: Text('Mapa no disponible')),
                        if (isUpdating)
                          Container(
                            color: Colors.white.withValues(alpha: 0.5),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: isUpdating
                              ? null
                              : () async {
                                  setModalState(() => isUpdating = true);
                                  await _initializeLocation();
                                  if (_latitude != null && _longitude != null) {
                                    mapController.move(
                                      LatLng(_latitude!, _longitude!),
                                      15,
                                    );
                                  }
                                  setModalState(() => isUpdating = false);
                                },
                          icon: const Icon(Icons.my_location),
                          label: const Text('Actualizar con mi GPS actual'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: requestPurple,
                            side: const BorderSide(color: requestPurple),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.colorPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Confirmar y cerrar'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/payment-methods',
      );
      final response = await _client
          .get(uri, headers: SessionCredentials.headers)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final methods = data
            .map((json) => PaymentMethod.fromJson(json as Map<String, dynamic>))
            .where((m) => m.isActive)
            .toList();

        setState(() {
          _paymentMethods = methods;
          // Select first method by default (usually "Efectivo")
          if (methods.isNotEmpty) {
            _selectedPaymentMethod = methods.first;
          }
          _loadingPaymentMethods = false;
        });
      } else {
        setState(() => _loadingPaymentMethods = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loadingPaymentMethods = false);
    }
  }

  Future<void> _pickImages() async {
    if (_pendingImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximo 5 fotos por solicitud')),
      );
      return;
    }

    final option = await showModalBottomSheet<_ImageSourceOption>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ImageSourceBottomSheet(),
    );

    if (option == null) return;

    List<XFile> selected = [];

    try {
      switch (option) {
        case _ImageSourceOption.camera:
          final photo = await _imagePicker.pickImage(
            source: ImageSource.camera,
            imageQuality: 70,
            maxWidth: 1080,
          );
          if (photo != null) selected = [photo];
          break;
        case _ImageSourceOption.gallery:
          selected = await _imagePicker.pickMultiImage(
            imageQuality: 70,
            maxWidth: 1080,
          );
          break;
        case _ImageSourceOption.files:
          selected = await _imagePicker.pickMultiImage(
            imageQuality: 70,
            maxWidth: 1080,
          );
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagenes: $e')),
        );
      }
      return;
    }

    if (selected.isEmpty) return;

    final remaining = 5 - _pendingImages.length;
    final toProcess = selected.take(remaining);
    for (final item in toProcess) {
      final bytes = await item.readAsBytes();
      _pendingImages.add(_PendingImage(bytes: bytes, fileName: item.name));
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _submit() async {
    if (_locationBlockMessage != null ||
        _latitude == null ||
        _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Necesitamos tu ubicacion actual para continuar.'),
        ),
      );
      return;
    }

    final user = SessionStore.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sesion expirada.')));
      return;
    }

    final description = _descriptionController.text.trim();
    double budget = 0;
    int? estimatedHours;
    double? hourlyRate;
    int? days;
    double? dailyRate;

    if (widget.modality == 'hourly') {
      estimatedHours = int.tryParse(_estimatedHoursController.text.trim()) ?? 0;
      hourlyRate = double.tryParse(_hourlyRateController.text.trim()) ?? 0;
      budget = (estimatedHours * hourlyRate).toDouble();
    } else if (widget.modality == 'daily') {
      days = int.tryParse(_daysController.text.trim()) ?? 0;
      dailyRate = double.tryParse(_dailyRateController.text.trim()) ?? 0;
      budget = (days * dailyRate).toDouble();
    } else {
      budget = double.tryParse(_budgetController.text.trim()) ?? 0;
    }

    if (description.isEmpty || budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Completa la descripcion y verifica que los montos sean mayores a 0.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final uploadedPhotos = <Map<String, String>>[];
      for (final image in _pendingImages) {
        try {
          final uploaded = await CloudinaryUploadService.uploadImageBytes(
              bytes: image.bytes,
              fileName: image.fileName,
              folder: 'chamba/requests');
          uploadedPhotos
              .add({'url': uploaded.secureUrl, 'publicId': uploaded.publicId});
        } catch (_) {
          // Signed presets are uploaded by the server. Its private key never enters the APK.
          final mime =
              lookupMimeType(image.fileName, headerBytes: image.bytes) ??
                  'image/jpeg';
          final uploaded = await MobileBackendService.instance
              .uploadRequestPhoto(
                  'data:$mime;base64,${base64Encode(image.bytes)}');
          uploadedPhotos.add({
            'url': uploaded['url'] as String,
            'publicId': uploaded['publicId'] as String
          });
        }
      }

      final response = (await RequestDependencies.createRequest(
        clientUserId: user.id,
        title: description.split('\n').first.length > 100
            ? description.split('\n').first.substring(0, 100)
            : description.split('\n').first,
        description: description,
        category: _primaryCategoryName,
        aiCategories: _suggestedCategories,
        budget: budget,
        priceType: priceType,
        address: _resolvedAddress ?? 'Ubicacion actual',
        latitude: _latitude!,
        longitude: _longitude!,
        photos: uploadedPhotos,
        paymentMethod: _selectedPaymentMethod?.name ?? 'Efectivo',
        modality: widget.modality,
        estimatedHours: estimatedHours,
        hourlyRate: hourlyRate,
        days: days,
        dailyRate: dailyRate,
        startDate: _startDateForBackend,
      ))
          .fold(
            onSuccess: (value) => value,
            onFailure: (failure) => throw Exception(failure.message),
          )
          .payload;

      final request = response['request'] as Map<String, dynamic>?;
      SessionStore.activeRequestId = request?['id'] as String?;

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) =>
              RequestStatusScreen(latitude: _latitude!, longitude: _longitude!),
        ),
        (route) => route.isFirst,
      );
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
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildLocationState(BuildContext context) {
    if (_checkingLocation) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_locationBlockMessage != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_off,
                  size: 36,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 12),
                Text(
                  _locationBlockMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      height: 1.2, fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () async {
                    if (_locationBlockType == 'disabled') {
                      final isEnabled =
                          await Geolocator.isLocationServiceEnabled();
                      if (isEnabled) {
                        _initializeLocation();
                      } else {
                        await Geolocator.openLocationSettings();
                      }
                    } else if (_locationBlockType == 'deniedForever') {
                      final perm = await Geolocator.checkPermission();
                      if (perm == LocationPermission.always ||
                          perm == LocationPermission.whileInUse) {
                        _initializeLocation();
                      } else {
                        await Geolocator.openAppSettings();
                      }
                    } else {
                      _initializeLocation();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.colorPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _locationBlockType == 'disabled'
                        ? 'Activar ubicacion'
                        : _locationBlockType == 'deniedForever'
                            ? 'Abrir Ajustes'
                            : 'Permitir ubicacion',
                    style: const TextStyle(height: 1.2, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      children: [
        RequestStepCard(
          number: 1,
          title: 'Información del servicio',
          subtitle: 'Describe qué necesitas realizar',
          color: requestPurple,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Expanded(
                  child: Text('Descripción del servicio',
                      style: TextStyle(
                          height: 1.2,
                          color: requestInk,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700))),
              TextButton.icon(
                  onPressed: _loading ? null : _pickImages,
                  style: TextButton.styleFrom(
                      foregroundColor: requestPurple,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 0),
                      minimumSize: const Size(0, 23),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  icon:
                      const Icon(Icons.add_photo_alternate_outlined, size: 17),
                  label: Text(
                      _pendingImages.isEmpty
                          ? 'Fotos'
                          : '${_pendingImages.length}/5',
                      style: const TextStyle(
                          height: 1.2,
                          fontSize: 11,
                          fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 5),
            Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E5F0))),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const RequestIconTile(
                          icon: Icons.edit_document,
                          color: requestPurple,
                          size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                            TextField(
                                controller: _descriptionController,
                                enabled: !_loading,
                                minLines: 1,
                                maxLines: 4,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(
                                    color: requestInk,
                                    fontSize: 13.5,
                                    height: 1.2),
                                decoration: const InputDecoration(
                                    hintText:
                                        'Describe el trabajo que necesitas',
                                    hintStyle: TextStyle(
                                        height: 1.2, color: requestMuted),
                                    isDense: true,
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero)),
                            const SizedBox(height: 5),
                            Text('${_descriptionController.text.length}/120',
                                style: const TextStyle(
                                    height: 1.2,
                                    fontSize: 10,
                                    color: requestMuted)),
                          ])),
                    ])),
            if (_pendingImages.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                  height: 65,
                  child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pendingImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, index) => Stack(children: [
                            ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(_pendingImages[index].bytes,
                                    width: 65, height: 65, fit: BoxFit.cover)),
                            Positioned(
                                top: 0,
                                right: 0,
                                child: IconButton(
                                    tooltip: 'Quitar foto ${index + 1}',
                                    visualDensity: VisualDensity.compact,
                                    style: IconButton.styleFrom(
                                        backgroundColor: Colors.black54,
                                        minimumSize: const Size(25, 25)),
                                    onPressed: _loading
                                        ? null
                                        : () => setState(() =>
                                            _pendingImages.removeAt(index)),
                                    icon: const Icon(Icons.close,
                                        size: 14, color: Colors.white))),
                          ]))),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        RequestStepCard(
          number: 2,
          title: 'Detalles del trabajo',
          subtitle: 'Define la categoría, ubicación y tiempo',
          color: requestBlue,
          illustration: SizedBox(
              width: 78,
              child: Opacity(
                  opacity: .8,
                  child: Image.asset('assets/images/request/calendar.png',
                      fit: BoxFit.contain))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const RequestFieldLabel(
                text: 'Categoría del servicio',
                icon: Icons.calendar_month_rounded,
                color: requestGreen),
            const SizedBox(height: 5),
            Padding(
                padding: const EdgeInsets.only(left: 30),
                child: RequestChoiceTile(
                    title: _primaryCategoryName,
                    subtitle: _primaryCategoryName == 'General'
                        ? 'Servicio general y otros'
                        : 'Categoría del trabajo',
                    leading: const RequestIconTile(
                        icon: Icons.category_outlined,
                        color: requestPurple,
                        size: 34),
                    onTap: _loading ? null : _showCategoryPicker)),
            const SizedBox(height: 9),
            const RequestFieldLabel(
                text: 'Ubicación del servicio',
                icon: Icons.location_on_rounded,
                color: requestBlue),
            const SizedBox(height: 5),
            Padding(
                padding: const EdgeInsets.only(left: 30),
                child: RequestChoiceTile(
                    title: _resolvedAddress ?? 'Ubicación actual',
                    subtitle: 'Ubicación detectada',
                    leading: _locationThumbnail(),
                    onTap: _loading ? null : _showLocationMap,
                    extra: const Row(children: [
                      Icon(Icons.near_me_outlined,
                          color: requestPurple, size: 14),
                      SizedBox(width: 5),
                      Flexible(
                          child: Text('Ver / Actualizar ubicación',
                              style: TextStyle(
                                  height: 1.2,
                                  color: requestPurple,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)))
                    ]))),
            const SizedBox(height: 9),
            RequestFieldLabel(
                text: widget.modality == 'daily'
                    ? 'Fecha y duración'
                    : 'Duración y presupuesto',
                icon: widget.modality == 'hourly'
                    ? Icons.schedule_rounded
                    : Icons.event_note_rounded,
                color: requestGreen),
            const SizedBox(height: 5),
            Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Column(children: [
                  if (widget.modality == 'daily') ...[
                    Row(children: [
                      Expanded(
                          child: RequestDateTile(
                              label: 'Fecha de inicio',
                              value: _displayStartDate,
                              icon: Icons.calendar_month_rounded,
                              onTap: _loading ? null : _pickStartDate)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: RequestDateTile(
                              label: 'Hora de inicio',
                              value: _startTime != null
                                  ? _formatTimeOfDay(_startTime!)
                                  : 'Elegir hora',
                              icon: Icons.schedule_rounded,
                              onTap: _loading ? null : _pickStartTime)),
                    ]),
                    const SizedBox(height: 8),
                  ],
                  if (widget.modality == 'fixed')
                    RequestAmountField(
                        label: 'Monto total',
                        controller: _budgetController,
                        enabled: !_loading)
                  else
                    Row(children: [
                      Expanded(
                          child: RequestQuantityField(
                              label: widget.modality == 'daily'
                                  ? 'Días de trabajo'
                                  : 'Horas estimadas',
                              controller: widget.modality == 'daily'
                                  ? _daysController
                                  : _estimatedHoursController,
                              enabled: !_loading)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: RequestAmountField(
                              label: widget.modality == 'daily'
                                  ? 'Pago por día'
                                  : 'Pago por hora',
                              controller: widget.modality == 'daily'
                                  ? _dailyRateController
                                  : _hourlyRateController,
                              enabled: !_loading)),
                    ]),
                ])),
          ]),
        ),
        const SizedBox(height: 10),
        RequestStepCard(
            number: 3,
            title: 'Método de pago',
            subtitle: 'Selecciona cómo quieres pagar',
            color: requestOrange,
            child: RequestChoiceTile(
                title: _selectedPaymentMethod?.name ?? 'Efectivo',
                subtitle: _loadingPaymentMethods
                    ? 'Cargando métodos de pago…'
                    : _selectedPaymentMethod?.description ??
                        'Pagarás al finalizar el trabajo',
                leading: const RequestIconTile(
                    icon: Icons.payments_outlined,
                    color: requestOrange,
                    size: 38),
                color: requestInk,
                background: const Color(0xFFFFFBF2),
                borderColor: const Color(0xFFFFD993),
                showArrow:
                    !_loadingPaymentMethods && _paymentMethods.isNotEmpty,
                onTap: _loading ||
                        _loadingPaymentMethods ||
                        _paymentMethods.isEmpty
                    ? null
                    : _showPaymentPicker)),
      ],
    );
  }

  String get _displayStartDate {
    final date = DateTime.tryParse(_startDate ?? '');
    if (date == null) return 'Elegir fecha';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = DateTime.tryParse(_startDate ?? '');
    final date = await showDatePicker(
        context: context,
        initialDate: current != null && !current.isBefore(today)
            ? current
            : today.add(const Duration(days: 1)),
        firstDate: today,
        lastDate: today.add(const Duration(days: 365)));
    if (date != null && mounted) {
      setState(() => _startDate = date.toIso8601String().split('T')[0]);
    }
  }

  Future<void> _pickStartTime() async {
    final time = await showTimePicker(
        context: context,
        initialTime: _startTime ?? const TimeOfDay(hour: 8, minute: 0));
    if (time != null && mounted) setState(() => _startTime = time);
  }

  Future<void> _showPaymentPicker() async {
    final method = await showModalBottomSheet<PaymentMethod>(
        context: context,
        backgroundColor: Colors.white,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
                child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Método de pago',
                      style: TextStyle(
                          height: 1.2,
                          color: requestInk,
                          fontSize: 18,
                          fontWeight: FontWeight.w700))),
              ..._paymentMethods.map((m) => ListTile(
                  leading: const RequestIconTile(
                      icon: Icons.payments_outlined,
                      color: requestOrange,
                      size: 38),
                  title: Text(m.name,
                      style: const TextStyle(height: 1.2, color: requestInk)),
                  subtitle: Text(m.description ?? '',
                      style: const TextStyle(height: 1.2, color: requestMuted)),
                  trailing: m.id == _selectedPaymentMethod?.id
                      ? const Icon(Icons.check_circle, color: requestPurple)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, m))),
            ]))));
    if (method != null && mounted) {
      setState(() => _selectedPaymentMethod = method);
    }
  }

  Future<void> _showCategoryPicker() async {
    final future = MobileBackendService.instance.categories();
    final category = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: Colors.white,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
            child: SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * .55,
                child: Column(children: [
                  const Text('Categoría del servicio',
                      style: TextStyle(
                          height: 1.2,
                          color: requestInk,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Expanded(
                      child: FutureBuilder<Map<String, dynamic>>(
                          future: future,
                          builder: (_, snapshot) {
                            final choices = <String, Map<String, dynamic>>{
                              'General': {'name': 'General', 'confidence': 1.0},
                              for (final item in _suggestedCategories)
                                item['name'].toString(): item,
                              for (final item
                                  in (snapshot.data?['categories'] as List? ??
                                      []))
                                if (item is Map && item['active'] != false)
                                  item['name'].toString():
                                      Map<String, dynamic>.from(item),
                            };
                            return ListView(children: [
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting)
                                const LinearProgressIndicator(
                                    color: requestPurple),
                              if (snapshot.hasError)
                                const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text(
                                        'No se pudo cargar el catálogo. Puedes elegir una categoría sugerida.',
                                        style: TextStyle(
                                            height: 1.2, color: requestMuted))),
                              ...choices.values.map((item) => ListTile(
                                  leading: const RequestIconTile(
                                      icon: Icons.category_outlined,
                                      color: requestPurple,
                                      size: 34),
                                  title: Text(item['name'].toString(),
                                      style: const TextStyle(
                                          height: 1.2, color: requestInk)),
                                  trailing: item['name'] == _primaryCategoryName
                                      ? const Icon(Icons.check_circle,
                                          color: requestPurple)
                                      : null,
                                  onTap: () =>
                                      Navigator.pop(sheetContext, item))),
                            ]);
                          })),
                ]))));
    if (category != null && mounted) {
      setState(() {
        _suggestedCategories.clear();
        _suggestedCategories.add({...category, 'confidence': 1.0});
      });
    }
  }

  Widget _locationThumbnail() => ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
          width: 48,
          height: 52,
          child: IgnorePointer(
              child: AppConfig.mapboxAccessToken.isNotEmpty &&
                      _latitude != null &&
                      _longitude != null
                  ? FlutterMap(
                      key: ValueKey('$_latitude,$_longitude'),
                      options: MapOptions(
                          initialCenter: LatLng(_latitude!, _longitude!),
                          initialZoom: 14,
                          interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none)),
                      children: [
                          TileLayer(
                              urlTemplate:
                                  'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
                              userAgentPackageName: 'com.chambatrabajo.app',
                              additionalOptions: {
                                'accessToken': AppConfig.mapboxAccessToken
                              }),
                          MarkerLayer(markers: [
                            Marker(
                                point: LatLng(_latitude!, _longitude!),
                                width: 28,
                                height: 32,
                                child: const Icon(Icons.location_on,
                                    color: requestPurple, size: 30))
                          ]),
                        ])
                  : const ColoredBox(
                      color: Color(0xFFF0F2F7),
                      child: Center(
                          child: Icon(Icons.location_on,
                              color: requestPurple, size: 30))))));

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
            child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(children: [
                Container(
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: requestPurple.withValues(alpha: .08),
                              blurRadius: 16,
                              offset: const Offset(0, 3))
                        ]),
                    child: IconButton(
                        tooltip: 'Volver',
                        onPressed:
                            _loading ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: requestInk, size: 25))),
                const SizedBox(width: 16),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Nueva solicitud',
                          style: TextStyle(
                              height: 1.2,
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              color: requestInk,
                              letterSpacing: -.5)),
                      SizedBox(height: 3),
                      Text('Cuéntanos los detalles de tu solicitud',
                          style: TextStyle(
                              height: 1.2,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: requestMuted)),
                    ])),
              ])),
          Expanded(child: _buildLocationState(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 7, 14, 9),
            child: Container(
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF8138FF), Color(0xFF7133F8)]),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                          color: requestPurple.withValues(alpha: .15),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ]),
                child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: _loading ||
                                _checkingLocation ||
                                _locationBlockMessage != null
                            ? null
                            : _submit,
                        child: SizedBox(
                            height: 48,
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                      _loading
                                          ? 'Publicando…'
                                          : 'Publicar solicitud',
                                      style: const TextStyle(
                                          height: 1.2,
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 13),
                                  if (_loading)
                                    const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                  else
                                    const Icon(Icons.arrow_forward_rounded,
                                        color: Colors.white, size: 23),
                                ]))))),
          ),
        ])),
      ));
}

class _PendingImage {
  _PendingImage({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

enum _ImageSourceOption { camera, gallery, files }

class _ImageSourceBottomSheet extends StatelessWidget {
  const _ImageSourceBottomSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Agregar fotos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selecciona una opción',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          _OptionTile(
            icon: Icons.camera_alt_outlined,
            title: 'Camara',
            subtitle: 'Toma una foto ahora',
            color: Colors.blue,
            onTap: () => Navigator.of(context).pop(_ImageSourceOption.camera),
          ),
          _OptionTile(
            icon: Icons.photo_library_outlined,
            title: 'Galeria',
            subtitle: 'Selecciona de tu album',
            color: Colors.purple,
            onTap: () => Navigator.of(context).pop(_ImageSourceOption.gallery),
          ),
          _OptionTile(
            icon: Icons.folder_open_outlined,
            title: 'Archivos',
            subtitle: 'Busca en tus archivos',
            color: Colors.orange,
            onTap: () => Navigator.of(context).pop(_ImageSourceOption.files),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
