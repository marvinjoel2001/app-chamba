// Standalone visual review: fixture data, no authentication or API writes.
// flutter run -t tool/job_chat_preview.dart
import 'package:flutter/material.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/core/session/session_store.dart';
import 'package:mobile/features/messages/data/models/chat_thread_model.dart';
import 'package:mobile/features/messages/domain/entities/chat_message.dart';
import 'package:mobile/features/messages/domain/entities/chat_thread.dart';
import 'package:mobile/features/messages/domain/entities/job_conversation.dart';
import 'package:mobile/features/messages/domain/repositories/messages_repository.dart';
import 'package:mobile/features/messages/domain/usecases/messages_usecases.dart';
import 'package:mobile/features/messages/presentation/screens/chat_screen.dart';
import 'package:mobile/features/messages/presentation/screens/messages_screen.dart';
import 'package:mobile/features/notifications/domain/models/app_notification.dart';

ChatThread previewThread({bool closed = false}) => ChatThreadModel.fromJson({
      'id': 'preview-thread',
      'requestId': 'preview-job',
      'chatEnabled': true,
      'request': {
        'id': 'preview-job',
        'title': 'Reparación de grifo',
        'category': 'Plomería',
        'status': closed ? 'completed' : 'assigned',
        'budget': 150,
        'workerId': 'preview-worker',
        'clientId': 'preview-client'
      },
      'counterpart': {'firstName': 'Lucía', 'lastName': 'Mendoza'},
      'lastMessage': 'Te espero en la entrada del edificio.',
      'unreadCount': 1,
    });

class PreviewMessagesRepository implements MessagesRepository {
  PreviewMessagesRepository({this.closed = false});
  bool closed;
  int sends = 0;
  List<ChatMessage> messages = [
    ChatMessage(
        id: '1',
        threadId: 'preview-thread',
        senderUserId: 'preview-client',
        content:
            'Hola, el grifo de la cocina sigue goteando. Te espero en la entrada del edificio.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 3))),
    ChatMessage(
        id: '2',
        threadId: 'preview-thread',
        senderUserId: 'preview-worker',
        content:
            'Perfecto, llevaré las herramientas. ¿Ingreso por la puerta azul?',
        createdAt: DateTime.now().subtract(const Duration(minutes: 2))),
    ChatMessage(
        id: '3',
        threadId: 'preview-thread',
        senderUserId: 'preview-client',
        content: 'Sí, esa es. Estoy en el segundo piso.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 1))),
  ];
  @override
  Future<Result<JobConversation>> getThreadMessages(
          {required String threadId, String? before}) async =>
      Success(JobConversation(
          thread: previewThread(closed: closed), messages: messages));
  @override
  Future<Result<List<ChatThread>>> getThreads(
          {required String userId, ChatThreadType? type}) async =>
      Success([previewThread(closed: closed)]);
  @override
  Future<Result<ChatMessage>> sendMessage(
      {required String threadId,
      required String senderUserId,
      required String content}) async {
    sends++;
    final message = ChatMessage(
        id: 'preview-$sends',
        threadId: threadId,
        senderUserId: senderUserId,
        content: content,
        createdAt: DateTime.now());
    messages = [...messages, message];
    return Success(message);
  }

  @override
  Future<Result<void>> archiveThread(
          {required String threadId, required String userId}) async =>
      const Success(null);
  @override
  Future<Result<void>> deleteThread(
          {required String threadId, required String userId}) async =>
      const Success(null);
}

List<AppNotification> previewNotifications() {
  const entries = [
    (
      'Nuevas ofertas en tu solicitud',
      '3 trabajadores enviaron propuestas para tu solicitud de Limpieza.',
      'offer_new'
    ),
    (
      'Solicitud aceptada',
      'Tu solicitud de Plomería fue aceptada. Revisa los detalles.',
      'offer_accepted'
    ),
    (
      'Recordatorio de trabajo',
      'Tu trabajo de Pintura está programado para mañana a las 9:00.',
      'job_starting_soon'
    ),
    (
      'Nueva actualización de Chamba',
      'Tu solicitud fue publicada y ya está disponible para recibir ofertas.',
      'platform'
    ),
    (
      'Nuevo trabajo cerca de ti',
      'Un cliente está buscando ayuda con su jardín.',
      'request_new'
    ),
    (
      'Estado de tu solicitud',
      'Tu solicitud de Albañilería fue cancelada.',
      'job_cancelled'
    ),
  ];
  return [
    for (var i = 0; i < entries.length; i++)
      AppNotification(
          id: '$i',
          title: entries[i].$1,
          body: entries[i].$2,
          type: entries[i].$3,
          isRead: i > 1,
          createdAt: DateTime.now().subtract(Duration(minutes: 5 + i * 30)))
  ];
}

void main() {
  SessionStore.currentUser = const SessionUser(
      id: 'preview-worker', type: 'worker', firstName: 'Diego', email: '');
  runApp(
      const MaterialApp(debugShowCheckedModeBanner: false, home: _Preview()));
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  int index = 0;
  Widget chat({bool closed = false}) {
    final repo = PreviewMessagesRepository(closed: closed);
    return ChatScreen(
        key: ValueKey(closed),
        threadId: 'preview-thread',
        getThreadMessagesUseCase: GetThreadMessagesUseCase(repo),
        sendMessageUseCase: SendMessageUseCase(repo));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: index == 0
            ? MessagesInbox(
                threads: const [],
                notifications: previewNotifications(),
                unreadNotifications: 7,
                onRefresh: () async {},
                onNotifications: () {},
                onNotification: (_) {},
                onThread: (_) {})
            : chat(closed: index == 2),
        bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.notifications_outlined), label: 'Bandeja'),
              NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline), label: 'Chat activo'),
              NavigationDestination(
                  icon: Icon(Icons.lock_outline), label: 'Finalizado')
            ]),
      );
}
