import 'package:flutter/material.dart';
import '../../../../core/services/mobile_backend_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../history/presentation/screens/job_history_details_screen.dart';

/// Always reads the current server state; opening an old push never replaces the active job.
class RequestOutcomeScreen extends StatefulWidget {
  const RequestOutcomeScreen({required this.requestId, super.key});
  final String requestId;
  @override
  State<RequestOutcomeScreen> createState() => _RequestOutcomeScreenState();
}

class _RequestOutcomeScreenState extends State<RequestOutcomeScreen> {
  late Future<Map<String, dynamic>> _context = _load();
  Future<Map<String, dynamic>> _load() async {
    final result = await MobileBackendService.instance
        .notificationRequest(requestId: widget.requestId);
    final job = result['request'] as Map<String, dynamic>;
    // Compatibility with servers that returned only the original budget in notification context.
    final user = SessionStore.currentUser;
    if (user != null &&
        (user.type == 'client' ? job['worker'] : job['client']) == null) {
      final history = user.type == 'client'
          ? await MobileBackendService.instance
              .getClientHistory(clientUserId: user.id)
          : await MobileBackendService.instance
              .getWorkerHistory(workerUserId: user.id);
      for (final item in history['jobs'] as List? ?? []) {
        if (item is Map && item['requestId'] == widget.requestId) {
          return {
            'request': {...job, ...Map<String, dynamic>.from(item)}
          };
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _context,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Scaffold(
                appBar: AppBar(title: const Text('Resultado del trabajo')),
                body: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text(
                      'No pudimos cargar este trabajo. Revisa tu conexión.'),
                  TextButton(
                      onPressed: () => setState(() => _context = _load()),
                      child: const Text('Reintentar')),
                ])));
          if (!snapshot.hasData)
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          final job = snapshot.data!['request'] as Map<String, dynamic>;
          final isClient = SessionStore.currentUser?.type == 'client';
          return JobHistoryDetailsScreen(
            job: job,
            isClient: isClient,
            customRequestId: widget.requestId,
          );
        },
      );
}
