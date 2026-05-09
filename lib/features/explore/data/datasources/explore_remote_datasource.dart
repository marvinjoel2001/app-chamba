import '../../../../core/services/mobile_backend_service.dart';

abstract class ExploreRemoteDataSource {
  Future<Map<String, dynamic>> explore({
    required String userId,
    double? latitude,
    double? longitude,
    double? radiusKm,
  });

  Future<Map<String, dynamic>> previewRequestCategories({
    String? title,
    required String description,
    String? category,
  });
}

class ExploreRemoteDataSourceImpl implements ExploreRemoteDataSource {
  const ExploreRemoteDataSourceImpl();

  @override
  Future<Map<String, dynamic>> explore({
    required String userId,
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) {
    return MobileBackendService.instance.explore(
      userId: userId,
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    );
  }

  @override
  Future<Map<String, dynamic>> previewRequestCategories({
    String? title,
    required String description,
    String? category,
  }) {
    return MobileBackendService.instance.previewRequestCategories(
      title: title,
      description: description,
      category: category,
    );
  }
}
