import '../../../../core/services/mobile_backend_service.dart';

abstract class ReviewRemoteDataSource {
  Future<Map<String, dynamic>> offers({
    String? requestId,
    String? clientUserId,
  });
  Future<Map<String, dynamic>> createReview({
    required String requestId,
    required String workerUserId,
    required String clientUserId,
    required int stars,
    String? comment,
  });
}

class ReviewRemoteDataSourceImpl implements ReviewRemoteDataSource {
  const ReviewRemoteDataSourceImpl();

  @override
  Future<Map<String, dynamic>> offers({
    String? requestId,
    String? clientUserId,
  }) {
    return MobileBackendService.instance.offers(
      requestId: requestId,
      clientUserId: clientUserId,
    );
  }

  @override
  Future<Map<String, dynamic>> createReview({
    required String requestId,
    required String workerUserId,
    required String clientUserId,
    required int stars,
    String? comment,
  }) {
    return MobileBackendService.instance.createReview(
      requestId: requestId,
      workerUserId: workerUserId,
      clientUserId: clientUserId,
      stars: stars,
      comment: comment,
    );
  }
}
