import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/services/mobile_backend_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../data/repositories/worker_portfolio_repository.dart';
import '../../domain/entities/worker_portfolio_photo.dart';
import '../widgets/worker_portfolio_gallery.dart';

class WorkerPortfolioScreen extends StatefulWidget {
  const WorkerPortfolioScreen({this.repository, this.pickPhoto, super.key});

  final WorkerPortfolioRepository? repository;
  final Future<XFile?> Function(ImageSource source)? pickPhoto;

  @override
  State<WorkerPortfolioScreen> createState() => _WorkerPortfolioScreenState();
}

class _WorkerPortfolioScreenState extends State<WorkerPortfolioScreen> {
  late final WorkerPortfolioRepository _repository = widget.repository ??
      const WorkerPortfolioRepositoryImpl(MobileBackendService.instance);
  List<WorkerPortfolioPhoto> _photos = [];
  bool _loading = true;
  bool _busy = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final photos = await _repository.list();
      if (mounted) setState(() => _photos = photos);
    } catch (error) {
      if (mounted) setState(() => _error = mapToFailure(error).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add() async {
    if (_busy || _photos.length >= 20) return;
    setState(() => _busy = true);
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galer\u00eda'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('C\u00e1mara'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );
      if (source == null || !mounted) return;
      final file = widget.pickPhoto != null
          ? await widget.pickPhoto!(source)
          : await ImagePicker().pickImage(
              source: source,
              imageQuality: 85,
              maxWidth: 1920,
              maxHeight: 1920,
            );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 5 * 1024 * 1024) {
        _message('Selecciona una foto de hasta 5 MB');
        return;
      }
      final mime = _imageMime(bytes);
      final caption = await showDialog<String>(
        context: context,
        builder: (_) => _PhotoDraftDialog(bytes: bytes),
      );
      if (caption == null || !mounted) return;
      setState(() => _saving = true);
      final photo = await _repository.add(
        imageBase64: 'data:image/$mime;base64,${base64Encode(bytes)}',
        caption: caption,
      );
      if (!mounted) return;
      setState(() => _photos = [photo, ..._photos]);
      _message('Foto publicada');
    } catch (error) {
      _message(mapToFailure(error).message);
    } finally {
      if (mounted) setState(() {
        _busy = false;
        _saving = false;
      });
    }
  }

  Future<void> _delete(WorkerPortfolioPhoto photo) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text('Esta foto dejar\u00e1 de aparecer en tu perfil.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _saving = true;
    });
    try {
      await _repository.remove(photo.id);
      if (!mounted) return;
      setState(() =>
          _photos = _photos.where((item) => item.id != photo.id).toList());
      _message('Foto eliminada');
    } catch (error) {
      _message(mapToFailure(error).message);
    } finally {
      if (mounted) setState(() {
        _busy = false;
        _saving = false;
      });
    }
  }

  String _imageMime(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) return 'jpeg';
    if (bytes.length >= 8 && bytes[0] == 0x89 && ascii.decode(bytes.sublist(1, 4), allowInvalid: true) == 'PNG') return 'png';
    if (bytes.length >= 12 && ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' && ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') return 'webp';
    throw Exception('Selecciona una foto JPG, PNG o WebP');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Mis trabajos')),
        floatingActionButton: _loading || _error != null || _photos.length >= 20
            ? null
            : FloatingActionButton.extended(
                onPressed: _busy ? null : _add,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Agregar foto'),
              ),
        body: ChambaBackground(
          child: Column(
            children: [
              if (_saving) const LinearProgressIndicator(),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_error!, textAlign: TextAlign.center),
                                  TextButton.icon(
                                    onPressed: _load,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Reintentar'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 100),
                              children: [
                                Text(
                                  '${_photos.length} / 20 fotos',
                                  style: const TextStyle(
                                      color: AppTheme.colorMuted),
                                ),
                                const SizedBox(height: 16),
                                if (_photos.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 80),
                                    child: Column(
                                      children: [
                                        Icon(Icons.photo_library_outlined,
                                            size: 48,
                                            color: AppTheme.colorMuted),
                                        SizedBox(height: 12),
                                        Text('A\u00fan no tienes fotos publicadas'),
                                      ],
                                    ),
                                  )
                                else
                                  IgnorePointer(
                                    ignoring: _busy,
                                    child: WorkerPortfolioGallery(
                                        photos: _photos, onDelete: _delete),
                                  ),
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

class _PhotoDraftDialog extends StatefulWidget {
  const _PhotoDraftDialog({required this.bytes});
  final Uint8List bytes;

  @override
  State<_PhotoDraftDialog> createState() => _PhotoDraftDialogState();
}

class _PhotoDraftDialogState extends State<_PhotoDraftDialog> {
  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Publicar trabajo'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.memory(widget.bytes, fit: BoxFit.contain)),
              const SizedBox(height: 16),
              TextField(
                controller: _caption,
                maxLength: 200,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Descripci\u00f3n (opcional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _caption.text.trim()),
          icon: const Icon(Icons.publish_outlined),
          label: const Text('Publicar'),
        ),
      ],
    );
  }
}
