import '../../../../core/errors/result.dart';
import '../entities/request_payload_entity.dart';

abstract class RequestRepository {
  Future<Result<RequestPayloadEntity>> createRequest({
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
    String? modality,
    int? estimatedHours,
    double? hourlyRate,
    int? days,
    double? dailyRate,
    String? startDate,
  });

  Future<Result<RequestPayloadEntity>> requestStatus({
    String? requestId,
    String? clientUserId,
  });

  Future<Result<RequestPayloadEntity>> incomingRequest({
    required String workerUserId,
  });

  Future<Result<void>> blockClient({
    required String workerUserId,
    required String clientUserId,
  });

  Future<Result<void>> reportRequest({
    required String requestId,
    required String reporterUserId,
    required String reason,
  });

  Future<Result<void>> dismissRequest({
    required String requestId,
    required String workerUserId,
  });

  Future<Result<RequestPayloadEntity>> updateWorkerLocation({
    required String workerUserId,
    required double latitude,
    required double longitude,
  });

  Future<Result<RequestPayloadEntity>> setAvailability({
    required String workerUserId,
    required bool available,
  });

  Future<Result<RequestPayloadEntity>> counterOffer({
    required String requestId,
    required String workerUserId,
    required double amount,
    String? message,
  });

  Future<Result<void>> clientCounterOffer({
    required String requestId,
    required String clientUserId,
    required double amount,
  });

  Future<Result<void>> declineOffer({
    required String requestId,
    required String workerUserId,
  });

  Future<Result<void>> reactivateOffer({
    required String requestId,
    required String workerUserId,
  });

  Future<Result<RequestPayloadEntity>> tracking({required String requestId});

  Future<Result<RequestPayloadEntity>> workerMarkArrived({
    required String requestId,
    required String workerUserId,
  });

  Future<Result<RequestPayloadEntity>> completeJob({
    required String requestId,
    required String workerUserId,
  });

  Future<Result<RequestPayloadEntity>> cancelJob({
    required String requestId,
    required String userId,
  });

  Future<Result<RequestPayloadEntity>> messages({required String userId});
}
