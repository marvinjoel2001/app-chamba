import '../../../../core/errors/result.dart';
import '../entities/request_payload_entity.dart';
import '../repositories/request_repository.dart';

class CreateRequestUseCase {
  CreateRequestUseCase(this._repository);

  final RequestRepository _repository;

  Future<Result<RequestPayloadEntity>> call({
    required String clientUserId,
    required String title,
    required String description,
    String? category,
    List<Map<String, dynamic>>? aiCategories,
    required double budget,
    required String priceType,
    required String address,
    required double latitude,
    required double longitude,
    String? scheduledAt,
    List<String>? photosBase64,
    List<Map<String, String>>? photos,
    String? paymentMethod,
  }) {
    return _repository.createRequest(
      clientUserId: clientUserId,
      title: title,
      description: description,
      category: category,
      aiCategories: aiCategories,
      budget: budget,
      priceType: priceType,
      address: address,
      latitude: latitude,
      longitude: longitude,
      scheduledAt: scheduledAt,
      photosBase64: photosBase64,
      photos: photos,
      paymentMethod: paymentMethod,
    );
  }
}

class GetRequestStatusUseCase {
  GetRequestStatusUseCase(this._repository);

  final RequestRepository _repository;

  Future<Result<RequestPayloadEntity>> call({
    String? requestId,
    String? clientUserId,
  }) {
    return _repository.requestStatus(
      requestId: requestId,
      clientUserId: clientUserId,
    );
  }
}

class GetIncomingRequestUseCase {
  GetIncomingRequestUseCase(this._repository);

  final RequestRepository _repository;

  Future<Result<RequestPayloadEntity>> call({required String workerUserId}) {
    return _repository.incomingRequest(workerUserId: workerUserId);
  }
}

class UpdateRequestWorkerLocationUseCase {
  UpdateRequestWorkerLocationUseCase(this._repository);

  final RequestRepository _repository;

  Future<Result<RequestPayloadEntity>> call({
    required String workerUserId,
    required double latitude,
    required double longitude,
  }) {
    return _repository.updateWorkerLocation(
      workerUserId: workerUserId,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

class SetRequestWorkerAvailabilityUseCase {
  SetRequestWorkerAvailabilityUseCase(this._repository);

  final RequestRepository _repository;

  Future<Result<RequestPayloadEntity>> call({
    required String workerUserId,
    required bool available,
  }) {
    return _repository.setAvailability(
      workerUserId: workerUserId,
      available: available,
    );
  }
}

class CreateCounterOfferUseCase {
  CreateCounterOfferUseCase(this._repository);

  final RequestRepository _repository;

  Future<Result<RequestPayloadEntity>> call({
    required String requestId,
    required String workerUserId,
    required double amount,
    String? message,
  }) {
    return _repository.counterOffer(
      requestId: requestId,
      workerUserId: workerUserId,
      amount: amount,
      message: message,
    );
  }
}

class GetRequestTrackingUseCase {
  GetRequestTrackingUseCase(this._repository);

  final RequestRepository _repository;

  Future<Result<RequestPayloadEntity>> call({required String requestId}) {
    return _repository.tracking(requestId: requestId);
  }
}

class WorkerMarkArrivedUseCase {
  WorkerMarkArrivedUseCase(this._repository);

  final RequestRepository _repository;

  Future<Result<RequestPayloadEntity>> call({
    required String requestId,
    required String workerUserId,
  }) {
    return _repository.workerMarkArrived(
      requestId: requestId,
      workerUserId: workerUserId,
    );
  }
}

class CompleteJobUseCase {
  CompleteJobUseCase(this._repository);

  final RequestRepository _repository;

  Future<Result<RequestPayloadEntity>> call({
    required String requestId,
    required String workerUserId,
  }) {
    return _repository.completeJob(
      requestId: requestId,
      workerUserId: workerUserId,
    );
  }
}

class CancelJobUseCase {
  CancelJobUseCase(this._repository);

  final RequestRepository _repository;

  Future<Result<RequestPayloadEntity>> call({
    required String requestId,
    required String userId,
  }) {
    return _repository.cancelJob(requestId: requestId, userId: userId);
  }
}

class GetRequestMessagesUseCase {
  GetRequestMessagesUseCase(this._repository);

  final RequestRepository _repository;

  Future<Result<RequestPayloadEntity>> call({required String userId}) {
    return _repository.messages(userId: userId);
  }
}

class DiscardOfferUseCase {
  DiscardOfferUseCase(this._repository);

  final RequestRepository _repository;

  Future<Result<void>> call({
    required String requestId,
    required String workerUserId,
  }) {
    return _repository.declineOffer(
      requestId: requestId,
      workerUserId: workerUserId,
    );
  }
}

class ClientCounterOfferUseCase {
  ClientCounterOfferUseCase(this._repository);

  final RequestRepository _repository;

  Future<Result<void>> call({
    required String requestId,
    required String clientUserId,
    required double amount,
  }) {
    return _repository.clientCounterOffer(
      requestId: requestId,
      clientUserId: clientUserId,
      amount: amount,
    );
  }
}

class DeclineOfferUseCase {
  DeclineOfferUseCase(this._repository);

  final RequestRepository _repository;

  Future<Result<void>> call({
    required String requestId,
    required String workerUserId,
  }) {
    return _repository.declineOffer(
      requestId: requestId,
      workerUserId: workerUserId,
    );
  }
}

class ReactivateOfferUseCase {
  ReactivateOfferUseCase(this._repository);

  final RequestRepository _repository;

  Future<Result<void>> call({
    required String requestId,
    required String workerUserId,
  }) {
    return _repository.reactivateOffer(
      requestId: requestId,
      workerUserId: workerUserId,
    );
  }
}
