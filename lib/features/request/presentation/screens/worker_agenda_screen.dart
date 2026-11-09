import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/job_schedule_format.dart';
import '../widgets/request_extras_widgets.dart';

/// Agenda del trabajador: sus trabajos asignados agrupados por día. Puede
/// tener varios mientras no caigan el mismo día.
class WorkerAgendaScreen extends StatelessWidget {
  const WorkerAgendaScreen({
    required this.jobs,
    required this.onOpenJob,
    required this.onOpenChat,
    super.key,
  });

  /// Trabajos asignados (el de hoy y los programados).
  final List<Map<String, dynamic>> jobs;
  final void Function(String requestId) onOpenJob;
  final Future<void> Function(String requestId) onOpenChat;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    // Sin fecha (o con fecha pasada) = es el trabajo de hoy.
    DateTime dayOf(Map<String, dynamic> job) {
      final day = jobStartDay(job['startDate']?.toString());
      if (day == null || day.isBefore(todayKey)) return todayKey;
      return day;
    }

    final sorted = [...jobs]..sort((a, b) {
        final byDay = dayOf(a).compareTo(dayOf(b));
        if (byDay != 0) return byDay;
        return (jobStartTime(a['startDate']?.toString()) ?? '')
            .compareTo(jobStartTime(b['startDate']?.toString()) ?? '');
      });
    final groups = <DateTime, List<Map<String, dynamic>>>{};
    for (final job in sorted) {
      groups.putIfAbsent(dayOf(job), () => []).add(job);
    }

    return Scaffold(
      backgroundColor: AppTheme.colorBackground,
      appBar: AppBar(
        title: const Text('Mi agenda'),
        backgroundColor: AppTheme.colorBackground,
        surfaceTintColor: Colors.transparent,
      ),
      body: jobs.isEmpty
          ? const _EmptyAgenda()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                const _AgendaRule(),
                const SizedBox(height: 14),
                for (final entry in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Text(
                      _dayTitle(entry.key, todayKey),
                      style: const TextStyle(
                        color: AppTheme.colorMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final job in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AgendaJobCard(
                        job: job,
                        isToday: entry.key == todayKey,
                        onOpen: () => onOpenJob(job['id'].toString()),
                        onChat: () => onOpenChat(job['id'].toString()),
                      ),
                    ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
    );
  }

  static String _dayTitle(DateTime day, DateTime today) {
    final label = jobDayLabel(day, now: today);
    if (label == 'Hoy' || label == 'Mañana') {
      return '$label, ${day.day}/${day.month}';
    }
    return label[0].toUpperCase() + label.substring(1);
  }
}

class _AgendaRule extends StatelessWidget {
  const _AgendaRule();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.colorPrimaryTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppTheme.colorPrimary, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Puedes aceptar trabajos de otros días aunque ya tengas algo programado. Solo no se pueden dos trabajos el mismo día.',
              style: TextStyle(
                color: Color(0xFF4C1D95),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaJobCard extends StatelessWidget {
  const _AgendaJobCard({
    required this.job,
    required this.isToday,
    required this.onOpen,
    required this.onChat,
  });

  final Map<String, dynamic> job;
  final bool isToday;
  final VoidCallback onOpen;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final offer = job['workerOffer'] as Map<String, dynamic>?;
    final amount = (offer?['amount'] as num?)?.toDouble() ??
        (job['budget'] as num?)?.toDouble() ??
        0;
    final materials = (offer?['materialsAmount'] as num?)?.toDouble();
    final time = jobStartTime(job['startDate']?.toString());
    final days = (job['days'] as num?)?.toInt();
    final client = job['client'] as Map<String, dynamic>?;
    final accent = isToday ? AppTheme.colorSuccess : AppTheme.colorPrimary;
    final chips = requestTagChips(job);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.colorGlassBorder),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                job['title']?.toString() ??
                                    job['category']?.toString() ??
                                    'Trabajo',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.colorText,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isToday ? 'Hoy' : 'Programado',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (time != null) time,
                            if (days != null && days > 1) '$days días',
                            'Bs ${amount.toStringAsFixed(0)}',
                            if (materials != null && materials > 0)
                              'incluye Bs ${materials.toStringAsFixed(0)} de materiales',
                          ].join(' · '),
                          style: const TextStyle(
                              color: AppTheme.colorMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: AppTheme.colorMuted),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                job['address']?.toString() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppTheme.colorMuted, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                        if (chips.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 4, children: chips),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (client != null)
                              Expanded(
                                child: Text(
                                  'Cliente: ${client['name'] ?? client['firstName'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.colorText,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else
                              const Spacer(),
                            TextButton.icon(
                              onPressed: onChat,
                              icon: const Icon(Icons.chat_bubble_outline,
                                  size: 16),
                              label: const Text('Chat'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.colorPrimary,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                      ],
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

class _EmptyAgenda extends StatelessWidget {
  const _EmptyAgenda();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_outlined,
                size: 56, color: AppTheme.colorMuted),
            SizedBox(height: 12),
            Text(
              'Tu agenda está libre',
              style: TextStyle(
                color: AppTheme.colorText,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Cuando un cliente te elija para otro día, el trabajo aparece aquí y puedes seguir aceptando trabajos para hoy.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.colorMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
