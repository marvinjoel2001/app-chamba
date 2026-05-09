import '../../../../core/errors/result.dart';
import '../entities/offers_payload_entity.dart';
import '../repositories/offers_repository.dart';

class GetOffersUseCase {
  GetOffersUseCase(this._repository);

  final OffersRepository _repository;

  Future<Result<OffersPayloadEntity>> call({
    String? requestId,
    String? clientUserId,
  }) {
    return _repository.offers(requestId: requestId, clientUserId: clientUserId);
  }
}

class GetWorkerProfileUseCase {
  GetWorkerProfileUseCase(this._repository);

  final OffersRepository _repository;

  Future<Result<OffersPayloadEntity>> call(String workerId) {
    return _repository.workerProfile(workerId);
  }
}

class AcceptOfferUseCase {
  AcceptOfferUseCase(this._repository);

  final OffersRepository _repository;

  Future<Result<OffersPayloadEntity>> call({
    required String offerId,
    required String clientUserId,
  }) {
    return _repository.acceptOffer(
      offerId: offerId,
      clientUserId: clientUserId,
    );
  }
}

class CounterOfferUseCase {
  CounterOfferUseCase(this._repository);

  final OffersRepository _repository;

  Future<Result<OffersPayloadEntity>> call({
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
