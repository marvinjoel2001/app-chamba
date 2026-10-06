import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/session/session_store.dart';

void main() {
  tearDown(() => SessionStore.clearActiveJob());
  test('closing an old notification leaves the current job and chat intact', () {
    SessionStore.activeRequestId = 'current-job';
    SessionStore.activeThreadId = 'current-chat';
    SessionStore.clearActiveJob(requestId: 'old-job');
    expect(SessionStore.activeRequestId, 'current-job');
    expect(SessionStore.activeThreadId, 'current-chat');
  });
  test('ending the current job clears its matching chat', () {
    SessionStore.activeRequestId = 'current-job';
    SessionStore.activeThreadId = 'current-chat';
    SessionStore.clearActiveJob(requestId: 'current-job');
    expect(SessionStore.activeRequestId, isNull);
    expect(SessionStore.activeThreadId, isNull);
  });
}
