import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/cloudinary_upload_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';
import 'request_status_screen.dart';

class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({
    required this.initialPrompt,
    this.initialTitle,
    this.suggestedCategories = const [],
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    super.key,
  });

  final String initialPrompt;
  final String? initialTitle;
  final List<Map<String, dynamic>> suggestedCategories;
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  String priceType = 'Precio fijo';
  late final TextEditingController _descriptionController;
  final _budgetController = TextEditingController(text: '100');
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

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.initialPrompt);
    _suggestedCategories = widget.suggestedCategories
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    _initializeLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _budgetController.dispose();
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
        permission = await Geolocator.requestPermission();
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
      _resolvedAddress = await _reverseGeocode(position.latitude, position.longitude);

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
      final first = features.isEmpty
          ? null
          : features.first as Map<String, dynamic>?;
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

  Future<void> _pickImages() async {
    if (_pendingImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximo 5 fotos por solicitud')),
      );
      return;
    }

    final selected = await _imagePicker.pickMultiImage(
      imageQuality: 70,
      maxWidth: 1080,
    );
    if (selected.isEmpty) {
      return;
    }

    final remaining = 5 - _pendingImages.length;
    final toProcess = selected.take(remaining);
    for (final item in toProcess) {
      final bytes = await item.readAsBytes();
      _pendingImages.add(_PendingImage(bytes: bytes, fileName: item.name));
    }

    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _submit() async {
    if (_locationBlockMessage != null || _latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Necesitamos tu ubicacion actual para continuar.'),
        ),
      );
      return;
    }

    final user = SessionStore.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesion expirada.')),
      );
      return;
    }

    final description = _descriptionController.text.trim();
    final budget = double.tryParse(_budgetController.text.trim()) ?? 0;

    if (description.isEmpty || budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa la descripcion y un presupuesto valido.'),
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

      final response = await MobileBackendService.createRequest(
        clientUserId: user.id,
        title:
            widget.initialTitle?.trim().isNotEmpty == true
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
      );

      final request = response['request'] as Map<String, dynamic>?;
      SessionStore.activeRequestId = request?['id'] as String?;

      if (!mounted) {
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const RequestStatusScreen()),
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
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_off,
                  size: 36,
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
                  onPressed: _initializeLocation,
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

    return SingleChildScrollView(
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Que necesitas?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: null,
              readOnly: true,
              enableInteractiveSelection: false,
              decoration: const InputDecoration(
                hintText: 'Tu solicitud se analizara desde la pantalla anterior.',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Categorias sugeridas por IA',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _suggestedCategories.isEmpty
                  ? const [ChambaChip(label: 'General', selected: true)]
                  : _suggestedCategories.asMap().entries.map((entry) {
                      final category = entry.value;
                      final label =
                          category['name']?.toString().trim().isNotEmpty == true
                          ? category['name'].toString().trim()
                          : 'General';
                      return ChambaChip(
                        label: label,
                        selected: entry.key == 0,
                      );
                    }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Ubicacion actual',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: AppTheme.glassContainerDecoration(radius: 18),
              child: Row(
                children: [
                  const Icon(Icons.my_location, color: AppTheme.colorHighlight),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _resolvedAddress ?? 'Ubicacion actual',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : _initializeLocation,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Precio propuesto',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(prefixText: 'Bs  '),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ['Precio fijo', 'Por hora', 'Por dia']
                  .map(
                    (option) => ChambaChip(
                      label: option,
                      selected: priceType == option,
                      onTap: () {
                        setState(() {
                          priceType = option;
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Fotos del trabajo (${_pendingImages.length}/5)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _loading ? null : _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            if (_pendingImages.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pendingImages.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 10),
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
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _loading
                                ? null
                                : () {
                                    setState(() {
                                      _pendingImages.removeAt(index);
                                    });
                                  },
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.colorBackgroundAlt.withValues(
                                  alpha: 0.92,
                                ),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.close,
                                color: AppTheme.colorText,
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
            const SizedBox(height: 24),
            ChambaPrimaryButton(
              label: _loading ? 'Publicando...' : 'Publicar solicitud',
              icon: Icons.send,
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Nueva solicitud',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildLocationState(context)),
              ],
            ),
          ),
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
