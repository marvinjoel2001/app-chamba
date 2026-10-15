import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_labels.dart';
import '../domain/account_deletion.dart';

/// Aviso visible mientras la cuenta tiene una eliminación programada, con la
/// fecha y la acción para cancelarla.
class PendingDeletionBanner extends StatelessWidget {
  const PendingDeletionBanner({
    required this.status,
    required this.onCancel,
    this.cancelling = false,
    super.key,
  });

  final AccountDeletionStatus status;
  final VoidCallback onCancel;
  final bool cancelling;

  @override
  Widget build(BuildContext context) {
    final date = status.scheduledFor;
    if (!status.pending || date == null) return const SizedBox.shrink();
    final days = status.daysLeft();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.colorErrorSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.colorError.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: AppTheme.colorError),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  days <= 1
                      ? 'Tu cuenta se elimina mañana'
                      : 'Tu cuenta se eliminará en $days días',
                  style: const TextStyle(
                    color: AppTheme.colorText,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'El ${longDateLabel(date)} se borrarán tus datos de forma definitiva. '
            'Hasta entonces puedes seguir usando Chamba y cancelar la eliminación.',
            style: const TextStyle(
              color: AppTheme.colorMuted,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: cancelling ? null : onCancel,
              icon: cancelling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restore_rounded),
              label: Text(cancelling ? 'Cancelando…' : 'Cancelar eliminación'),
            ),
          ),
        ],
      ),
    );
  }
}
