import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/notifications/domain/models/app_notification.dart';
import 'package:mobile/features/notifications/presentation/screens/notifications_screen.dart';

void main() => runApp(const NotificationDesignPreview());

class NotificationDesignPreview extends StatelessWidget {
  const NotificationDesignPreview({super.key});
  @override
  Widget build(BuildContext context) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    AppNotification notice(String id, String title, String body, String type,
            int hour, int minute, {Map<String, dynamic>? data}) =>
        AppNotification(
            id: id,
            title: title,
            body: body,
            type: type,
            isRead: true,
            createdAt: DateTime(
                yesterday.year, yesterday.month, yesterday.day, hour, minute),
            data: data);
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Builder(
            builder: (context) => NotificationsScreen(
                  previewItems: [
                    notice(
                        'arrival',
                        'Jorge ha llegado',
                        'El trabajador llegó a tu ubicación.',
                        'worker_arrived',
                        23,
                        6,
                        data: {'requestId': 'sample-work'}),
                    notice(
                        'offer',
                        'Jorge ofertó Bs 100',
                        'En tu solicitud: limpieza de tu hogar.',
                        'offer_new',
                        21,
                        18,
                        data: {'requestId': 'sample-offer'}),
                    notice(
                        'completed',
                        'Trabajo finalizado',
                        'Jorge completó el trabajo correctamente.',
                        'job_finished',
                        19,
                        40,
                        data: {'requestId': 'sample-completed'}),
                    notice('message', 'Nuevo mensaje',
                        'Jorge envió un nuevo mensaje.', 'message_new', 18, 22,
                        data: {'threadId': 'sample-chat'}),
                    notice(
                        'system',
                        'Verificación pendiente',
                        'Completa tu perfil para empezar a trabajar.',
                        'verification_update',
                        16,
                        0),
                  ],
                  onOpenNotification: (notification) {
                    showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                                title: Text(notification.title),
                                content: const Text(
                                    'Vista de diseño con datos de ejemplo. En la app, este botón abre el trabajo, el mensaje o el perfil correspondiente.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cerrar'))
                                ]));
                    return true;
                  },
                )));
  }
}
