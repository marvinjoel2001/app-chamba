import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/session/session_credentials.dart';
import 'package:mobile/core/session/session_store.dart';
import 'package:mobile/core/session/verification_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const worker = SessionUser(
    id: 'worker',
    type: 'worker',
    firstName: 'Ana',
    email: 'ana@test.com',
    verificationStatus: 'pending',
    isAvailable: false,
  );
  Map<String, dynamic> result(String status) => {
        'user': {
          'id': 'worker',
          'verificationStatus': status,
          'idPhotoVerified': status == 'verified',
          'facePhotoVerified': status == 'verified',
        }
      };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SessionStore.currentUser = worker;
    SessionCredentials.accessToken = 'session';
  });
  tearDown(() {
    SessionStore.currentUser = null;
    SessionCredentials.accessToken = null;
  });

  test(
      'recovers a missed approval and persists it without changing availability',
      () async {
    final sync = VerificationSyncService(fetch: () async => result('verified'));
    final revision = SessionStore.userChanges.value;
    await sync.refresh();
    expect(SessionStore.currentUser!.needsWorkerVerification, isFalse);
    expect(SessionStore.currentUser!.isAvailable, isFalse);
    expect(SessionStore.currentUser!.idPhotoVerified, isTrue);
    expect(SessionStore.userChanges.value, greaterThan(revision));
    final saved =
        (await SharedPreferences.getInstance()).getString('session_user')!;
    expect(jsonDecode(saved)['verificationStatus'], 'verified');
  });

  test('startup, reconnect and profile refresh share one in-flight request',
      () async {
    final response = Completer<Map<String, dynamic>>();
    var calls = 0;
    final sync = VerificationSyncService(fetch: () {
      calls++;
      return response.future;
    });
    final first = sync.refresh();
    final second = sync.refresh();
    expect(calls, 1);
    response.complete(result('verified'));
    await Future.wait([first, second]);
  });

  test('a response after logout cannot restore the worker session', () async {
    final response = Completer<Map<String, dynamic>>();
    final sync = VerificationSyncService(fetch: () => response.future);
    final pending = sync.refresh();
    SessionStore.currentUser = null;
    SessionCredentials.accessToken = null;
    response.complete(result('verified'));
    await pending;
    expect(SessionStore.currentUser, isNull);
  });

  test('old HTTP state cannot overwrite a newer live approval', () async {
    final response = Completer<Map<String, dynamic>>();
    final sync = VerificationSyncService(fetch: () => response.future);
    final pending = sync.refresh();
    await SessionStore.setCurrentUser(
        worker.copyWith(verificationStatus: 'verified'));
    response.complete(result('pending'));
    await pending;
    expect(SessionStore.currentUser!.verificationStatus, 'verified');
  });

  test('offline synchronization preserves the cached state and can retry',
      () async {
    var calls = 0;
    final sync = VerificationSyncService(fetch: () async {
      if (calls++ == 0) throw Exception('offline');
      return result('verified');
    });
    await sync.refreshQuietly();
    expect(SessionStore.currentUser!.verificationStatus, 'pending');
    await sync.refresh();
    expect(SessionStore.currentUser!.verificationStatus, 'verified');
  });

  test('ignores a response belonging to a previous login', () async {
    final response = Completer<Map<String, dynamic>>();
    final sync = VerificationSyncService(fetch: () => response.future);
    final pending = sync.refresh();
    SessionCredentials.accessToken = 'new-session';
    response.complete(result('verified'));
    await pending;
    expect(SessionStore.currentUser!.verificationStatus, 'pending');
  });

  test('rejects another account in a verification response', () async {
    final sync = VerificationSyncService(
        fetch: () async => {
              'user': {
                'id': 'another-worker',
                'verificationStatus': 'verified',
              }
            });
    await expectLater(sync.refresh(), throwsFormatException);
    expect(SessionStore.currentUser!.verificationStatus, 'pending');
  });
}
