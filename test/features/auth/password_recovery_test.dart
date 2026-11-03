import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_exceptions.dart';
import 'package:mobile/core/network/api_service.dart';
import 'package:mobile/features/auth/presentation/screens/forgot_password_screen.dart';

class _FakeRecoveryApi extends PasswordRecoveryApi {
  _FakeRecoveryApi({this.startError, this.completeError});

  final Object? startError;
  final Object? completeError;
  final startedWith = <String>[];
  final completedWith = <List<String>>[];

  @override
  Future<Map<String, dynamic>> start(String idToken) async {
    startedWith.add(idToken);
    if (startError != null) throw startError!;
    return {
      'resetToken': 'reset-1',
      'email': 'ana@gmail.com',
      'firstName': 'Ana',
      'hadPassword': true,
    };
  }

  @override
  Future<Map<String, dynamic>> complete(
      String resetToken, String newPassword) async {
    completedWith.add([resetToken, newPassword]);
    if (completeError != null) throw completeError!;
    return {
      'user': {'id': 'u1', 'type': 'client', 'firstName': 'Ana'},
      'token': 'session-token',
    };
  }
}

/// Monta un botón que abre la pantalla y guarda lo que devuelve al cerrarse.
Future<List<Object?>> _open(
  WidgetTester tester,
  PasswordRecoveryApi api, {
  Future<String?> Function()? idToken,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final results = <Object?>[];
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => results.add(
            await Navigator.of(context).push<Map<String, dynamic>>(
              MaterialPageRoute(
                builder: (_) => ForgotPasswordScreen(
                  api: api,
                  requestIdToken: idToken ?? () async => 'google-id-token',
                ),
              ),
            ),
          ),
          child: const Text('Olvidé'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Olvidé'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  group('Olvidé mi contraseña (Google)', () {
    testWidgets('valida con Google, pide la contraseña nueva y entra',
        (tester) async {
      final api = _FakeRecoveryApi();
      final results = await _open(tester, api);

      await tester.tap(find.byKey(const Key('forgot-google')));
      await tester.pumpAndSettle();
      expect(api.startedWith, ['google-id-token']);
      expect(find.text('Crea una contraseña nueva para ana@gmail.com.'),
          findsOneWidget);

      // Muy corta y que no coincide.
      await tester.enterText(find.byKey(const Key('forgot-password')), 'corta');
      await tester.enterText(find.byKey(const Key('forgot-confirm')), 'otra');
      await tester.tap(find.byKey(const Key('forgot-save')));
      await tester.pumpAndSettle();
      expect(find.text('Usa al menos 8 caracteres'), findsOneWidget);
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      expect(api.completedWith, isEmpty);

      await tester.enterText(
          find.byKey(const Key('forgot-password')), 'clave-nueva-1');
      await tester.enterText(
          find.byKey(const Key('forgot-confirm')), 'clave-nueva-1');
      await tester.tap(find.byKey(const Key('forgot-save')));
      await tester.pumpAndSettle();

      expect(api.completedWith, [
        ['reset-1', 'clave-nueva-1']
      ]);
      expect(results, hasLength(1));
      expect((results.single as Map)['token'], 'session-token');
    });

    testWidgets('si cierra el selector de Google no pasa nada',
        (tester) async {
      final api = _FakeRecoveryApi();
      final results = await _open(tester, api, idToken: () async => null);
      await tester.tap(find.byKey(const Key('forgot-google')));
      await tester.pumpAndSettle();
      expect(api.startedWith, isEmpty);
      expect(find.byKey(const Key('forgot-error')), findsNothing);
      expect(results, isEmpty);
    });

    testWidgets('sin cuenta con ese correo muestra el motivo del backend',
        (tester) async {
      final api = _FakeRecoveryApi(
        startError: const ApiException(
          'No hay una cuenta de Chamba con otra@gmail.com. Elige la cuenta de Google del correo con el que te registraste.',
          statusCode: 404,
        ),
      );
      await _open(tester, api);
      await tester.tap(find.byKey(const Key('forgot-google')));
      await tester.pumpAndSettle();
      expect(find.textContaining('No hay una cuenta de Chamba'), findsOneWidget);
      expect(find.byKey(const Key('forgot-password')), findsNothing);
    });

    testWidgets('si el permiso venció vuelve a pedir Google', (tester) async {
      final api = _FakeRecoveryApi(
        completeError: const ApiException(
          'La recuperación venció. Vuelve a empezar con Google.',
          statusCode: 401,
        ),
      );
      await _open(tester, api);
      await tester.tap(find.byKey(const Key('forgot-google')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('forgot-password')), 'clave-nueva-1');
      await tester.enterText(
          find.byKey(const Key('forgot-confirm')), 'clave-nueva-1');
      await tester.tap(find.byKey(const Key('forgot-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('forgot-google')), findsOneWidget);
      expect(find.textContaining('venció'), findsOneWidget);
    });
  });

  group('mensajes del backend', () {
    ApiService apiReturning(int status, String message) => ApiService(
          baseUrl: 'https://qa.invalid/api',
          client: MockClient((_) async =>
              http.Response(jsonEncode({'message': message}), status)),
        );

    Future<String> errorOf(ApiService api) async {
      try {
        await api.post('/auth/login', body: const {});
      } on ApiException catch (error) {
        return error.message;
      }
      fail('Se esperaba un error');
    }

    test('contraseña incorrecta conserva el aviso de intentos restantes',
        () async {
      expect(
        await errorOf(apiReturning(401,
            'Credenciales invalidas. Te quedan 2 intentos antes de que la cuenta se bloquee 15 minutos.')),
        'Correo/teléfono o contraseña incorrectos. Te quedan 2 intentos antes de que la cuenta se bloquee 15 minutos.',
      );
      expect(await errorOf(apiReturning(401, 'Credenciales invalidas')),
          'Correo/teléfono o contraseña incorrectos.');
    });

    test('cuenta bloqueada por intentos (429) muestra cuánto esperar',
        () async {
      const lock =
          'Demasiados intentos fallidos. Por seguridad la cuenta quedó bloqueada; intenta de nuevo en 15 minutos o usa "Olvidé mi contraseña".';
      expect(await errorOf(apiReturning(429, lock)), lock);
    });

    test('recuperación: motivos de Google y de cuenta no se pierden', () async {
      expect(
        await errorOf(apiReturning(
            403, 'Esta cuenta está vinculada a otra cuenta de Google.')),
        'Esta cuenta está vinculada a otra cuenta de Google.',
      );
      expect(
        await errorOf(apiReturning(403, 'Forbidden resource')),
        'No tienes permisos para realizar esta acción.',
      );
    });
  });
}
