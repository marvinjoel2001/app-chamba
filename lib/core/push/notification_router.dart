import 'package:flutter/material.dart';

import '../../app.dart';
import '../session/session_store.dart';
import '../../features/messages/presentation/screens/chat_screen.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/request/presentation/screens/incoming_request_screen.dart';
import '../../features/request/presentation/screens/job_in_progress_screen.dart';
import '../../features/request/presentation/screens/request_status_screen.dart';
import '../../features/support/presentation/screens/support_screen.dart';
import '../../features/tracking/presentation/screens/tracking_screen.dart';
import '../../features/worker/presentation/screens/profile_menu_screen.dart';

/// Router central para notificaciones (push y centro de notificaciones).
/// Decide la pantalla destino a partir del `type` y `deep_link` que envía
/// el backend en el `data` de cada notificación.
class NotificationRouter {
  const NotificationRouter._();

  /// Abre la pantalla que corresponde a la notificación.
  /// Devuelve `false` si no había datos suficientes para navegar.
  static bool openFromData(Map<String, dynamic> data) {
    final navigator = ChambaApp.navigatorKey.currentState;
    if (navigator == null) return false;

    final type = (data['type'] ?? '').toString();
    final deepLink = (data['deep_link'] ?? '').toString();
    final threadId = _firstNonEmpty([
      data['threadId']?.toString(),
      _pathParam(deepLink, '/chat/'),
    ]);
    final requestId = _firstNonEmpty([
      data['requestId']?.toString(),
      data['jobId']?.toString(),
      _pathParam(deepLink, '/request/'),
    ]);
    final isWorker = SessionStore.currentUser?.type == 'worker';

    Widget? destination;

    if (type == 'message_new' || deepLink.startsWith('/chat')) {
      destination = threadId == null
          ? const MessagesScreen()
          : ChatScreen(threadId: threadId);
    } else if (type == 'support_message' ||
        type == 'dispute_created' ||
        type == 'dispute_resolved' ||
        deepLink.startsWith('/support')) {
      destination = const SupportScreen();
    } else if (type == 'new_review' ||
        type == 'verification_update' ||
        deepLink.startsWith('/profile')) {
      destination = const ProfileMenuScreen();
    } else if (type == 'request_new') {
      // Nueva solicitud cerca: solo tiene sentido para el worker.
      destination = isWorker ? const IncomingRequestScreen() : null;
    } else if (type == 'offer_accepted' ||
        type == 'arrival_confirmed' ||
        type == 'job_starting_soon') {
      if (isWorker) {
        destination = requestId == null
            ? const IncomingRequestScreen()
            : JobInProgressScreen(requestId: requestId);
      } else {
        if (requestId != null) {
          SessionStore.activeRequestId = requestId;
        }
        destination = const TrackingScreen();
      }
    } else if (type == 'worker_arrived' || type == 'job_finished') {
      if (requestId != null) {
        SessionStore.activeRequestId = requestId;
      }
      destination = const TrackingScreen();
    } else if (type == 'offer_new' ||
        type == 'counter_offer' ||
        type == 'improve_offer_reminder' ||
        type == 'request_timeout' ||
        type == 'offer_rejected' ||
        type == 'request_closed' ||
        type == 'job_cancelled' ||
        deepLink.startsWith('/request')) {
      // Novedades de la negociación: el cliente ve el estado de su solicitud
      // con las ofertas; el worker vuelve a la lista de solicitudes cercanas.
      destination =
          isWorker ? const IncomingRequestScreen() : const RequestStatusScreen();
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => destination ?? const NotificationsScreen(),
      ),
    );
    return destination != null;
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  static String? _pathParam(String deepLink, String prefix) {
    if (!deepLink.startsWith(prefix)) return null;
    final rest = deepLink.substring(prefix.length);
    final slash = rest.indexOf('/');
    return slash == -1 ? rest : rest.substring(0, slash);
  }
}
