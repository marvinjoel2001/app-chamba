import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/realtime_service.dart';
import 'package:mobile/core/session/session_credentials.dart';
import 'package:mobile/core/session/session_store.dart';
import 'package:mobile/features/messages/domain/entities/chat_thread.dart';
import 'package:mobile/features/messages/presentation/screens/messages_screen.dart';
import 'package:mobile/features/notifications/domain/models/app_notification.dart';

void main() {
  setUp(() {
    SessionCredentials.accessToken = null;
  });
  tearDown(() {
    SessionStore.currentUser = null;
    RealtimeService.instance.disconnect();
  });
  for (final role in ['client', 'worker']) {
    testWidgets(
        'shell notification entry uses visual filters and keeps conversations for $role',
        (tester) async {
      SessionStore.currentUser =
          SessionUser(id: 'qa', type: role, firstName: 'QA', email: '');
      final notice = AppNotification(
          id: 'new',
          title: 'Aviso nuevo',
          body: 'Contenido',
          type: 'announcement',
          isRead: false,
          createdAt: DateTime.now());
      const thread = ChatThread(
          id: 'chat',
          jobId: 'job',
          jobTitle: 'Trabajo activo',
          jobDescription: 'Puerta',
          jobStatus: ChatThreadStatus.active,
          agreedPrice: 100,
          counterpartName: 'QA',
          chatEnabled: true);
      await tester.pumpWidget(MaterialApp(
          home: MessagesScreen(
        loadThreads: () async => [thread],
        previewNotifications: [notice],
      )));
      await tester.pumpAndSettle();
      expect(find.text('Notificaciones'), findsOneWidget);
      for (final filter in ['Trabajos', 'Mensajes', 'Sistema']) {
        expect(find.widgetWithText(ChoiceChip, filter), findsOneWidget);
      }
      expect(find.text('Nuevas 1'), findsOneWidget);
      expect(find.text('Pagos'), findsNothing);
      expect(find.text('Trabajo activo'), findsOneWidget);
      // Opening the tab does not clear the unread notification.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Nuevas 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver detalle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevas 0'), findsOneWidget);
      expect(find.text('Leídas 1'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Leídas 1'));
      await tester.pumpAndSettle();
      expect(find.text('Aviso nuevo'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
