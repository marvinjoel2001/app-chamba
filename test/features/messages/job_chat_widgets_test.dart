import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/session/session_store.dart';
import 'package:mobile/core/session/session_credentials.dart';
import 'package:mobile/features/messages/domain/usecases/messages_usecases.dart';
import 'package:mobile/features/messages/presentation/screens/chat_screen.dart';
import 'package:mobile/features/messages/presentation/screens/messages_screen.dart';
import 'package:mobile/core/network/realtime_service.dart';
import '../../../tool/job_chat_preview.dart';

void main() {
  setUp(() {
    SessionCredentials.accessToken = null;
    SessionStore.currentUser = const SessionUser(
        id: 'preview-worker', type: 'worker', firstName: 'Diego', email: '');
  });
  tearDown(() {
    SessionStore.currentUser = null;
    RealtimeService.instance.disconnect();
  });
  Future<void> openChat(
      WidgetTester tester, PreviewMessagesRepository repo) async {
    await tester.pumpWidget(MaterialApp(
        home: ChatScreen(
            threadId: 'preview-thread',
            getThreadMessagesUseCase: GetThreadMessagesUseCase(repo),
            sendMessageUseCase: SendMessageUseCase(repo))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('notification entry stays visible without any accepted jobs',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(
        home: MessagesInbox(
            threads: const [],
            notifications: const [],
            unreadNotifications: 0,
            onRefresh: () async {},
            onNotifications: () => opened = true,
            onNotification: (_) {},
            onThread: (_) {})));
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Trabajos confirmados'), findsNothing);
    await tester.tap(find.text('Notificaciones'));
    expect(opened, isTrue);
  });
  testWidgets('contact alert blocks a send without reaching the repository',
      (tester) async {
    final repo = PreviewMessagesRepository();
    await openChat(tester, repo);
    await tester.enterText(find.byType(TextField), 'Mi WhatsApp es 72177549');
    await tester.pump();
    await tester.tap(find.byTooltip('Enviar mensaje'));
    await tester.pumpAndSettle();
    expect(find.text('Mantengamos tu trabajo protegido'), findsOneWidget);
    expect(repo.sends, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'quick reply fills a draft and does not send without confirmation',
      (tester) async {
    final repo = PreviewMessagesRepository();
    await openChat(tester, repo);
    await tester.tap(find.text('¿Dónde ingreso?'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '¿Dónde ingreso?');
    expect(repo.sends, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'job completion disables input and retains messages even after reopening',
      (tester) async {
    final repo = PreviewMessagesRepository(closed: true);
    await openChat(tester, repo);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Este trabajo terminó. Conservamos tu conversación.'),
        findsOneWidget);
    expect(find.text('Sí, esa es. Estoy en el segundo piso.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  for (final size in [
    const Size(320, 640),
    const Size(412, 892),
    const Size(768, 1024)
  ]) {
    testWidgets('inbox and chat fit ${size.width} logical pixels',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: MessagesInbox(
              threads: [previewThread()],
              notifications: previewNotifications(),
              unreadNotifications: 7,
              onRefresh: () async {},
              onNotifications: () {},
              onNotification: (_) {},
              onThread: (_) {})));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await openChat(tester, PreviewMessagesRepository());
      tester.view.viewInsets = FakeViewPadding(bottom: size.height * 0.45);
      await tester.pump();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpWidget(const SizedBox());
    });
  }
}
