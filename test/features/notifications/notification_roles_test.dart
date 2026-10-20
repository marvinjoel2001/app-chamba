import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/push/notification_router.dart';
import 'package:mobile/features/notifications/presentation/notification_card_presentation.dart';
import 'package:mobile/features/notifications/domain/models/app_notification.dart';
import 'package:mobile/features/request/presentation/screens/incoming_request_screen.dart';
import 'package:mobile/features/request/presentation/screens/job_in_progress_screen.dart';
import 'package:mobile/features/request/presentation/screens/request_status_screen.dart';
import 'package:mobile/features/request/presentation/screens/request_outcome_screen.dart';
import 'package:mobile/features/review/presentation/screens/rating_screen.dart';
import 'package:mobile/features/tracking/presentation/screens/tracking_screen.dart';

void main() {
  AppNotification notification(String type, {bool hasRequest = true}) =>
      AppNotification(
          id: 'notice',
          title: 'Aviso',
          body: 'Detalle',
          type: type,
          isRead: false,
          createdAt: DateTime(2026, 10, 12),
          data: hasRequest ? {'requestId': 'real-job'} : null);
  test('client actions describe offers, arrival map and summary', () {
    expect(
        NotificationCardPresentation.actionLabel(notification('offer_new'),
            role: 'client'),
        'Ver ofertas');
    expect(
        NotificationCardPresentation.actionLabel(notification('worker_arrived'),
            role: 'client'),
        'Ver mapa');
    expect(
        NotificationCardPresentation.actionLabel(notification('job_finished'),
            role: 'client'),
        'Ver resumen');
  });
  test(
      'worker actions describe requests and client proposals rather than a client offer list',
      () {
    expect(
        NotificationCardPresentation.actionLabel(notification('request_new'),
            role: 'worker'),
        'Ver solicitud');
    expect(
        NotificationCardPresentation.actionLabel(notification('counter_offer'),
            role: 'worker'),
        'Ver propuesta');
    expect(
        NotificationCardPresentation.actionLabel(
            notification('agency_offer_sent'),
            role: 'worker'),
        'Ver oferta');
    expect(
        NotificationCardPresentation.actionLabel(notification('worker_arrived'),
            role: 'worker'),
        'Ver trabajo');
    expect(
        NotificationCardPresentation.actionLabel(notification('offer_accepted'),
            role: 'worker'),
        'Ver trabajo');
  });
  for (final role in ['client', 'worker']) {
    test('$role can open messages, support and verification with clear labels',
        () {
      expect(
          NotificationCardPresentation.actionLabel(notification('message_new'),
              role: role),
          'Ver mensaje');
      expect(
          NotificationCardPresentation.actionLabel(
              notification('support_message'),
              role: role),
          'Ver soporte');
      expect(
          NotificationCardPresentation.actionLabel(
              notification('verification_update'),
              role: role),
          'Ver perfil');
      expect(
          NotificationCardPresentation.actionLabel(
              notification('offer_new', hasRequest: false),
              role: role),
          'Ver detalle');
    });
    for (final status in ['assigned', 'in_progress']) {
      test('$role opens the correct active-work screen for $status', () {
        final destination = NotificationRouter.destinationForRequest(
            requestId: 'real-job',
            status: status,
            type: 'offer_accepted',
            isWorker: role == 'worker');
        expect(
            destination,
            role == 'worker'
                ? isA<JobInProgressScreen>()
                : isA<TrackingScreen>());
      });
    }
    for (final status in ['completed', 'cancelled', 'expired']) {
      test('$role opens $status notifications as a summary', () {
        expect(
            NotificationRouter.destinationForRequest(
                requestId: 'old-job',
                status: status,
                type: 'job_finished',
                isWorker: role == 'worker',
                reviewed: true),
            isA<RequestOutcomeScreen>());
      });
    }
    test('$role: job finished and not yet rated', () {
      expect(
          NotificationRouter.destinationForRequest(
              requestId: 'done-job',
              status: 'completed',
              type: 'job_finished',
              isWorker: role == 'worker'),
          role == 'worker' ? isA<RequestOutcomeScreen>() : isA<RatingScreen>());
    });
  }
  test(
      'new work opens incoming requests for worker and request status for client',
      () {
    expect(
        NotificationRouter.destinationForRequest(
            requestId: 'new-job',
            status: 'searching',
            type: 'request_new',
            isWorker: true),
        isA<IncomingRequestScreen>());
    expect(
        NotificationRouter.destinationForRequest(
            requestId: 'new-job',
            status: 'searching',
            type: 'offer_new',
            isWorker: false),
        isA<RequestStatusScreen>());
  });
}
