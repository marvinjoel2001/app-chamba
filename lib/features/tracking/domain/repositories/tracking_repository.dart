import '../../../../core/errors/result.dart';
import '../entities/tracking_payload_entity.dart';

abstract class TrackingRepository {
  Future<Result<TrackingPayloadEntity>> tracking({required String requestId});
  Future<Result<TrackingPayloadEntity>> clientConfirmArrival({
    required String requestId,
    required String clientUserId,
  });
  Future<Result<TrackingPayloadEntity>> cancelJob({
    required String requestId,
    required String userId,
  });
  Future<Result<TrackingPayloadEntity>> messages({required String userId});
}
