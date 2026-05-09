import '../../../../core/services/mobile_backend_service.dart';

abstract class RequestRemoteDataSource {
  Future<Map<String, dynamic>> createRequest({
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
  });

  Future<Map<String, dynamic>> requestStatus({
    String? requestId,
    String? clientUserId,
  });

  Future<Map<String, dynamic>> incomingRequest({required String workerUserId});

  Future<Map<String, dynamic>> updateWorkerLocation({
    required String workerUserId,
    required double latitude,
    required double longitude,
  });

  Future<Map<String, dynamic>> setAvailability({
    required String workerUserId,
    required bool available,
  });

  Future<Map<String, dynamic>> counterOffer({
    required String requestId,
    required String workerUserId,
    required double amount,
    String? message,
  });

  Future<Map<String, dynamic>> clientCounterOffer({
    required String requestId,
    required String clientUserId,
    required double amount,
  });

  Future<void> declineOffer({
    required String requestId,
    required String workerUserId,
  });

  Future<void> reactivateOffer({
    required String requestId,
    required String workerUserId,
  });

  Future<Map<String, dynamic>> tracking({required String requestId});

  Future<Map<String, dynamic>> workerMarkArrived({
    required String requestId,
    required String workerUserId,
  });

  Future<Map<String, dynamic>> completeJob({
    required String requestId,
    required String workerUserId,
  });

  Future<Map<String, dynamic>> cancelJob({
    required String requestId,
    required String userId,
  });

  Future<Map<String, dynamic>> messages({required String userId});
}

class RequestRemoteDataSourceImpl implements RequestRemoteDataSource {
  const RequestRemoteDataSourceImpl();

  @override
  Future<Map<String, dynamic>> createRequest({
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
  }) {
    return MobileBackendService.instance.createRequest(
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
    );
  }

  @override
  Future<Map<String, dynamic>> requestStatus({
    String? requestId,
    String? clientUserId,
  }) {
    return MobileBackendService.instance.requestStatus(
      requestId: requestId,
      clientUserId: clientUserId,
    );
  }

  @override
  Future<Map<String, dynamic>> incomingRequest({required String workerUserId}) {
    return MobileBackendService.instance.incomingRequest(
      workerUserId: workerUserId,
    );
  }

  @override
  Future<Map<String, dynamic>> updateWorkerLocation({
    required String workerUserId,
    required double latitude,
    required double longitude,
  }) {
    return MobileBackendService.instance.updateWorkerLocation(
      workerUserId: workerUserId,
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  Future<Map<String, dynamic>> setAvailability({
    required String workerUserId,
    required bool available,
  }) {
    return MobileBackendService.instance.setAvailability(
      workerUserId: workerUserId,
      available: available,
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

  @override
  Future<Map<String, dynamic>> clientCounterOffer({
    required String requestId,
    required String clientUserId,
    required double amount,
  }) {
    return MobileBackendService.instance.clientCounterOffer(
      requestId: requestId,
      clientUserId: clientUserId,
      amount: amount,
    );
  }

  @override
  Future<void> declineOffer({
    required String requestId,
    required String workerUserId,
  }) async {
    await MobileBackendService.instance.declineOffer(
      requestId: requestId,
      workerUserId: workerUserId,
    );
  }

  @override
  Future<void> reactivateOffer({
    required String requestId,
    required String workerUserId,
  }) async {
    await MobileBackendService.instance.reactivateOffer(
      requestId: requestId,
      workerUserId: workerUserId,
    );
  }

  @override
  Future<Map<String, dynamic>> tracking({required String requestId}) {
    return MobileBackendService.instance.tracking(requestId: requestId);
  }

  @override
  Future<Map<String, dynamic>> workerMarkArrived({
    required String requestId,
    required String workerUserId,
  }) {
    return MobileBackendService.instance.workerMarkArrived(
      requestId: requestId,
      workerUserId: workerUserId,
    );
  }

  @override
  Future<Map<String, dynamic>> completeJob({
    required String requestId,
    required String workerUserId,
  }) {
    return MobileBackendService.instance.completeJob(
      requestId: requestId,
      workerUserId: workerUserId,
    );
  }

  @override
  Future<Map<String, dynamic>> cancelJob({
    required String requestId,
    required String userId,
  }) {
    return MobileBackendService.instance.cancelJob(
      requestId: requestId,
      userId: userId,
    );
  }

  @override
  Future<Map<String, dynamic>> messages({required String userId}) {
    return MobileBackendService.instance.messages(userId: userId);
  }
}
