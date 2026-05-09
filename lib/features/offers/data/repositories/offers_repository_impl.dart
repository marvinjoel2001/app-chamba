import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/offers_payload_entity.dart';
import '../../domain/repositories/offers_repository.dart';
import '../datasources/offers_remote_datasource.dart';
import '../models/offers_payload_model.dart';

class OffersRepositoryImpl implements OffersRepository {
  OffersRepositoryImpl(this._remote);

  final OffersRemoteDataSource _remote;

  @override
  Future<Result<OffersPayloadEntity>> offers({
    String? requestId,
    String? clientUserId,
  }) {
    return _wrap(
      () => _remote.offers(requestId: requestId, clientUserId: clientUserId),
    );
  }

  @override
  Future<Result<OffersPayloadEntity>> workerProfile(String workerId) {
    return _wrap(() => _remote.workerProfile(workerId));
  }

  @override
  Future<Result<OffersPayloadEntity>> acceptOffer({
    required String offerId,
    required String clientUserId,
  }) {
    return _wrap(
      () => _remote.acceptOffer(offerId: offerId, clientUserId: clientUserId),
    );
  }

  @override
  Future<Result<OffersPayloadEntity>> counterOffer({
    required String requestId,
    required String workerUserId,
    required double amount,
    String? message,
  }) {
    return _wrap(
      () => _remote.counterOffer(
        requestId: requestId,
        workerUserId: workerUserId,
        amount: amount,
        message: message,
      ),
    );
  }

  Future<Result<OffersPayloadEntity>> _wrap(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    try {
      final response = await action();
      return Success(OffersPayloadModel.fromJson(response));
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }
}
