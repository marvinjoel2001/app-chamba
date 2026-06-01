import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/request_payload_entity.dart';
import '../../domain/repositories/request_repository.dart';
import '../datasources/request_remote_datasource.dart';
import '../models/request_payload_model.dart';

class RequestRepositoryImpl implements RequestRepository {
  RequestRepositoryImpl(this._remote);

  final RequestRemoteDataSource _remote;

  @override
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
  }) {
    return _wrap(
      () => _remote.createRequest(
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
        paymentMethod: paymentMethod,
      ),
    );
  }

  @override
  Future<Result<RequestPayloadEntity>> requestStatus({
    String? requestId,
    String? clientUserId,
  }) {
    return _wrap(
      () => _remote.requestStatus(
        requestId: requestId,
        clientUserId: clientUserId,
      ),
    );
  }

  @override
  Future<Result<RequestPayloadEntity>> incomingRequest({
    required String workerUserId,
  }) {
    return _wrap(() => _remote.incomingRequest(workerUserId: workerUserId));
  }

  @override
  Future<Result<RequestPayloadEntity>> updateWorkerLocation({
    required String workerUserId,
    required double latitude,
    required double longitude,
  }) {
    return _wrap(
      () => _remote.updateWorkerLocation(
        workerUserId: workerUserId,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  @override
  Future<Result<RequestPayloadEntity>> setAvailability({
    required String workerUserId,
    required bool available,
  }) {
    return _wrap(
      () => _remote.setAvailability(
        workerUserId: workerUserId,
        available: available,
      ),
    );
  }

  @override
  Future<Result<RequestPayloadEntity>> counterOffer({
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

  @override
  Future<Result<void>> clientCounterOffer({
    required String requestId,
    required String clientUserId,
    required double amount,
  }) {
    return _wrapVoid(
      () => _remote.clientCounterOffer(
        requestId: requestId,
        clientUserId: clientUserId,
        amount: amount,
      ),
    );
  }

  @override
  Future<Result<void>> declineOffer({
    required String requestId,
    required String workerUserId,
  }) {
    return _wrapVoid(
      () => _remote.declineOffer(
        requestId: requestId,
        workerUserId: workerUserId,
      ),
    );
  }

  @override
  Future<Result<void>> reactivateOffer({
    required String requestId,
    required String workerUserId,
  }) {
    return _wrapVoid(
      () => _remote.reactivateOffer(
        requestId: requestId,
        workerUserId: workerUserId,
      ),
    );
  }

  @override
  Future<Result<RequestPayloadEntity>> tracking({required String requestId}) {
    return _wrap(() => _remote.tracking(requestId: requestId));
  }

  @override
  Future<Result<RequestPayloadEntity>> workerMarkArrived({
    required String requestId,
    required String workerUserId,
  }) {
    return _wrap(
      () => _remote.workerMarkArrived(
        requestId: requestId,
        workerUserId: workerUserId,
      ),
    );
  }

  @override
  Future<Result<RequestPayloadEntity>> completeJob({
    required String requestId,
    required String workerUserId,
  }) {
    return _wrap(
      () =>
          _remote.completeJob(requestId: requestId, workerUserId: workerUserId),
    );
  }

  @override
  Future<Result<RequestPayloadEntity>> cancelJob({
    required String requestId,
    required String userId,
  }) {
    return _wrap(() => _remote.cancelJob(requestId: requestId, userId: userId));
  }

  @override
  Future<Result<RequestPayloadEntity>> messages({required String userId}) {
    return _wrap(() => _remote.messages(userId: userId));
  }

  Future<Result<RequestPayloadEntity>> _wrap(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    try {
      final response = await action();
      return Success(RequestPayloadModel.fromJson(response));
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }

  Future<Result<void>> _wrapVoid(Future<void> Function() action) async {
    try {
      await action();
      return const Success(null);
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }
}
