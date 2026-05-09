import '../../../../core/errors/result.dart';
import '../entities/offers_payload_entity.dart';

abstract class OffersRepository {
  Future<Result<OffersPayloadEntity>> offers({
    String? requestId,
    String? clientUserId,
  });

  Future<Result<OffersPayloadEntity>> workerProfile(String workerId);

  Future<Result<OffersPayloadEntity>> acceptOffer({
    required String offerId,
    required String clientUserId,
  });

  Future<Result<OffersPayloadEntity>> counterOffer({
    required String requestId,
    required String workerUserId,
    required double amount,
    String? message,
  });
}
