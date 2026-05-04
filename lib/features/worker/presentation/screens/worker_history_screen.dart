import 'package:flutter/material.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../messages/presentation/screens/chat_screen.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';

class WorkerHistoryScreen extends StatefulWidget {
  const WorkerHistoryScreen({super.key});

  @override
  State<WorkerHistoryScreen> createState() => _WorkerHistoryScreenState();
}

class _WorkerHistoryScreenState extends State<WorkerHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _jobs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '--';
    try {
      final dt = DateTime.parse(value).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final jobDay = DateTime(dt.year, dt.month, dt.day);
      final diff = today.difference(jobDay).inDays;
      final timeStr =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (diff == 0) return 'Hoy, $timeStr';
      if (diff == 1) return 'Ayer, $timeStr';
      return '${dt.day}/${dt.month}/${dt.year}, $timeStr';
    } catch (_) {
      final normalized = value.replaceFirst('T', ' ');
      return normalized.length > 16 ? normalized.substring(0, 16) : normalized;
    }
  }

  Future<void> _load() async {
    final user = SessionStore.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Sesion expirada';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await MobileBackendService.workerHistory(
        workerUserId: user.id,
      );
      setState(() {
        _jobs = (response['jobs'] as List<dynamic>? ?? const []);
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
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Historial',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                ],
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Text(_error!)
              else if (_jobs.isEmpty)
                const Text('Aun no tienes trabajos en tu historial.')
              else
                ..._jobs.map((item) {
                  final job = item as Map<String, dynamic>;
                  final client = job['client'] as Map<String, dynamic>? ?? {};
                  final title = job['title']?.toString() ?? 'Trabajo';
                  final clientName =
                      '${client['firstName'] ?? ''} ${client['lastName'] ?? ''}'
                          .trim();
                  final requestStatus = job['requestStatus']?.toString() ?? '';
                  final isCancelled = requestStatus == 'cancelled';
                  final amount = job['amount'] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Monto — rojo si cancelado, morado si completado
                              Text(
                                'Bs $amount',
                                style: TextStyle(
                                  color: isCancelled
                                      ? AppTheme.colorError
                                      : AppTheme.colorPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Badge de estado
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isCancelled
                                  ? AppTheme.colorError.withValues(alpha: 0.15)
                                  : AppTheme.colorSuccess.withValues(
                                      alpha: 0.12,
                                    ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCancelled
                                    ? AppTheme.colorError.withValues(alpha: 0.4)
                                    : AppTheme.colorSuccess.withValues(
                                        alpha: 0.4,
                                      ),
                              ),
                            ),
                            child: Text(
                              isCancelled ? 'Trabajo cancelado' : 'Completado',
                              style: TextStyle(
                                color: isCancelled
                                    ? AppTheme.colorError
                                    : AppTheme.colorSuccess,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${job['category'] ?? 'General'} · ${job['address'] ?? ''}',
                            style: const TextStyle(color: AppTheme.colorMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cliente: ${clientName.isEmpty ? 'Cliente' : clientName}',
                            style: const TextStyle(color: AppTheme.colorMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(job['acceptedAt']?.toString()),
                            style: const TextStyle(
                              color: AppTheme.colorMuted,
                              fontSize: 12,
                            ),
                          ),
                          if (job['threadId'] != null && !isCancelled) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ChatScreen(
                                        threadId: job['threadId'] as String,
                                        title: clientName.isEmpty
                                            ? 'Cliente'
                                            : clientName,
                                        avatarUrl:
                                            client['profilePhotoUrl']
                                                as String?,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 16,
                                ),
                                label: const Text('Ver chat'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
