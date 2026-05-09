import '../../../../core/errors/result.dart';
import '../entities/chat_message.dart';
import '../entities/chat_thread.dart';

abstract class MessagesRepository {
  Future<Result<List<ChatThread>>> getThreads({
    required String userId,
    ChatThreadType? type,
  });
  Future<Result<List<ChatMessage>>> getThreadMessages({
    required String threadId,
  });
  Future<Result<ChatMessage>> sendMessage({
    required String threadId,
    required String senderUserId,
    required String content,
  });
  Future<Result<void>> archiveThread({
    required String threadId,
    required String userId,
  });
}
