import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Ícono y color de cada tipo de aviso. Compartido por el centro de
/// notificaciones y la sección "Actividad reciente" de Mensajes, para que un
/// mismo aviso se vea igual en ambos lugares.
class NotificationStyle {
  const NotificationStyle(this.icon, this.color);

  final IconData icon;
  final Color color;

  static const _violet = AppTheme.colorPrimary;
  static const _blue = Color(0xFF2563EB);
  static const _green = Color(0xFF16A34A);
  static const _amber = Color(0xFFD97706);
  static const _red = Color(0xFFE5484D);
  static const _teal = Color(0xFF0D9488);
  static const _pink = Color(0xFFDB2777);

  static NotificationStyle of(String type) => switch (type) {
        'offer_new' => const NotificationStyle(Icons.local_offer_rounded, _violet),
        'counter_offer' || 'offer_client_counter' =>
          const NotificationStyle(Icons.swap_horiz_rounded, _violet),
        'offer_accepted' =>
          const NotificationStyle(Icons.handshake_rounded, _green),
        'arrival_confirmed' =>
          const NotificationStyle(Icons.verified_rounded, _green),
        'offer_rejected' =>
          const NotificationStyle(Icons.do_not_disturb_on_rounded, _red),
        'request_new' =>
          const NotificationStyle(Icons.work_outline_rounded, _amber),
        'request_timeout' =>
          const NotificationStyle(Icons.timer_off_rounded, _red),
        'job_starting_soon' =>
          const NotificationStyle(Icons.event_available_rounded, _blue),
        'worker_arrived' =>
          const NotificationStyle(Icons.where_to_vote_rounded, _blue),
        'job_finished' =>
          const NotificationStyle(Icons.task_alt_rounded, _green),
        'job_cancelled' =>
          const NotificationStyle(Icons.event_busy_rounded, _red),
        'new_review' => const NotificationStyle(Icons.star_rounded, _amber),
        'dispute_created' =>
          const NotificationStyle(Icons.report_rounded, _amber),
        'dispute_resolved' =>
          const NotificationStyle(Icons.gavel_rounded, _teal),
        'verification_update' =>
          const NotificationStyle(Icons.badge_rounded, _violet),
        'payment_received' || 'payment' =>
          const NotificationStyle(Icons.payments_rounded, _green),
        'message_new' || 'chat_message' =>
          const NotificationStyle(Icons.chat_rounded, _blue),
        'support_message' =>
          const NotificationStyle(Icons.support_agent_rounded, _pink),
        _ => const NotificationStyle(Icons.notifications_rounded, _violet),
      };
}

/// Círculo tintado con el ícono del aviso y un punto si no está leído.
class NotificationIcon extends StatelessWidget {
  const NotificationIcon({
    required this.type,
    this.unread = false,
    this.size = 44,
    super.key,
  });

  final String type;
  final bool unread;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = NotificationStyle.of(type);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: style.color.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(size * 0.32),
          ),
          child: Icon(style.icon, color: style.color, size: size * 0.52),
        ),
        if (unread)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: AppTheme.colorPrimary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
