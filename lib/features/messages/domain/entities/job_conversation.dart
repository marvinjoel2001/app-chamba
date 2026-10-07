import 'chat_message.dart';
import 'chat_thread.dart';

class JobConversation {
  const JobConversation(
      {required this.thread, required this.messages, this.hasMore = false});

  final ChatThread thread;
  final List<ChatMessage> messages;
  final bool hasMore;
}
