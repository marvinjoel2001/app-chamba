import '../../data/datasources/tracking_remote_datasource.dart';
import '../../data/repositories/tracking_repository_impl.dart';
import '../../domain/usecases/tracking_usecases.dart';

class TrackingDependencies {
  TrackingDependencies._();

  static final _repository = TrackingRepositoryImpl(
    const TrackingRemoteDataSourceImpl(),
  );

  static final getTracking = GetTrackingUseCase(_repository);
  static final clientConfirmArrival = ClientConfirmArrivalUseCase(_repository);
  static final cancelJob = CancelTrackingJobUseCase(_repository);
  static final getMessages = GetTrackingMessagesUseCase(_repository);
}
