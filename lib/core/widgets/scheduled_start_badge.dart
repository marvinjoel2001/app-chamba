import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/job_schedule_format.dart';

/// Píldora sobre el mapa para un trabajo programado para otro día. Ocupa el
/// lugar de la llegada estimada, que no aplica hasta ese día. Morado, igual
/// que "Programado" en la Agenda.
class ScheduledStartBadge extends StatelessWidget {
  const ScheduledStartBadge({required this.startDate, super.key});

  final String? startDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.colorPrimaryTint,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppTheme.colorPrimary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.event_outlined,
            color: AppTheme.colorPrimary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatJobStart(startDate),
                style: const TextStyle(
                  color: AppTheme.colorText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'TRABAJO\nPROGRAMADO',
                style: TextStyle(
                  color: AppTheme.colorPrimary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Empieza mañana 08:00" / "Empieza sáb 15 · 08:00" para frases.
String scheduledStartSentence(String? startDate) {
  final label = formatJobStart(startDate);
  if (label.startsWith('Mañana') || label.startsWith('Hoy')) {
    return 'Empieza ${label[0].toLowerCase()}${label.substring(1)}';
  }
  return 'Empieza $label';
}
