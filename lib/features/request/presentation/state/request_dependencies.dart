import '../../data/datasources/request_remote_datasource.dart';
import '../../data/repositories/request_repository_impl.dart';
import '../../domain/usecases/request_usecases.dart';

class RequestDependencies {
  RequestDependencies._();

  static final _repository = RequestRepositoryImpl(
    const RequestRemoteDataSourceImpl(),
  );

  static final createRequest = CreateRequestUseCase(_repository);
  static final getRequestStatus = GetRequestStatusUseCase(_repository);
  static final getIncomingRequest = GetIncomingRequestUseCase(_repository);
  static final updateWorkerLocation = UpdateRequestWorkerLocationUseCase(
    _repository,
  );
  static final setAvailability = SetRequestWorkerAvailabilityUseCase(
    _repository,
  );
  static final createCounterOffer = CreateCounterOfferUseCase(_repository);
  static final clientCounterOffer = ClientCounterOfferUseCase(_repository);
  static final declineOffer = DeclineOfferUseCase(_repository);
  static final reactivateOffer = ReactivateOfferUseCase(_repository);
  static final getTracking = GetRequestTrackingUseCase(_repository);
  static final workerMarkArrived = WorkerMarkArrivedUseCase(_repository);
  static final completeJob = CompleteJobUseCase(_repository);
  static final cancelJob = CancelJobUseCase(_repository);
  static final getMessages = GetRequestMessagesUseCase(_repository);
}
