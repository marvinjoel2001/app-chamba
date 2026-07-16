import '../../../../core/errors/result.dart';
import '../entities/chat_message.dart';
import '../entities/chat_thread.dart';
import '../repositories/messages_repository.dart';

class GetThreadsUseCase {
  GetThreadsUseCase(this._repository);

  final MessagesRepository _repository;

  Future<Result<List<ChatThread>>> call({
    required String userId,
    ChatThreadType? type,
  }) {
    return _repository.getThreads(userId: userId, type: type);
  }
}

class GetThreadMessagesUseCase {
  GetThreadMessagesUseCase(this._repository);

  final MessagesRepository _repository;

  Future<Result<List<ChatMessage>>> call({required String threadId}) {
    return _repository.getThreadMessages(threadId: threadId);
  }
}

class SendMessageUseCase {
  SendMessageUseCase(this._repository);

  final MessagesRepository _repository;

  Future<Result<ChatMessage>> call({
    required String threadId,
    required String senderUserId,
    required String content,
  }) {
    return _repository.sendMessage(
      threadId: threadId,
      senderUserId: senderUserId,
      content: content,
    );
  }
}

class ArchiveThreadUseCase {
  ArchiveThreadUseCase(this._repository);

  final MessagesRepository _repository;

  Future<Result<void>> call({
    required String threadId,
    required String userId,
  }) {
    return _repository.archiveThread(threadId: threadId, userId: userId);
  }
}

class DeleteThreadUseCase {
  DeleteThreadUseCase(this._repository);

  final MessagesRepository _repository;

  Future<Result<void>> call({
    required String threadId,
    required String userId,
  }) {
    return _repository.deleteThread(threadId: threadId, userId: userId);
  }
}
