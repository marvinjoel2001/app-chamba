import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';
import 'request_status_screen.dart';

class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key});

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  String priceType = 'Precio fijo';
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController(text: '100');
  final _addressController = TextEditingController(
    text: 'Av. Arce, Edificio Multicine',
  );
  final ImagePicker _imagePicker = ImagePicker();
  final List<_PendingImage> _pendingImages = [];
  bool _loading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _budgetController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = SessionStore.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sesion expirada.')));
      return;
    }

    final description = _descriptionController.text.trim();
    final budget = double.tryParse(_budgetController.text.trim()) ?? 0;

    if (description.isEmpty || budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa descripcion y presupuesto valido.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await MobileBackendService.createRequest(
        clientUserId: user.id,
        title: 'Solicitud de ${priceType.toLowerCase()}',
        description: description,
        category: 'General',
        budget: budget,
        priceType: priceType,
        address: _addressController.text.trim(),
        latitude: -16.5002,
        longitude: -68.1342,
        photosBase64: _pendingImages.map((item) => item.dataUri).toList(),
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

  Future<void> _pickImages() async {
    if (_pendingImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximo 5 fotos por solicitud')),
      );
      return;
    }

    final selected = await _imagePicker.pickMultiImage(
      imageQuality: 82,
      maxWidth: 1440,
    );
    if (selected.isEmpty) {
      return;
    }

    final remaining = 5 - _pendingImages.length;
    final toProcess = selected.take(remaining);
    for (final item in toProcess) {
      final bytes = await item.readAsBytes();
      final dataUri =
          'data:${_resolveMimeType(item.path)};base64,${base64Encode(bytes)}';
      _pendingImages.add(_PendingImage(bytes: bytes, dataUri: dataUri));
    }

    if (!mounted) {
      return;
    }
    setState(() {});
  }

  String _resolveMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
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
                Expanded(
                  child: SingleChildScrollView(
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Describe que necesitas...',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _descriptionController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText:
                                  'Ej: Necesito un plomero para arreglar una fuga en la cocina...',
                              suffixIcon: IconButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Dictado por voz aun no implementado.',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.mic),
                              ),
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
                            decoration: const InputDecoration(
                              prefixText: 'Bs  ',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
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
                          TextField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Ubicacion',
                              hintText: 'Av. Arce, Edificio Multicine',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Fotos del trabajo (${_pendingImages.length}/5)',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _loading ? null : _pickImages,
                                icon: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                ),
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
                                separatorBuilder: (_, itemIndex) =>
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
                                                    _pendingImages.removeAt(
                                                      index,
                                                    );
                                                  });
                                                },
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              color: Colors.black87,
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
                          const SizedBox(height: 24),
                          ChambaPrimaryButton(
                            label: _loading
                                ? 'Publicando...'
                                : 'Publicar solicitud',
                            icon: Icons.send,
                            onPressed: _loading ? null : _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingImage {
  _PendingImage({required this.bytes, required this.dataUri});

  final Uint8List bytes;
  final String dataUri;
}
