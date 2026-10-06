import 'package:flutter/material.dart';
import '../../../../core/services/mobile_backend_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../history/presentation/screens/job_history_details_screen.dart';
import '../../../review/presentation/screens/rating_screen.dart';

/// Always reads the current server state; opening an old push never replaces the active job.
class RequestOutcomeScreen extends StatefulWidget {
  const RequestOutcomeScreen({required this.requestId, super.key});
  final String requestId;
  @override
  State<RequestOutcomeScreen> createState() => _RequestOutcomeScreenState();
}

class _RequestOutcomeScreenState extends State<RequestOutcomeScreen> {
  late final Future<Map<String, dynamic>> _context = MobileBackendService.instance.notificationRequest(requestId: widget.requestId);
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _context,
    builder: (context, snapshot) {
      if (snapshot.hasError) return Scaffold(appBar: AppBar(title: const Text('Resultado del trabajo')),
        body: const Center(child: Text('No pudimos cargar este trabajo. Revisa tu conexión.')));
      if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final job = snapshot.data!['request'] as Map<String, dynamic>;
      final isClient = SessionStore.currentUser?.type == 'client';
      return Stack(children: [
        JobHistoryDetailsScreen(job: job, isClient: isClient),
        if (isClient && job['requestStatus'] == 'completed') Positioned(bottom: 24, left: 24, right: 24,
          child: SafeArea(child: FilledButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => RatingScreen(requestId: widget.requestId))), child: const Text('Calificar trabajo')))),
      ]);
    },
  );
}
