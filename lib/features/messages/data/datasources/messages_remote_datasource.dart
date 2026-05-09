import '../../../../core/services/mobile_backend_service.dart';

abstract class MessagesRemoteDataSource {
  Future<Map<String, dynamic>> messages({required String userId});
  Future<Map<String, dynamic>> threadMessages({required String threadId});
  Future<Map<String, dynamic>> sendMessage({
    required String threadId,
    required String senderUserId,
    required String content,
  });
  Future<Map<String, dynamic>> archiveThread({
    required String threadId,
    required String userId,
  });
}

class MessagesRemoteDataSourceImpl implements MessagesRemoteDataSource {
  const MessagesRemoteDataSourceImpl(this._backendService);

  final MobileBackendService _backendService;

  @override
  Future<Map<String, dynamic>> messages({required String userId}) {
    return _backendService.messages(userId: userId);
  }

  @override
  Future<Map<String, dynamic>> threadMessages({required String threadId}) {
    return _backendService.threadMessages(threadId: threadId);
  }

  @override
  Future<Map<String, dynamic>> sendMessage({
    required String threadId,
    required String senderUserId,
    required String content,
  }) {
    return _backendService.sendMessage(
      threadId: threadId,
      senderUserId: senderUserId,
      content: content,
    );
  }

  @override
  Future<Map<String, dynamic>> archiveThread({
    required String threadId,
    required String userId,
  }) {
    return _backendService.archiveThread(threadId: threadId, userId: userId);
  }
}
