import 'package:flutter/material.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../messages/presentation/screens/chat_screen.dart';
import '../../domain/entities/worker_job.dart';
import '../../domain/usecases/worker_usecases.dart';
import '../state/worker_dependencies.dart';

class WorkerHistoryScreen extends StatefulWidget {
  const WorkerHistoryScreen({this.getWorkerHistoryUseCase, super.key});

  final GetWorkerHistoryUseCase? getWorkerHistoryUseCase;

  @override
  State<WorkerHistoryScreen> createState() => _WorkerHistoryScreenState();
}

class _WorkerHistoryScreenState extends State<WorkerHistoryScreen> {
  GetWorkerHistoryUseCase get _getWorkerHistoryUseCase =>
      widget.getWorkerHistoryUseCase ?? WorkerDependencies.getWorkerHistory;

  bool _loading = true;
  bool _isOffline = false;
  bool _shouldRedirectToLogin = false;
  String? _error;
  List<WorkerJob> _jobs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '--';
    try {
      final dt = value.toLocal();
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
      return '--';
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
    final result = await _getWorkerHistoryUseCase(workerUserId: user.id);
    result.fold(
      onSuccess: (jobs) {
        if (!mounted) {
          return;
        }
        setState(() {
          _jobs = jobs;
          _isOffline = false;
          _shouldRedirectToLogin = false;
          _loading = false;
        });
      },
      onFailure: (failure) {
        if (!mounted) {
          return;
        }
        setState(() {
          _error = failure.message;
          _isOffline = failure is NetworkFailure;
          _shouldRedirectToLogin = failure is UnauthorizedFailure;
          _loading = false;
        });
      },
    );
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
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
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
              if (_isOffline)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Sin conexión. Intenta nuevamente.'),
                ),
              if (_shouldRedirectToLogin)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Sesión expirada. Inicia sesión nuevamente.'),
                ),
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Text(_error!)
              else if (_jobs.isEmpty)
                const Text('Aun no tienes trabajos en tu historial.')
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _jobs.length,
                  itemBuilder: (context, index) {
                    final job = _jobs[index];
                    return _HistoryItem(
                      job: job,
                      onOpenChat: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ChatScreen(
                              threadId: job.threadId!,
                              counterpartName: job.clientFullName,
                              counterpartAvatarUrl: job.clientProfilePhotoUrl,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.job, this.onOpenChat});

  final WorkerJob job;
  final VoidCallback? onOpenChat;

  String _formatDate(DateTime? value) {
    if (value == null) return '--';
    try {
      final dt = value.toLocal();
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
      return '--';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCancelled = job.isCancelled;
    final amount = job.amount;

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
                    job.title,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Bs ${amount.toStringAsFixed(0)}',
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
              '${job.category} · ${job.address}',
              style: const TextStyle(color: AppTheme.colorMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Cliente: ${job.clientFullName}',
              style: const TextStyle(color: AppTheme.colorMuted),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(job.acceptedAt),
              style: const TextStyle(
                color: AppTheme.colorMuted,
                fontSize: 12,
              ),
            ),
            if (job.threadId != null && !isCancelled) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpenChat,
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
  }
}
