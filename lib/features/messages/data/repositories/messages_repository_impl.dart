import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_thread.dart';
import '../../domain/repositories/messages_repository.dart';
import '../datasources/messages_remote_datasource.dart';
import '../models/chat_message_model.dart';
import '../models/chat_thread_model.dart';

class MessagesRepositoryImpl implements MessagesRepository {
  MessagesRepositoryImpl(this._remote);

  final MessagesRemoteDataSource _remote;

  @override
  Future<Result<List<ChatThread>>> getThreads({
    required String userId,
    ChatThreadType? type,
  }) async {
    try {
      final response = await _remote.messages(userId: userId);
      final rawThreads = (response['threads'] as List<dynamic>? ?? const []);
      final threads = rawThreads
          .whereType<Map<String, dynamic>>()
          .map(ChatThreadModel.fromJson)
          .where((thread) => type == null || thread.type == type)
          .toList(growable: false);
      return Success(threads);
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }

  @override
  Future<Result<List<ChatMessage>>> getThreadMessages({
    required String threadId,
  }) async {
    try {
      final response = await _remote.threadMessages(threadId: threadId);
      final rawMessages = (response['messages'] as List<dynamic>? ?? const []);
      final messages = rawMessages
          .whereType<Map<String, dynamic>>()
          .map(ChatMessageModel.fromJson)
          .toList(growable: false);
      return Success(messages);
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }

  @override
  Future<Result<ChatMessage>> sendMessage({
    required String threadId,
    required String senderUserId,
    required String content,
  }) async {
    try {
      final response = await _remote.sendMessage(
        threadId: threadId,
        senderUserId: senderUserId,
        content: content,
      );
      final message = ChatMessageModel.fromJson(
        response['message'] as Map<String, dynamic>? ?? {},
      );
      return Success(message);
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }

  @override
  Future<Result<void>> archiveThread({
    required String threadId,
    required String userId,
  }) async {
    try {
      await _remote.archiveThread(threadId: threadId, userId: userId);
      return const Success(null);
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }

  @override
  Future<Result<void>> deleteThread({
    required String threadId,
    required String userId,
  }) async {
    try {
      await _remote.deleteThread(threadId: threadId, userId: userId);
      return const Success(null);
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }
}
