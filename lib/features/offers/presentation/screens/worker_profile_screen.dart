import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';

class WorkerProfileScreen extends StatefulWidget {
  const WorkerProfileScreen({this.workerId, super.key});

  final String? workerId;

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.workerId == null) {
      setState(() {
        _error = 'Worker no especificado';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await MobileBackendService.workerProfile(widget.workerId!);
      setState(() {
        _profile = response;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final worker = _profile?['worker'] as Map<String, dynamic>?;
    final skills = worker?['skills'] as List<dynamic>? ?? const [];
    final gallery = worker?['gallery'] as List<dynamic>? ?? const [];

    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const Spacer(),
                    IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                  ],
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(child: Text(_error!))
                          : SingleChildScrollView(
                              child: GlassCard(
                                child: Column(
                                  children: [
                                    Container(
                                      width: 74,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFCFD6E8),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    CircleAvatar(
                                      radius: 85,
                                      backgroundImage: worker?['profilePhotoUrl'] == null
                                          ? null
                                          : NetworkImage(worker!['profilePhotoUrl'] as String),
                                      child: worker?['profilePhotoUrl'] == null
                                          ? Text((worker?['firstName'] ?? 'W').toString().substring(0, 1))
                                          : null,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '${worker?['firstName'] ?? ''} ${worker?['lastName'] ?? ''}'.trim(),
                                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${worker?['averageRating'] ?? 0} - ${worker?['completedJobs'] ?? 0} trabajos',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            color: AppTheme.colorMuted,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 10,
                                      children: [
                                        for (final skill in skills)
                                          ChambaChip(label: skill.toString(), selected: true),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      worker?['bio']?.toString() ?? '',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 20),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Galeria de trabajos',
                                        style: Theme.of(context).textTheme.headlineSmall,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        for (final imageUrl in gallery.take(3)) ...[
                                          Expanded(child: _GalleryItem(url: imageUrl.toString())),
                                          const SizedBox(width: 8),
                                        ],
                                      ],
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

class _GalleryItem extends StatelessWidget {
  const _GalleryItem({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 1,
        child: Image.network(url, fit: BoxFit.cover),
      ),
    );
  }
}
