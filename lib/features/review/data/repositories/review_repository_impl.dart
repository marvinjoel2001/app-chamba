import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/review_payload_entity.dart';
import '../../domain/repositories/review_repository.dart';
import '../datasources/review_remote_datasource.dart';
import '../models/review_payload_model.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  ReviewRepositoryImpl(this._remote);

  final ReviewRemoteDataSource _remote;

  @override
  Future<Result<ReviewPayloadEntity>> offers({
    String? requestId,
    String? clientUserId,
  }) {
    return _wrap(
      () => _remote.offers(requestId: requestId, clientUserId: clientUserId),
    );
  }

  @override
  Future<Result<ReviewPayloadEntity>> createReview({
    required String requestId,
    required String workerUserId,
    required String clientUserId,
    required int stars,
    String? comment,
  }) {
    return _wrap(
      () => _remote.createReview(
        requestId: requestId,
        workerUserId: workerUserId,
        clientUserId: clientUserId,
        stars: stars,
        comment: comment,
      ),
    );
  }

  Future<Result<ReviewPayloadEntity>> _wrap(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    try {
      final response = await action();
      return Success(ReviewPayloadModel.fromJson(response));
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }
}
