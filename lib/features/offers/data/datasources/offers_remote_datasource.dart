import '../../../../core/services/mobile_backend_service.dart';

abstract class OffersRemoteDataSource {
  Future<Map<String, dynamic>> offers({
    String? requestId,
    String? clientUserId,
  });
  Future<Map<String, dynamic>> workerProfile(String workerId);
  Future<Map<String, dynamic>> acceptOffer({
    required String offerId,
    required String clientUserId,
  });
  Future<Map<String, dynamic>> counterOffer({
    required String requestId,
    required String workerUserId,
    required double amount,
    String? message,
  });
}

class OffersRemoteDataSourceImpl implements OffersRemoteDataSource {
  const OffersRemoteDataSourceImpl();

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
  Future<Map<String, dynamic>> workerProfile(String workerId) {
    return MobileBackendService.instance.workerProfile(workerId);
  }

  @override
  Future<Map<String, dynamic>> acceptOffer({
    required String offerId,
    required String clientUserId,
  }) {
    return MobileBackendService.instance.acceptOffer(
      offerId: offerId,
      clientUserId: clientUserId,
    );
  }

  @override
  Future<Map<String, dynamic>> counterOffer({
    required String requestId,
    required String workerUserId,
    required double amount,
    String? message,
  }) {
    return MobileBackendService.instance.counterOffer(
      requestId: requestId,
      workerUserId: workerUserId,
      amount: amount,
      message: message,
    );
  }
}
