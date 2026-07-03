import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../state/offers_dependencies.dart';

/// Perfil público del trabajador que ve el cliente al revisar una oferta.
/// Muestra solo datos reales del backend, con estados vacíos claros cuando
/// el trabajador todavía no tiene historial.
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
      final response =
          (await OffersDependencies.getWorkerProfile(widget.workerId!))
              .fold(
                onSuccess: (value) => value,
                onFailure: (failure) => throw Exception(failure.message),
              )
              .payload;
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

  String _formatDate(String? raw) {
    final date = DateTime.tryParse(raw ?? '');
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final worker = _profile?['worker'] as Map<String, dynamic>?;
    final skills = worker?['skills'] as List<dynamic>? ?? const [];
    final gallery = worker?['gallery'] as List<dynamic>? ?? const [];
    final reviews = _profile?['reviews'] as List<dynamic>? ?? const [];
    final bio = worker?['bio']?.toString().trim() ?? '';
    final completedJobs = (worker?['completedJobs'] as num?)?.toInt() ?? 0;
    final averageRating = (worker?['averageRating'] as num?)?.toDouble() ?? 0;
    final isVerified = worker?['verificationStatus'] == 'verified';
    final hourlyRate = (worker?['hourlyRate'] as num?)?.toDouble();
    final dailyRate = (worker?['dailyRate'] as num?)?.toDouble();

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
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(child: Text(_error!))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: SingleChildScrollView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    GlassCard(
                                      child: Column(
                                        children: [
                                          CircleAvatar(
                                            radius: 56,
                                            backgroundImage:
                                                worker?['profilePhotoUrl'] ==
                                                        null
                                                    ? null
                                                    : NetworkImage(
                                                        worker!['profilePhotoUrl']
                                                            as String,
                                                      ),
                                            child:
                                                worker?['profilePhotoUrl'] ==
                                                        null
                                                    ? Text(
                                                        chambaInitial(
                                                          worker?['firstName'],
                                                          fallback: 'W',
                                                        ),
                                                        style: const TextStyle(
                                                          fontSize: 32,
                                                        ),
                                                      )
                                                    : null,
                                          ),
                                          const SizedBox(height: 14),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  '${worker?['firstName'] ?? ''} ${worker?['lastName'] ?? ''}'
                                                      .trim(),
                                                  textAlign: TextAlign.center,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headlineMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ),
                                              if (isVerified) ...[
                                                const SizedBox(width: 6),
                                                const Icon(
                                                  Icons.verified,
                                                  color: AppTheme.colorSuccess,
                                                  size: 22,
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          if (completedJobs > 0)
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.star_rounded,
                                                  color:
                                                      AppTheme.colorHighlight,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  averageRating
                                                      .toStringAsFixed(1),
                                                  style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Text(
                                                  '  ·  $completedJobs ${completedJobs == 1 ? 'trabajo completado' : 'trabajos completados'}',
                                                  style: const TextStyle(
                                                    color: AppTheme.colorMuted,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            )
                                          else
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    AppTheme.colorSurfaceSoft,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: const Text(
                                                'Aún no realizó trabajos en Chamba',
                                                style: TextStyle(
                                                  color: AppTheme.colorMuted,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          if (hourlyRate != null ||
                                              dailyRate != null) ...[
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              alignment: WrapAlignment.center,
                                              children: [
                                                if (hourlyRate != null)
                                                  _RateChip(
                                                    icon: Icons.schedule,
                                                    label:
                                                        'Bs ${hourlyRate.toStringAsFixed(0)} / hora',
                                                  ),
                                                if (dailyRate != null)
                                                  _RateChip(
                                                    icon: Icons
                                                        .calendar_today_outlined,
                                                    label:
                                                        'Bs ${dailyRate.toStringAsFixed(0)} / día',
                                                  ),
                                              ],
                                            ),
                                          ],
                                          if (bio.isNotEmpty) ...[
                                            const SizedBox(height: 14),
                                            Text(
                                              bio,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: AppTheme.colorMuted,
                                                fontSize: 14,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    GlassCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Especialidades',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 10),
                                          if (skills.isEmpty)
                                            const Text(
                                              'Sin especialidades registradas aún.',
                                              style: TextStyle(
                                                color: AppTheme.colorMuted,
                                                fontSize: 13,
                                              ),
                                            )
                                          else
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                for (final skill in skills)
                                                  ChambaChip(
                                                    label: skill.toString(),
                                                    selected: true,
                                                  ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (gallery.isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      GlassCard(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Galería de trabajos',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                for (final imageUrl
                                                    in gallery.take(3)) ...[
                                                  Expanded(
                                                    child: _GalleryItem(
                                                      url: imageUrl.toString(),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 14),
                                    GlassCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Opiniones de clientes',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 10),
                                          if (reviews.isEmpty)
                                            const Text(
                                              'Aún no tiene opiniones. Será uno de sus primeros clientes.',
                                              style: TextStyle(
                                                color: AppTheme.colorMuted,
                                                fontSize: 13,
                                              ),
                                            )
                                          else
                                            for (final review in reviews)
                                              _ReviewItem(
                                                review: review
                                                        is Map<String, dynamic>
                                                    ? review
                                                    : Map<String,
                                                            dynamic>.from(
                                                        review as Map),
                                                formatDate: _formatDate,
                                              ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
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

class _RateChip extends StatelessWidget {
  const _RateChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.colorSurfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.colorPrimary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.colorPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.review, required this.formatDate});

  final Map<String, dynamic> review;
  final String Function(String?) formatDate;

  @override
  Widget build(BuildContext context) {
    final stars = (review['stars'] as num?)?.toInt() ?? 0;
    final comment = review['comment']?.toString().trim() ?? '';
    final clientName = review['clientName']?.toString().trim() ?? '';
    final date = formatDate(review['createdAt']?.toString());

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Icon(
                  i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 16,
                  color: i < stars
                      ? AppTheme.colorHighlight
                      : AppTheme.colorMuted,
                ),
              const Spacer(),
              Text(
                date,
                style: const TextStyle(
                  color: AppTheme.colorMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              comment,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ],
          if (clientName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '— $clientName',
              style: const TextStyle(
                color: AppTheme.colorMuted,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
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
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppTheme.colorSurfaceSoft,
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppTheme.colorMuted,
            ),
          ),
        ),
      ),
    );
  }
}
