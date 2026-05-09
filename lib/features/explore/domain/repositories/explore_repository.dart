import '../../../../core/errors/result.dart';
import '../entities/explore_payload_entity.dart';

abstract class ExploreRepository {
  Future<Result<ExplorePayloadEntity>> explore({
    required String userId,
    double? latitude,
    double? longitude,
    double? radiusKm,
  });

  Future<Result<ExplorePayloadEntity>> previewRequestCategories({
    String? title,
    required String description,
    String? category,
  });
}
