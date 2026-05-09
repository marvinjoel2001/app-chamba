import '../../../../core/services/mobile_backend_service.dart';
import '../../data/datasources/messages_remote_datasource.dart';
import '../../data/repositories/messages_repository_impl.dart';
import '../../domain/usecases/messages_usecases.dart';

class MessagesDependencies {
  MessagesDependencies._();

  static final _repository = MessagesRepositoryImpl(
    const MessagesRemoteDataSourceImpl(MobileBackendService.instance),
  );

  static final getActiveThreads = GetThreadsUseCase(_repository);
  static final getArchivedThreads = GetThreadsUseCase(_repository);
  static final getThreadMessages = GetThreadMessagesUseCase(_repository);
  static final sendMessage = SendMessageUseCase(_repository);
  static final archiveThread = ArchiveThreadUseCase(_repository);
}
