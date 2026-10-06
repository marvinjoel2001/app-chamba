import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/push/notification_presentation_policy.dart';

void main() {
  final now = DateTime.utc(2026, 10, 2, 12);
  late NotificationPresentationPolicy policy;
  setUp(() => policy = NotificationPresentationPolicy());
  NotificationDisposition evaluate(Map<String, dynamic> data, {bool visible = true, String? thread, String? user = 'user'}) =>
    policy.evaluate(data, userId: user, isVisible: visible, visibleThreadId: thread, now: now);

  test('a background socket cannot acknowledge presentation and suppress the push', () {
    expect(evaluate({'eventId': 'e'}, visible: false), NotificationDisposition.defer);
    expect(evaluate({'eventId': 'e'}), NotificationDisposition.alert);
  });
  test('socket plus FCM produces one visible alert for the same event', () {
    expect(evaluate({'eventId': 'same', 'type': 'offer_new'}), NotificationDisposition.alert);
    expect(evaluate({'eventId': 'same', 'type': 'offer_new'}), NotificationDisposition.silent);
  });
  test('messages in the visible chat are silent, another chat alerts', () {
    expect(evaluate({'eventId': 'a', 'type': 'message_new', 'threadId': 'one'}, thread: 'one'), NotificationDisposition.silent);
    expect(evaluate({'eventId': 'b', 'type': 'message_new', 'threadId': 'two'}, thread: 'one'), NotificationDisposition.alert);
  });
  test('expired job invitations never alert', () {
    expect(evaluate({'type': 'request_new', 'expiresAt': now.subtract(const Duration(seconds: 1)).toIso8601String()}), NotificationDisposition.silent);
  });
  test('support messages are silent only in the visible dispute', () {
    expect(policy.evaluate({'type': 'support_message', 'disputeId': 'open', 'eventId': 'support-one'},
      userId: 'user', isVisible: true, visibleDisputeId: 'open', now: now), NotificationDisposition.silent);
    expect(policy.evaluate({'type': 'support_message', 'disputeId': 'other', 'eventId': 'support-two'},
      userId: 'user', isVisible: true, visibleDisputeId: 'open', now: now), NotificationDisposition.alert);
  });
  test('signed-out users and messages addressed to another account are ignored', () {
    expect(evaluate({'eventId': 'e'}, user: null), NotificationDisposition.defer);
    expect(evaluate({'eventId': 'e', 'userId': 'other'}), NotificationDisposition.defer);
    expect(evaluate({'eventId': 'e', 'userId': 'user'}), NotificationDisposition.alert);
  });
  test('separate events on the same job still alert and logout clears old dedupe', () {
    expect(evaluate({'eventId': 'first', 'requestId': 'job'}), NotificationDisposition.alert);
    expect(evaluate({'eventId': 'second', 'requestId': 'job'}), NotificationDisposition.alert);
    policy.reset();
    expect(evaluate({'eventId': 'first', 'requestId': 'job'}), NotificationDisposition.alert);
  });
}
