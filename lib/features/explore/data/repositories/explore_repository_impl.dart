import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/explore_payload_entity.dart';
import '../../domain/repositories/explore_repository.dart';
import '../datasources/explore_remote_datasource.dart';
import '../models/explore_payload_model.dart';

class ExploreRepositoryImpl implements ExploreRepository {
  ExploreRepositoryImpl(this._remote);

  final ExploreRemoteDataSource _remote;

  @override
  Future<Result<ExplorePayloadEntity>> explore({
    required String userId,
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) {
    return _wrap(
      () => _remote.explore(
        userId: userId,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
      ),
    );
  }

  @override
  Future<Result<ExplorePayloadEntity>> previewRequestCategories({
    String? title,
    required String description,
    String? category,
  }) {
    return _wrap(
      () => _remote.previewRequestCategories(
        title: title,
        description: description,
        category: category,
      ),
    );
  }

  Future<Result<ExplorePayloadEntity>> _wrap(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    try {
      final response = await action();
      return Success(ExplorePayloadModel.fromJson(response));
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }
}
