import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/cloudinary_upload_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../payment/domain/entities/payment_method.dart';
import '../state/request_dependencies.dart';
import 'request_status_screen.dart';

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
  final ImagePicker _imagePicker = ImagePicker();
  final List<_PendingImage> _pendingImages = [];
  late final List<Map<String, dynamic>> _suggestedCategories;
  bool _loading = false;
  bool _checkingLocation = true;
  String? _locationBlockMessage;
  bool _canOpenLocationSettings = false;
  double? _latitude;
  double? _longitude;
  String? _resolvedAddress;
  static final http.Client _client = http.Client();

  // Payment methods
  List<PaymentMethod> _paymentMethods = [];
  PaymentMethod? _selectedPaymentMethod;
  bool _loadingPaymentMethods = true;

  final ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0.0;

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

    _scrollController.addListener(() {
      if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
        setState(() {
          _scrollProgress = (_scrollController.offset / _scrollController.position.maxScrollExtent).clamp(0.0, 1.0);
        });
      }
    });
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
      _canOpenLocationSettings = false;
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
          _canOpenLocationSettings = true;
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
          _canOpenLocationSettings =
              permission == LocationPermission.deniedForever;
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

      final response = await _client.get(endpoint);
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
                                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
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
                            color: Colors.white.withOpacity(0.5),
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
      final response = await _client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

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
      setState(() => _loadingPaymentMethods = false);
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
          content: Text('Completa la descripcion y verifica que los montos sean mayores a 0.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final uploadedPhotos = <Map<String, String>>[];
      for (final image in _pendingImages) {
        final uploaded = await CloudinaryUploadService.uploadImageBytes(
          bytes: image.bytes,
          fileName: image.fileName,
          folder: 'chamba/requests',
        );
        uploadedPhotos.add({
          'url': uploaded.secureUrl,
          'publicId': uploaded.publicId,
        });
      }

      final response = (await RequestDependencies.createRequest(
        clientUserId: user.id,
        title: widget.initialTitle?.trim().isNotEmpty == true
            ? widget.initialTitle!.trim()
            : 'Solicitud de ${_primaryCategoryName.toLowerCase()}',
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
        startDate: _startDate,
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
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ]
            ),
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
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _initializeLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.colorPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Permitir ubicacion', style: TextStyle(color: Colors.white)),
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

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Qué necesitas?
        const Text(
          '¿Qué necesitas?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF090D16),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.colorPrimary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: AppTheme.colorPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextField(
                      controller: _descriptionController,
                      minLines: 2,
                      maxLines: null,
                      readOnly: true,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                      decoration: const InputDecoration(
                        hintText: 'Ejemplo: Busco alguien que limpie mi techo y canaletas.',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        filled: true,
                        fillColor: Colors.transparent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_descriptionController.text.length}/120',
                      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Categoría del servicio
        const Text(
          'Categoría del servicio',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF090D16),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _suggestedCategories.isEmpty
              ? const [_CategoryPill(label: 'General', selected: true)]
              : _suggestedCategories.map((category) {
                  final label = category['name']?.toString().trim().isNotEmpty == true
                          ? category['name'].toString().trim()
                          : 'General';
                  // Simulamos que todas están pre-seleccionadas si son sugeridas por la IA,
                  // o permitimos que el usuario las seleccione. Por simplicidad visual,
                  // las mostraremos todas "activas" o la primera activa si se desea.
                  return _CategoryPill(
                    label: label,
                    selected: true, // Mostrar todas sugeridas como activas según el pedido
                  );
                }).toList(),
        ),
        const SizedBox(height: 24),

        // Ubicación del servicio
        const Text(
          'Ubicación del servicio',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF090D16),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[100]!),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Placeholder del mapa
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.location_on,
                    color: AppTheme.colorPrimary,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _resolvedAddress ?? 'Ubicación actual',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ubicación detectada',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _loading ? null : _showLocationMap,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ver / Actualizar ubicación',
                            style: TextStyle(
                              color: AppTheme.colorPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.chevron_right, size: 14, color: AppTheme.colorPrimary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Presupuesto estimado
        const Text(
          'Presupuesto',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF090D16),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.modality == 'fixed') ...[
          _buildAmountField('Monto total', _budgetController),
        ] else if (widget.modality == 'hourly') ...[
          Row(
            children: [
              Expanded(child: _buildNumberField('Horas estimadas', _estimatedHoursController)),
              const SizedBox(width: 12),
              Expanded(child: _buildAmountField('Pago por hora', _hourlyRateController)),
            ],
          ),
        ] else if (widget.modality == 'daily') ...[
          Row(
            children: [
              Expanded(child: _buildNumberField('Días de trabajo', _daysController)),
              const SizedBox(width: 12),
              Expanded(child: _buildAmountField('Pago por día', _dailyRateController)),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.colorPrimary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: AppTheme.colorPrimary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  priceType == 'Por hora'
                      ? 'Se calculará el pago en base a las horas trabajadas. Podrás acordar la tarifa final con el trabajador.'
                      : priceType == 'Por día'
                          ? 'Se calculará el pago por cada día de trabajo. Podrás acordar la tarifa final con el trabajador.'
                          : 'El precio es referencial. Podrás acordar el monto final con el trabajador seleccionado.',
                  style: TextStyle(
                    color: AppTheme.colorPrimary.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Método de pago
        const Text(
          'Método de pago',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF090D16),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[100]!),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.money, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Efectivo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pagarás al finalizar el trabajo',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.keyboard_arrow_down, color: Colors.grey[400]),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Fotos del trabajo
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text(
              'Fotos del trabajo ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF090D16),
              ),
            ),
            Text(
              '(opcional)',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _loading ? null : _pickImages,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppTheme.colorPrimary.withOpacity(0.3), style: BorderStyle.none),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Dash simulation wrapper
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.colorPrimary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.colorPrimary.withOpacity(0.3)),
                  ),
                  child: const Center(
                    child: Icon(Icons.camera_alt, color: AppTheme.colorPrimary, size: 28),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Agrega fotos para que los trabajadores entiendan mejor lo que necesitas.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Agregar fotos',
                        style: TextStyle(
                          color: AppTheme.colorPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_pendingImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pendingImages.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final image = _pendingImages[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        image.bytes,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: _loading ? null : () {
                          setState(() {
                            _pendingImages.removeAt(index);
                          });
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 32),
        
        // Botón Publicar
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.colorPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              else
                const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                _loading ? 'Publicando...' : 'Publicar solicitud',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildAmountField(String label, TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Row(
            children: [
              const Text('Bs ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nueva solicitud',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF090D16),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Cuéntanos qué necesitas',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: _scrollProgress < 0.1 ? 32 : 8,
                    height: _scrollProgress < 0.1 ? 6 : 8,
                    decoration: BoxDecoration(
                      color: AppTheme.colorPrimary,
                      borderRadius: BorderRadius.circular(_scrollProgress < 0.1 ? 3 : 4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 24,
                    height: 2,
                    color: _scrollProgress >= 0.1 ? AppTheme.colorPrimary.withOpacity(0.5) : Colors.grey[200],
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: _scrollProgress >= 0.1 && _scrollProgress < 0.8 ? 32 : 8,
                    height: _scrollProgress >= 0.1 && _scrollProgress < 0.8 ? 6 : 8,
                    decoration: BoxDecoration(
                      color: _scrollProgress >= 0.1 ? AppTheme.colorPrimary : Colors.grey[200],
                      borderRadius: BorderRadius.circular(_scrollProgress >= 0.1 && _scrollProgress < 0.8 ? 3 : 4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 24,
                    height: 2,
                    color: _scrollProgress >= 0.8 ? AppTheme.colorPrimary.withOpacity(0.5) : Colors.grey[200],
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: _scrollProgress >= 0.8 ? 32 : 8,
                    height: _scrollProgress >= 0.8 ? 6 : 8,
                    decoration: BoxDecoration(
                      color: _scrollProgress >= 0.8 ? AppTheme.colorPrimary : Colors.grey[200],
                      borderRadius: BorderRadius.circular(_scrollProgress >= 0.8 ? 3 : 4),
                    ),
                  ),
                ],
              ),
            ),
            
            // Body
            Expanded(child: _buildLocationState(context)),
          ],
        ),
      ),
    );
  }
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
            color: Colors.black.withOpacity(0.1),
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
                color: color.withOpacity(0.15),
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

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppTheme.colorPrimary.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? Colors.transparent : Colors.grey[300]!,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? AppTheme.colorPrimary : Colors.black87,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _PriceTypeOption extends StatelessWidget {
  const _PriceTypeOption({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.colorPrimary.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.colorPrimary : Colors.grey[200]!,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.colorPrimary : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? AppTheme.colorPrimary.withOpacity(0.6) : Colors.grey[500],
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
