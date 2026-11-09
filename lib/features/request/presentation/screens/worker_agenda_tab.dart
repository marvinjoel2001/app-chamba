import 'package:flutter/material.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../messages/presentation/screens/chat_screen.dart';
import '../../../messages/presentation/state/messages_dependencies.dart';
import '../state/request_dependencies.dart';
import 'job_in_progress_screen.dart';
import 'worker_agenda_screen.dart';

/// Pestaña "Agenda" del trabajador: el trabajo de hoy y los programados.
/// Carga sus propios datos y los refresca cada vez que se abre la pestaña.
class WorkerAgendaTab extends StatefulWidget {
  const WorkerAgendaTab({this.isActive = true, super.key});

  final bool isActive;

  @override
  State<WorkerAgendaTab> createState() => _WorkerAgendaTabState();
}

class _WorkerAgendaTabState extends State<WorkerAgendaTab> {
  List<Map<String, dynamic>> _jobs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WorkerAgendaTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    final user = SessionStore.currentUser;
    if (user == null) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response =
          (await RequestDependencies.getIncomingRequest(workerUserId: user.id))
              .fold(
                onSuccess: (value) => value,
                onFailure: (failure) => throw Exception(failure.message),
              )
              .payload;
      final jobs = <Map<String, dynamic>>[];
      for (final raw in response['requests'] as List<dynamic>? ?? const []) {
        if (raw is! Map) continue;
        final job = Map<String, dynamic>.from(raw);
        final status = job['status']?.toString();
        if (status == 'completed' || status == 'cancelled') continue;
        // Igual que en Inicio: el asignado de hoy y los programados.
        final accepted = (job['workerOffer'] as Map?)?['status'] == 'accepted';
        if (accepted || job['isScheduled'] == true) jobs.add(job);
      }
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  // Al volver del trabajo se recarga: pudo cancelarse o terminarse mientras
  // estaba abierto.
  Future<void> _openJob(String requestId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JobInProgressScreen(requestId: requestId),
      ),
    );
    if (mounted) await _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: AppTheme.colorBackground,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _jobs.isEmpty) {
      return ColoredBox(
        color: AppTheme.colorBackground,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No se pudo cargar tu agenda. $_error',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: AppTheme.colorMuted, fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _load,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return WorkerAgendaScreen(
      jobs: _jobs,
      onOpenJob: _openJob,
      onOpenChat: (requestId) => openJobChat(context, requestId),
      onRefresh: () => _load(silent: true),
    );
  }
}

/// Abre el chat del trabajo, si ya está habilitado (oferta aceptada).
Future<void> openJobChat(BuildContext context, String requestId) async {
  final user = SessionStore.currentUser;
  if (user == null) return;
  final result = await MessagesDependencies.getActiveThreads(userId: user.id);
  if (!context.mounted) return;
  result.fold(
      onSuccess: (threads) {
        final matches = threads
            .where((thread) => thread.jobId == requestId && thread.canSend);
        if (matches.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('El chat se habilita al aceptar una oferta.')));
          return;
        }
        final thread = matches.first;
        Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ChatScreen(
                  threadId: thread.id,
                  jobId: thread.jobId,
                  jobTitle: thread.jobTitle,
                  counterpartName: thread.counterpartName,
                )));
      },
      onFailure: (failure) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message))));
}
