import '../../../../core/services/mobile_backend_service.dart';

abstract class TrackingRemoteDataSource {
  Future<Map<String, dynamic>> tracking({required String requestId});
  Future<Map<String, dynamic>> clientConfirmArrival({
    required String requestId,
    required String clientUserId,
  });
  Future<Map<String, dynamic>> cancelJob({
    required String requestId,
    required String userId,
  });
  Future<Map<String, dynamic>> messages({required String userId});
}

class TrackingRemoteDataSourceImpl implements TrackingRemoteDataSource {
  const TrackingRemoteDataSourceImpl();

  @override
  Future<Map<String, dynamic>> tracking({required String requestId}) {
    return MobileBackendService.instance.tracking(requestId: requestId);
  }

  @override
  Future<Map<String, dynamic>> clientConfirmArrival({
    required String requestId,
    required String clientUserId,
  }) {
    return MobileBackendService.instance.clientConfirmArrival(
      requestId: requestId,
      clientUserId: clientUserId,
    );
  }

  @override
  Future<Map<String, dynamic>> cancelJob({
    required String requestId,
    required String userId,
  }) {
    return MobileBackendService.instance.cancelJob(requestId: requestId, userId: userId);
  }

  @override
  Future<Map<String, dynamic>> messages({required String userId}) {
    return MobileBackendService.instance.messages(userId: userId);
  }
}
