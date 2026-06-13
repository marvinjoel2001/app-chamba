import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../../core/services/mobile_backend_service.dart';
import '../../../../core/session/session_store.dart';
import 'package:intl/intl.dart';
import 'job_history_details_screen.dart';

class JobHistoryScreen extends StatefulWidget {
  const JobHistoryScreen({super.key});

  @override
  State<JobHistoryScreen> createState() => _JobHistoryScreenState();
}

class _JobHistoryScreenState extends State<JobHistoryScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _jobs = [];

  bool get _isClient => SessionStore.currentUser?.type == 'client';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final user = SessionStore.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      setState(() {
        _isLoading = true;
        _error = null;
      });

      final result = _isClient
          ? await MobileBackendService.instance.getClientHistory(clientUserId: user.id)
          : await MobileBackendService.instance.getWorkerHistory(workerUserId: user.id);

      if (mounted) {
        setState(() {
          _jobs = result['jobs'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar el historial: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Trabajos'),
      ),
      body: ChambaBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppTheme.colorError),
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 16),
                        ChambaPrimaryButton(
                          label: 'Reintentar',
                          onPressed: _loadHistory,
                        ),
                      ],
                    ),
                  )
                : _jobs.isEmpty
                    ? Center(
                        child: Text(
                          'Aún no tienes historial de trabajos.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.colorMuted,
                              ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadHistory,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _jobs.length,
                          itemBuilder: (context, index) {
                            final job = _jobs[index];
                            return _buildJobCard(context, job);
                          },
                        ),
                      ),
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, Map<String, dynamic> job) {
    final photoUrl = job['photoUrl'] as String?;
    final title = job['title'] as String? ?? 'Trabajo';
    final requestStatus = job['requestStatus'] as String? ?? '';
    final amount = job['amount'] != null ? NumberFormat.currency(symbol: '\$').format(job['amount']) : 'N/A';
    
    // Parse date
    final rawDate = _isClient ? job['createdAt'] : job['acceptedAt'];
    String formattedDate = '';
    if (rawDate != null) {
      try {
        final date = DateTime.parse(rawDate).toLocal();
        formattedDate = DateFormat('dd/MM/yyyy • HH:mm').format(date);
      } catch (_) {}
    }

    final isCompleted = requestStatus == 'completed';
    final isCancelled = requestStatus == 'cancelled';
    
    Color statusColor = AppTheme.colorPrimary;
    String statusText = 'Asignado';
    if (isCompleted) {
      statusColor = AppTheme.colorSuccess;
      statusText = 'Completado';
    } else if (isCancelled) {
      statusColor = AppTheme.colorError;
      statusText = 'Cancelado';
    }

    final otherUser = _isClient ? job['worker'] : job['client'];
    final otherName = otherUser != null ? '${otherUser['firstName']} ${otherUser['lastName']}'.trim() : 'Sin asignar';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => JobHistoryDetailsScreen(
                job: job,
                isClient: _isClient,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: GlassCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Foto
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 80,
                  height: 80,
                  color: AppTheme.colorPrimary.withOpacity(0.1),
                  child: photoUrl != null
                      ? Image.network(photoUrl, fit: BoxFit.cover)
                      : const Icon(Icons.work_outline, color: AppTheme.colorPrimary, size: 36),
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.colorMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isClient ? Icons.handyman : Icons.person,
                          size: 14,
                          color: AppTheme.colorMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            otherName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.colorMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                        Text(
                          amount,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.colorHighlight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
