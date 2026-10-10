import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/services/mobile_backend_service.dart';
import 'package:mobile/core/session/session_store.dart';
import 'package:mobile/features/support/presentation/screens/support_screen.dart';

class _Backend extends Fake implements MobileBackendService {
  final response = Completer<Map<String, dynamic>>();
  int sends = 0;

  @override
  Future<Map<String, dynamic>> getUserActiveDisputes(String userId) async =>
      {'disputes': []};
  @override
  Future<Map<String, dynamic>> getDisputeMessages({required String disputeId,
      String? readBy}) async => {'messages': []};
  @override
  Future<Map<String, dynamic>> sendDisputeMessage({required String disputeId,
      required String senderType, String? senderId, required String content}) {
    sends++;
    return response.future;
  }
}

void main() {
  setUp(() => SessionStore.currentUser = const SessionUser(id: 'qa',
      type: 'client', firstName: 'QA', email: 'qa@example.invalid'));
  tearDown(() => SessionStore.currentUser = null);

  Future<void> open(WidgetTester tester, _Backend backend) async {
    await tester.pumpWidget(MaterialApp(home: SupportScreen(
        disputeId: 'qa-dispute', backend: backend)));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Necesito ayuda');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
  }

  testWidgets('failed support message keeps its draft and prevents double send',
      (tester) async {
    final backend = _Backend();
    await open(tester, backend);
    expect(find.text('Necesito ayuda'), findsOneWidget);
    expect(backend.sends, 1);
    backend.response.completeError(Exception('Sin conexión'));
    await tester.pump();
    expect(find.text('Necesito ayuda'), findsOneWidget);
    expect(find.text('Sin conexión'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('successful send preserves a new draft typed while waiting',
      (tester) async {
    final backend = _Backend();
    await open(tester, backend);
    await tester.enterText(find.byType(TextField), 'Otro mensaje');
    backend.response.complete({});
    await tester.pump();
    expect(find.text('Otro mensaje'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('successful send clears only the sent draft', (tester) async {
    final backend = _Backend();
    await open(tester, backend);
    backend.response.complete({});
    await tester.pump();
    expect(find.text('Necesito ayuda'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
