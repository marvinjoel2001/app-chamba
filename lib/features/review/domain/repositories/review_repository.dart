import '../../../../core/errors/result.dart';
import '../entities/review_payload_entity.dart';

abstract class ReviewRepository {
  Future<Result<ReviewPayloadEntity>> offers({
    String? requestId,
    String? clientUserId,
  });

  Future<Result<ReviewPayloadEntity>> createReview({
    required String requestId,
    required String workerUserId,
    required String clientUserId,
    required int stars,
    String? comment,
  });
}
