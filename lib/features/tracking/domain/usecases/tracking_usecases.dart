import '../../../../core/errors/result.dart';
import '../entities/tracking_payload_entity.dart';
import '../repositories/tracking_repository.dart';

class GetTrackingUseCase {
  GetTrackingUseCase(this._repository);

  final TrackingRepository _repository;

  Future<Result<TrackingPayloadEntity>> call({required String requestId}) {
    return _repository.tracking(requestId: requestId);
  }
}

class ClientConfirmArrivalUseCase {
  ClientConfirmArrivalUseCase(this._repository);

  final TrackingRepository _repository;

  Future<Result<TrackingPayloadEntity>> call({
    required String requestId,
    required String clientUserId,
  }) {
    return _repository.clientConfirmArrival(
      requestId: requestId,
      clientUserId: clientUserId,
    );
  }
}

class CancelTrackingJobUseCase {
  CancelTrackingJobUseCase(this._repository);

  final TrackingRepository _repository;

  Future<Result<TrackingPayloadEntity>> call({
    required String requestId,
    required String userId,
  }) {
    return _repository.cancelJob(requestId: requestId, userId: userId);
  }
}

class GetTrackingMessagesUseCase {
  GetTrackingMessagesUseCase(this._repository);

  final TrackingRepository _repository;

  Future<Result<TrackingPayloadEntity>> call({required String userId}) {
    return _repository.messages(userId: userId);
  }
}
