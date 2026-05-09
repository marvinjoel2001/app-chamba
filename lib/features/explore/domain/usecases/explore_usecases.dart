import '../../../../core/errors/result.dart';
import '../entities/explore_payload_entity.dart';
import '../repositories/explore_repository.dart';

class ExploreUseCase {
  ExploreUseCase(this._repository);

  final ExploreRepository _repository;

  Future<Result<ExplorePayloadEntity>> call({
    required String userId,
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) {
    return _repository.explore(
      userId: userId,
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    );
  }
}

class PreviewRequestCategoriesUseCase {
  PreviewRequestCategoriesUseCase(this._repository);

  final ExploreRepository _repository;

  Future<Result<ExplorePayloadEntity>> call({
    String? title,
    required String description,
    String? category,
  }) {
    return _repository.previewRequestCategories(
      title: title,
      description: description,
      category: category,
    );
  }
}
