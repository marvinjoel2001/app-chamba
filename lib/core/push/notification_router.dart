import 'package:flutter/material.dart';

import '../../app.dart';
import '../services/toast_service.dart';
import '../session/session_store.dart';
import '../services/mobile_backend_service.dart';
import '../../features/request/presentation/screens/request_outcome_screen.dart';
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

  static const String _routePrefix = 'notif:';
  static const String _notificationsRouteName = '${_routePrefix}center';

  /// Abre la pantalla que corresponde a la notificación.
  ///
  /// [fromNotificationCenter]: true cuando el tap viene de la lista de
  /// `NotificationsScreen`. En ese caso, si la notificación no tiene destino
  /// NO se vuelve a abrir `NotificationsScreen` encima de sí misma (antes se
  /// apilaba una copia por cada tap).
  ///
  /// Devuelve `false` si no había datos suficientes para navegar.
  static bool openFromData(
    Map<String, dynamic> data, {
    bool fromNotificationCenter = false,
  }) {
    if (!SessionStore.isLoggedIn || (data['userId'] != null && data['userId'] != SessionStore.currentUser?.id)) return false;
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

    if (requestId != null && (deepLink.startsWith('/request') || [
      'request_new', 'offer_new', 'offer_accepted', 'counter_offer', 'offer_client_counter', 'arrival_confirmed',
      'worker_arrived', 'job_finished', 'job_cancelled', 'job_starting_soon', 'request_timeout',
      'offer_rejected', 'request_closed', 'agency_offer_sent', 'improve_offer_reminder'].contains(type))) {
      _openRequest(requestId, type);
      return true;
    }

    Widget? destination;
    String? routeKey;

    if (type == 'message_new' ||
        type == 'chat_message' ||
        deepLink.startsWith('/chat')) {
      destination = threadId == null
          ? const MessagesScreen()
          : ChatScreen(threadId: threadId);
      routeKey = 'chat:${threadId ?? 'list'}';
    } else if (type == 'support_message' ||
        type == 'dispute_created' ||
        type == 'dispute_resolved' ||
        deepLink.startsWith('/support')) {
      destination = SupportScreen(disputeId: data['disputeId']?.toString());
      routeKey = 'support';
    } else if (type == 'new_review' ||
        type == 'verification_update' ||
        deepLink.startsWith('/profile')) {
      destination = const ProfileMenuScreen();
      routeKey = 'profile';
    } else if (type == 'request_new') {
      // Nueva solicitud cerca: solo tiene sentido para el worker.
      if (isWorker) {
        destination = const IncomingRequestScreen();
        routeKey = 'incoming';
      }
    } else if (type == 'offer_accepted' ||
        type == 'arrival_confirmed' ||
        type == 'job_starting_soon' ||
        type == 'worker_arrived' ||
        type == 'job_finished') {
      if (requestId != null) {
        SessionStore.activeRequestId = requestId;
      }
      if (isWorker) {
        // El worker nunca debe caer en TrackingScreen (es la vista del
        // cliente); su pantalla del trabajo es JobInProgressScreen.
        destination = requestId == null
            ? const IncomingRequestScreen()
            : JobInProgressScreen(requestId: requestId);
        routeKey = requestId == null ? 'incoming' : 'job:$requestId';
      } else {
        // TrackingScreen consulta el estado real: si el trabajo ya está
        // `completed` redirige a calificar, si está `cancelled` vuelve al
        // inicio (cubre el cold start desde el push `job_finished`).
        destination = const TrackingScreen();
        routeKey = 'tracking:${requestId ?? ''}';
      }
    } else if (type == 'offer_new' ||
        type == 'counter_offer' ||
        type == 'offer_client_counter' ||
        type == 'improve_offer_reminder' ||
        type == 'request_timeout' ||
        type == 'offer_rejected' ||
        type == 'request_closed' ||
        deepLink.startsWith('/request')) {
      // Novedades de la negociación: el cliente ve el estado de su solicitud
      // con las ofertas; el worker vuelve a la lista de solicitudes cercanas.
      if (isWorker) {
        destination = const IncomingRequestScreen();
        routeKey = 'incoming';
      } else {
        if (requestId != null) {
          SessionStore.activeRequestId = requestId;
        }
        // RequestStatusScreen ahora detecta si la solicitud ya fue asignada,
        // completada o cancelada y redirige.
        destination = const RequestStatusScreen();
        routeKey = 'request:${requestId ?? ''}';
      }
    }

    if (destination == null) {
      if (fromNotificationCenter) {
        // Ya está en el centro de notificaciones: no apilar otra copia.
        return false;
      }
      _pushUnlessOnTop(
        navigator,
        const NotificationsScreen(),
        _notificationsRouteName,
      );
      return false;
    }

    _pushUnlessOnTop(navigator, destination, '$_routePrefix$routeKey');
    return true;
  }

  static Future<void> _openRequest(String requestId, String type) async {
    final userId = SessionStore.currentUser?.id;
    try {
      final response = await MobileBackendService.instance.notificationRequest(requestId: requestId);
      if (SessionStore.currentUser?.id != userId) return;
      final nav = ChambaApp.navigatorKey.currentState;
      if (nav == null) return;
      final job = response['request'] as Map<String, dynamic>;
      final status = job['requestStatus'];
      final worker = SessionStore.currentUser?.type == 'worker';
      final terminal = status == 'cancelled' || status == 'completed' || status == 'expired' || ['offer_rejected', 'request_closed', 'request_timeout'].contains(type);
      final Widget screen = terminal ? RequestOutcomeScreen(requestId: requestId)
        : status == 'assigned' ? (worker ? JobInProgressScreen(requestId: requestId) : TrackingScreen(requestId: requestId))
        : worker ? IncomingRequestScreen(focusRequestId: requestId) : RequestStatusScreen(requestId: requestId);
      _pushUnlessOnTop(nav, screen, 'notif:request:' + requestId + ':' + status.toString());
    } catch (_) {
      ToastService.show(title: 'No pudimos abrir la solicitud', body: 'Revisa tu conexión o consulta tus notificaciones.', type: ToastType.info);
    }
  }

  /// Evita apilar la misma pantalla varias veces cuando el usuario toca
  /// varias notificaciones seguidas del mismo tipo/trabajo.
  static void _pushUnlessOnTop(
    NavigatorState navigator,
    Widget screen,
    String routeName,
  ) {
    Route<dynamic>? top;
    // popUntil con un predicado que devuelve true NO saca ninguna ruta:
    // es la forma estándar de leer la ruta superior.
    navigator.popUntil((route) {
      top = route;
      return true;
    });
    if (top?.settings.name == routeName) {
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: routeName),
        builder: (_) => screen,
      ),
    );
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
