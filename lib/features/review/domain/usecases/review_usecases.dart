import '../../../../core/errors/result.dart';
import '../entities/review_payload_entity.dart';
import '../repositories/review_repository.dart';

class GetReviewOffersUseCase {
  GetReviewOffersUseCase(this._repository);

  final ReviewRepository _repository;

  Future<Result<ReviewPayloadEntity>> call({
    String? requestId,
    String? clientUserId,
  }) {
    return _repository.offers(requestId: requestId, clientUserId: clientUserId);
  }
}

class CreateReviewUseCase {
  CreateReviewUseCase(this._repository);

  final ReviewRepository _repository;

  Future<Result<ReviewPayloadEntity>> call({
    required String requestId,
    required String workerUserId,
    required String clientUserId,
    required int stars,
    String? comment,
  }) {
    return _repository.createReview(
      requestId: requestId,
      workerUserId: workerUserId,
      clientUserId: clientUserId,
      stars: stars,
      comment: comment,
    );
  }
}
