import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app.dart';
import 'package:mobile/core/session/session_store.dart';
import 'package:mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_exceptions.dart';
import 'package:mobile/core/network/api_service.dart';
import 'package:mobile/core/session/session_credentials.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => SessionCredentials.accessToken = null);

  test('protected 401 expires the session once across simultaneous calls',
      () async {
    SessionCredentials.accessToken = 'expired';
    final before = SessionCredentials.sessionExpirations.value;
    final api = ApiService(
        baseUrl: 'https://qa.invalid/api',
        client: MockClient((_) async => http.Response('{}', 401)));
    await Future.wait([
      expectLater(api.get('/mobile/messages'), throwsA(isA<ApiException>())),
      expectLater(
          api.get('/mobile/notifications'), throwsA(isA<ApiException>())),
    ]);
    expect(SessionCredentials.accessToken, isNull);
    expect(SessionCredentials.sessionExpirations.value, before + 1);
  });

  test('invalid login does not expire an existing session', () async {
    SessionCredentials.accessToken = 'valid';
    final api = ApiService(
        baseUrl: 'https://qa.invalid/api',
        client: MockClient((_) async => http.Response('{}', 401)));
    await expectLater(api.post('/auth/login'), throwsA(isA<ApiException>()));
    expect(SessionCredentials.accessToken, 'valid');
  });

  test('late 401 from an old account cannot log out the new account', () async {
    SessionCredentials.accessToken = 'old';
    final response = Completer<http.Response>();
    final api = ApiService(
        baseUrl: 'https://qa.invalid/api',
        client: MockClient((_) => response.future));
    final pending =
        expectLater(api.get('/mobile/messages'), throwsA(isA<ApiException>()));
    SessionCredentials.accessToken = 'new';
    response.complete(http.Response('{}', 401));
    await pending;
    expect(SessionCredentials.accessToken, 'new');
  });

  testWidgets(
      'expiration clears stored account and replaces navigation with login',
      (tester) async {
    SessionStore.currentUser = const SessionUser(
        id: 'old',
        type: 'client',
        firstName: 'QA',
        email: 'qa@example.invalid');
    SessionCredentials.accessToken = 'expired';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_access_token', 'expired');
    await prefs.setString('session_user', '{"id":"old"}');
    await tester.pumpWidget(const ProviderScope(child: ChambaApp()));
    ChambaApp.navigatorKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Sesión antigua'))));
    await tester.pump();
    SessionCredentials.expireIfCurrent('expired');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(SessionStore.currentUser, isNull);
    expect(prefs.getString('session_access_token'), isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Sesión antigua'), findsNothing);
    expect(ChambaApp.navigatorKey.currentState!.canPop(), isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
