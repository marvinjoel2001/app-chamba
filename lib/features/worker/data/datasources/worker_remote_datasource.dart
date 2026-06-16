import '../../../../core/services/mobile_backend_service.dart';

abstract class WorkerRemoteDataSource {
  Future<Map<String, dynamic>> workerRadar({required String workerUserId});

  Future<Map<String, dynamic>> setAvailability({
    required String workerUserId,
    required bool available,
  });

  Future<Map<String, dynamic>> workerSkills({required String workerUserId});

  Future<Map<String, dynamic>> updateWorkerSkills({
    required String workerUserId,
    required List<String> skills,
  });

  Future<Map<String, dynamic>> workerModalities({
    required String workerUserId,
  });

  Future<Map<String, dynamic>> updateWorkerModalities({
    required String workerUserId,
    required List<String> modalities,
    double? hourlyRate,
    double? dailyRate,
  });

  Future<Map<String, dynamic>> workerHistory({required String workerUserId});

  Future<Map<String, dynamic>> categories();

  Future<Map<String, dynamic>> createCategory({required String name});

  Future<Map<String, dynamic>> uploadProfilePhoto({
    required String userId,
    String? imageUrl,
    String? imagePublicId,
  });

  Future<Map<String, dynamic>> deleteProfilePhoto({required String userId});

  Future<Map<String, dynamic>> updateWorkerLocation({
    required String workerUserId,
    required double latitude,
    required double longitude,
  });
}

class WorkerRemoteDataSourceImpl implements WorkerRemoteDataSource {
  const WorkerRemoteDataSourceImpl(this._backendService);

  final MobileBackendService _backendService;

  @override
  Future<Map<String, dynamic>> workerRadar({required String workerUserId}) {
    return _backendService.workerRadar(workerUserId: workerUserId);
  }

  @override
  Future<Map<String, dynamic>> setAvailability({
    required String workerUserId,
    required bool available,
  }) {
    return _backendService.setAvailability(
      workerUserId: workerUserId,
      available: available,
    );
  }

  @override
  Future<Map<String, dynamic>> workerSkills({required String workerUserId}) {
    return _backendService.workerSkills(workerUserId: workerUserId);
  }

  @override
  Future<Map<String, dynamic>> updateWorkerSkills({
    required String workerUserId,
    required List<String> skills,
  }) {
    return _backendService.updateWorkerSkills(
      workerUserId: workerUserId,
      skills: skills,
    );
  }

  @override
  Future<Map<String, dynamic>> workerModalities({
    required String workerUserId,
  }) {
    return _backendService.workerModalities(workerUserId: workerUserId);
  }

  @override
  Future<Map<String, dynamic>> updateWorkerModalities({
    required String workerUserId,
    required List<String> modalities,
    double? hourlyRate,
    double? dailyRate,
  }) {
    return _backendService.updateWorkerModalities(
      workerUserId: workerUserId,
      modalities: modalities,
      hourlyRate: hourlyRate,
      dailyRate: dailyRate,
    );
  }

  @override
  Future<Map<String, dynamic>> workerHistory({required String workerUserId}) {
    return _backendService.workerHistory(workerUserId: workerUserId);
  }

  @override
  Future<Map<String, dynamic>> categories() {
    return _backendService.categories();
  }

  @override
  Future<Map<String, dynamic>> createCategory({required String name}) {
    return _backendService.createCategory(name: name);
  }

  @override
  Future<Map<String, dynamic>> uploadProfilePhoto({
    required String userId,
    String? imageUrl,
    String? imagePublicId,
  }) {
    return _backendService.uploadProfilePhoto(
      userId: userId,
      imageUrl: imageUrl,
      imagePublicId: imagePublicId,
    );
  }

  @override
  Future<Map<String, dynamic>> deleteProfilePhoto({required String userId}) {
    return _backendService.deleteProfilePhoto(userId: userId);
  }

  @override
  Future<Map<String, dynamic>> updateWorkerLocation({
    required String workerUserId,
    required double latitude,
    required double longitude,
  }) {
    return _backendService.updateWorkerLocation(
      workerUserId: workerUserId,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
