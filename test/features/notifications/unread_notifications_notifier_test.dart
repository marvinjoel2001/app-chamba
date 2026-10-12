import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/session/session_store.dart';
import 'package:mobile/core/session/unread_notifications_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const user = SessionUser(
      id: 'client', type: 'client', firstName: 'Ana', email: 'ana@test.com');
  late SessionUser? previousUser;
  setUp(() {
    previousUser = SessionStore.currentUser;
    SessionStore.currentUser = user;
  });
  tearDown(() => SessionStore.currentUser = previousUser);

  test(
      'a new event during an in-flight fetch refreshes without waiting for polling',
      () async {
    final staleResponse = Completer<int>();
    var calls = 0;
    final counter = UnreadNotificationsNotifier.forTesting(loadCount: () {
      calls++;
      return calls == 1 ? staleResponse.future : Future.value(1);
    });
    addTearDown(counter.dispose);

    final initial = counter.refresh();
    final socket = counter.refresh();
    final push = counter.refresh();
    staleResponse.complete(0);
    await Future.wait([initial, socket, push]);

    expect(calls, 2);
    expect(counter.value, 1);
  });

  test(
      'multiple transport updates use the server count instead of adding duplicates',
      () async {
    final counter =
        UnreadNotificationsNotifier.forTesting(loadCount: () async => 1);
    addTearDown(counter.dispose);
    await counter.refresh();
    await counter.refresh();
    expect(counter.value, 1);
  });

  test('reading a notice updates the badge to the new server count', () async {
    var count = 2;
    final counter =
        UnreadNotificationsNotifier.forTesting(loadCount: () async => count);
    addTearDown(counter.dispose);
    await counter.refresh();
    expect(counter.value, 2);
    count = 1;
    await counter.refresh();
    expect(counter.value, 1);
  });

  test('an outage preserves the last confirmed unread count', () async {
    var fail = false;
    final counter = UnreadNotificationsNotifier.forTesting(loadCount: () async {
      if (fail) throw Exception('Offline');
      return 3;
    });
    addTearDown(counter.dispose);
    await counter.refresh();
    fail = true;
    await counter.refresh();
    expect(counter.value, 3);
  });

  test('logout ignores an old in-flight response and clears the count',
      () async {
    final response = Completer<int>();
    final counter = UnreadNotificationsNotifier.forTesting(
        loadCount: () => response.future);
    addTearDown(counter.dispose);
    final pending = counter.refresh();
    SessionStore.currentUser = null;
    final logout = counter.refresh();
    response.complete(9);
    await Future.wait([pending, logout]);
    expect(counter.value, 0);
  });
}
