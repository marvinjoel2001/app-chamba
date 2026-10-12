import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/session/session_store.dart';
import 'package:mobile/features/worker/presentation/screens/worker_onboarding_banner.dart';

void main() {
  tearDown(() => SessionStore.currentUser = null);

  SessionUser worker(String status) => SessionUser(
      id: 'worker', type: 'worker', firstName: 'Juana', email: 'juana@example.test',
      verificationStatus: status, isAvailable: false,
      idPhotoUrl: status == 'pending' ? 'id-photo' : null,
      facePhotoUrl: status == 'pending' ? 'face-photo' : null);

  testWidgets('new worker sees pending steps and can continue exploring', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SessionStore.currentUser = worker('not_verified');
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: WorkerOnboardingBanner())));
    expect(find.text('Verificación pendiente'), findsOneWidget);
    await tester.tap(find.text('Ver pasos'));
    await tester.pumpAndSettle();
    expect(find.text('Tu cuenta ya está lista'), findsOneWidget);
    expect(find.text('Elige tus oficios'), findsOneWidget);
    expect(find.text('Completa tus modalidades y tarifas'), findsOneWidget);
    expect(find.text('Verifica tu identidad'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Seguir explorando'));
    await tester.pumpAndSettle();
    expect(find.text('Tu cuenta ya está lista'), findsNothing);
    expect(find.text('Verificación pendiente'), findsOneWidget);
  });

  testWidgets('submitted identity shows review instead of requiring a new upload', (tester) async {
    SessionStore.currentUser = worker('pending');
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: WorkerOnboardingBanner())));
    await tester.tap(find.text('Ver pasos'));
    await tester.pumpAndSettle();
    expect(find.text('Identidad en revisión'), findsOneWidget);
    expect(find.text('Verifica tu identidad'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('verified worker has no pending banner', (tester) async {
    SessionStore.currentUser = worker('verified');
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: WorkerOnboardingBanner())));
    expect(find.text('Verificación pendiente'), findsNothing);
    expect(find.text('Ver pasos'), findsNothing);
  });
}
