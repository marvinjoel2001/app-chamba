import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/tracking_payload_entity.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../datasources/tracking_remote_datasource.dart';
import '../models/tracking_payload_model.dart';

class TrackingRepositoryImpl implements TrackingRepository {
  TrackingRepositoryImpl(this._remote);

  final TrackingRemoteDataSource _remote;

  @override
  Future<Result<TrackingPayloadEntity>> tracking({required String requestId}) {
    return _wrap(() => _remote.tracking(requestId: requestId));
  }

  @override
  Future<Result<TrackingPayloadEntity>> clientConfirmArrival({
    required String requestId,
    required String clientUserId,
  }) {
    return _wrap(
      () => _remote.clientConfirmArrival(
        requestId: requestId,
        clientUserId: clientUserId,
      ),
    );
  }

  @override
  Future<Result<TrackingPayloadEntity>> cancelJob({
    required String requestId,
    required String userId,
  }) {
    return _wrap(() => _remote.cancelJob(requestId: requestId, userId: userId));
  }

  @override
  Future<Result<TrackingPayloadEntity>> messages({required String userId}) {
    return _wrap(() => _remote.messages(userId: userId));
  }

  Future<Result<TrackingPayloadEntity>> _wrap(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    try {
      final response = await action();
      return Success(TrackingPayloadModel.fromJson(response));
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }
}
