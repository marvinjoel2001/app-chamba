import '../../../../core/services/mobile_backend_service.dart';
import '../../domain/entities/worker_portfolio_photo.dart';

abstract class WorkerPortfolioRepository {
  Future<List<WorkerPortfolioPhoto>> list();
  Future<WorkerPortfolioPhoto> add({
    required String imageBase64,
    required String caption,
  });
  Future<void> remove(String photoId);
}

class WorkerPortfolioRepositoryImpl implements WorkerPortfolioRepository {
  const WorkerPortfolioRepositoryImpl(this._backend);

  final MobileBackendService _backend;

  @override
  Future<List<WorkerPortfolioPhoto>> list() async {
    final response = await _backend.workerPortfolio();
    return (response['photos'] as List<dynamic>)
        .map((photo) =>
            WorkerPortfolioPhoto.fromJson(photo as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<WorkerPortfolioPhoto> add({
    required String imageBase64,
    required String caption,
  }) async {
    final response = await _backend.addWorkerPortfolioPhoto(
      imageBase64: imageBase64,
      caption: caption,
    );
    return WorkerPortfolioPhoto.fromJson(
        response['photo'] as Map<String, dynamic>);
  }

  @override
  Future<void> remove(String photoId) async {
    await _backend.removeWorkerPortfolioPhoto(photoId);
  }
}
