import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exceptions.dart';
import 'package:mobile/core/session/session_store.dart';
import 'package:mobile/features/account/domain/account_deletion.dart';
import 'package:mobile/features/account/presentation/account_settings_screen.dart';
import 'package:mobile/features/account/presentation/delete_account_screen.dart';

class _FakeApi extends AccountDeletionApi {
  _FakeApi({this.initial = const AccountDeletionStatus.none(), this.failWith});

  AccountDeletionStatus initial;
  final Exception? failWith;
  final requests = <String>[];
  int cancels = 0;

  @override
  Future<AccountDeletionStatus> status() async => initial;

  @override
  Future<AccountDeletionStatus> request(String email) async {
    requests.add(email);
    if (failWith != null) throw failWith!;
    return initial = AccountDeletionStatus(
        pending: true,
        scheduledFor: DateTime.now().add(const Duration(days: 30)));
  }

  @override
  Future<AccountDeletionStatus> cancel() async {
    cancels++;
    return initial = const AccountDeletionStatus.none();
  }
}

void main() {
  group('reglas', () {
    test('el correo coincide sin distinguir mayúsculas ni espacios', () {
      expect(deletionEmailMatches('  Ana@Mail.com ', 'ana@mail.com'), isTrue);
      expect(deletionEmailMatches('ana@mail.co', 'ana@mail.com'), isFalse);
      expect(deletionEmailMatches('', ''), isFalse);
    });

    test('el correo se muestra enmascarado como pista', () {
      expect(maskEmail('marvin@gmail.com'), 'm•••n@gmail.com');
      expect(maskEmail('al@x.com'), 'a•••@x.com');
    });

    test('estado desde el servidor y días restantes', () {
      final now = DateTime(2026, 10, 14, 12);
      final status = AccountDeletionStatus.fromJson({
        'pending': true,
        'scheduledFor': DateTime(2026, 11, 13, 12).toUtc().toIso8601String(),
      });
      expect(status.pending, isTrue);
      expect(status.daysLeft(now: now), 30);
      expect(
          AccountDeletionStatus.fromJson({'pending': false}).pending, isFalse);
    });
  });

  group('pantalla de eliminación', () {
    setUp(() => SessionStore.currentUser = const SessionUser(
        id: 'u1', type: 'worker', firstName: 'Jorge', email: 'jorge@mail.com'));
    tearDown(() => SessionStore.currentUser = null);

    Future<void> open(WidgetTester tester, _FakeApi api) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: DeleteAccountScreen(api: api)));
    }

    FilledButton submit(WidgetTester tester) => tester
        .widget<FilledButton>(find.byKey(const Key('delete-account-submit')));

    testWidgets(
        'advierte sobre la billetera y no permite eliminar sin el correo',
        (tester) async {
      final api = _FakeApi();
      await open(tester, api);
      expect(find.textContaining('billetera'), findsOneWidget);
      expect(find.textContaining('j•••e@mail.com'), findsOneWidget);
      expect(submit(tester).onPressed, isNull);

      await tester.enterText(
          find.byKey(const Key('delete-account-email')), 'otro@mail.com');
      await tester.pump();
      expect(submit(tester).onPressed, isNull);
      expect(api.requests, isEmpty);
    });

    testWidgets('con el correo correcto pide confirmación y programa a 30 días',
        (tester) async {
      final api = _FakeApi();
      await open(tester, api);
      await tester.enterText(
          find.byKey(const Key('delete-account-email')), 'JORGE@mail.com ');
      await tester.pump();
      expect(submit(tester).onPressed, isNotNull);

      await tester
          .ensureVisible(find.byKey(const Key('delete-account-submit')));
      await tester.tap(find.byKey(const Key('delete-account-submit')));
      await tester.pumpAndSettle();
      expect(find.text('¿Programar la eliminación?'), findsOneWidget);

      // Echarse atrás en el diálogo no envía nada.
      await tester.tap(find.text('No, conservar mi cuenta').last);
      await tester.pumpAndSettle();
      expect(api.requests, isEmpty);

      await tester.tap(find.byKey(const Key('delete-account-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, eliminar'));
      await tester.pumpAndSettle();
      expect(api.requests, ['JORGE@mail.com ']);
      expect(find.text('Eliminación programada'), findsOneWidget);
      expect(find.text('Cancelar eliminación'), findsOneWidget);
    });

    testWidgets('muestra el motivo del servidor (trabajo en curso)',
        (tester) async {
      final api = _FakeApi(
          failWith: const ApiException('Tienes un trabajo en curso.',
              statusCode: 400));
      await open(tester, api);
      await tester.enterText(
          find.byKey(const Key('delete-account-email')), 'jorge@mail.com');
      await tester.pump();
      await tester
          .ensureVisible(find.byKey(const Key('delete-account-submit')));
      await tester.tap(find.byKey(const Key('delete-account-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('Tienes un trabajo en curso.'), findsOneWidget);
      expect(find.text('Eliminación programada'), findsNothing);
    });
  });

  group('configuración de la cuenta', () {
    setUp(() => SessionStore.currentUser = const SessionUser(
        id: 'u1', type: 'client', firstName: 'Ana', email: 'ana@mail.com'));
    tearDown(() => SessionStore.currentUser = null);

    testWidgets('con eliminación pendiente muestra el aviso y permite cancelar',
        (tester) async {
      final api = _FakeApi(
          initial: AccountDeletionStatus(
              pending: true,
              scheduledFor: DateTime.now().add(const Duration(days: 12))));
      await tester
          .pumpWidget(MaterialApp(home: AccountSettingsScreen(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('Tu cuenta se eliminará en 12 días'), findsOneWidget);
      // Mientras está pendiente no se ofrece pedirla de nuevo.
      expect(find.byKey(const Key('open-delete-account')), findsNothing);

      await tester.tap(find.text('Cancelar eliminación'));
      await tester.pumpAndSettle();
      expect(api.cancels, 1);
      expect(find.text('Tu cuenta se eliminará en 12 días'), findsNothing);
      expect(find.byKey(const Key('open-delete-account')), findsOneWidget);
    });
  });
}
