import 'package:flutter/material.dart';
import '../domain/models/app_notification.dart';
import 'notification_style.dart';

enum NotificationCategory {
  all('Todas', Icons.notifications_rounded),
  jobs('Trabajos', Icons.work_outline_rounded),
  messages('Mensajes', Icons.chat_bubble_outline_rounded),
  system('Sistema', Icons.info_outline_rounded);

  const NotificationCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

class NotificationCardPresentation {
  const NotificationCardPresentation(this.background, this.color, this.asset);
  final Color background;
  final Color color;
  final String? asset;

  static NotificationCategory categoryOf(String type) => switch (type) {
        'message_new' ||
        'chat_message' ||
        'support_message' =>
          NotificationCategory.messages,
        'verification_update' ||
        'dispute_created' ||
        'dispute_resolved' =>
          NotificationCategory.system,
        'offer_new' ||
        'counter_offer' ||
        'offer_client_counter' ||
        'offer_accepted' ||
        'offer_rejected' ||
        'request_new' ||
        'request_timeout' ||
        'request_closed' ||
        'worker_arrived' ||
        'arrival_confirmed' ||
        'job_starting_soon' ||
        'job_finished' ||
        'job_cancelled' ||
        'new_review' ||
        'agency_offer_sent' ||
        'improve_offer_reminder' =>
          NotificationCategory.jobs,
        _ => NotificationCategory.system,
      };

  static NotificationCardPresentation of(String type) {
    if (type == 'request_new') {
      return const NotificationCardPresentation(
          Color(0xFFF1EBFF), Color(0xFF6D28D9), 'completed');
    }
    if (type == 'worker_arrived' ||
        type == 'arrival_confirmed' ||
        type == 'job_starting_soon') {
      return const NotificationCardPresentation(
          Color(0xFFF1EBFF), Color(0xFF6D28D9), 'location');
    }
    if (type == 'offer_new' ||
        type == 'counter_offer' ||
        type == 'offer_client_counter' ||
        type == 'payment' ||
        type == 'payment_received') {
      return const NotificationCardPresentation(
          Color(0xFFFFF5DC), Color(0xFF9A5700), 'coins');
    }
    if (type == 'job_finished') {
      return const NotificationCardPresentation(
          Color(0xFFE3F7EC), Color(0xFF087C50), 'completed');
    }
    if (type == 'offer_accepted') {
      return const NotificationCardPresentation(
          Color(0xFFE3F7EC), Color(0xFF087C50), 'coins');
    }
    if (categoryOf(type) == NotificationCategory.messages) {
      return const NotificationCardPresentation(
          Color(0xFFE6F1FF), Color(0xFF1260D6), 'messages');
    }
    final style = NotificationStyle.of(type);
    return NotificationCardPresentation(
        style.color.withValues(alpha: 0.08), style.color, null);
  }

  static bool isVisibleInCenter(String type) =>
      type != 'payment' && type != 'payment_received';

  static String actionLabel(AppNotification notification,
      {String role = 'client'}) {
    final data = notification.data;
    final hasRequest = ['requestId', 'jobId']
            .any((key) => data?[key]?.toString().trim().isNotEmpty ?? false) ||
        (data?['deep_link']?.toString().startsWith('/request/') ?? false);
    if (categoryOf(notification.type) == NotificationCategory.messages) {
      return notification.type == 'support_message'
          ? 'Ver soporte'
          : 'Ver mensaje';
    }
    if (notification.type == 'new_review' ||
        notification.type == 'verification_update') {
      return 'Ver perfil';
    }
    if (notification.type == 'dispute_created' ||
        notification.type == 'dispute_resolved') {
      return 'Ver soporte';
    }
    if (!hasRequest) return 'Ver detalle';
    return switch (notification.type) {
      'worker_arrived' => role == 'worker' ? 'Ver trabajo' : 'Ver mapa',
      'arrival_confirmed' => 'Ver trabajo',
      'request_new' => role == 'worker' ? 'Ver solicitud' : 'Ver trabajo',
      'offer_new' => role == 'worker' ? 'Ver solicitud' : 'Ver ofertas',
      'counter_offer' ||
      'offer_client_counter' =>
        role == 'worker' ? 'Ver propuesta' : 'Ver ofertas',
      'agency_offer_sent' => 'Ver oferta',
      'job_finished' ||
      'job_cancelled' ||
      'request_timeout' ||
      'request_closed' ||
      'offer_rejected' ||
      'payment' ||
      'payment_received' =>
        'Ver resumen',
      _ => 'Ver trabajo',
    };
  }
}
