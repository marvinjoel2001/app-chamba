import '../../../../core/errors/result.dart';
import '../entities/worker_availability.dart';
import '../entities/worker_category.dart';
import '../entities/worker_job.dart';
import '../entities/worker_modalities.dart';
import '../entities/worker_radar_summary.dart';
import '../entities/worker_skill.dart';
import '../repositories/worker_repository.dart';

class GetWorkerRadarUseCase {
  GetWorkerRadarUseCase(this._repository);

  final WorkerRepository _repository;

  Future<Result<WorkerRadarSummary>> call({required String workerUserId}) {
    return _repository.workerRadar(workerUserId: workerUserId);
  }
}

class SetWorkerAvailabilityUseCase {
  SetWorkerAvailabilityUseCase(this._repository);

  final WorkerRepository _repository;

  Future<Result<WorkerAvailability>> call({
    required String workerUserId,
    required bool available,
  }) {
    return _repository.setAvailability(
      workerUserId: workerUserId,
      available: available,
    );
  }
}

class GetWorkerSkillsUseCase {
  GetWorkerSkillsUseCase(this._repository);

  final WorkerRepository _repository;

  Future<Result<List<WorkerSkill>>> call({required String workerUserId}) {
    return _repository.workerSkills(workerUserId: workerUserId);
  }
}

class UpdateWorkerSkillsUseCase {
  UpdateWorkerSkillsUseCase(this._repository);

  final WorkerRepository _repository;

  Future<Result<List<WorkerSkill>>> call({
    required String workerUserId,
    required List<String> skills,
  }) {
    return _repository.updateWorkerSkills(
      workerUserId: workerUserId,
      skills: skills,
    );
  }
}

class GetWorkerModalitiesUseCase {
  GetWorkerModalitiesUseCase(this._repository);

  final WorkerRepository _repository;

  Future<Result<WorkerModalities>> call({required String workerUserId}) {
    return _repository.workerModalities(workerUserId: workerUserId);
  }
}

class UpdateWorkerModalitiesUseCase {
  UpdateWorkerModalitiesUseCase(this._repository);

  final WorkerRepository _repository;

  Future<Result<WorkerModalities>> call({
    required String workerUserId,
    required List<String> modalities,
    double? hourlyRate,
    double? dailyRate,
  }) {
    return _repository.updateWorkerModalities(
      workerUserId: workerUserId,
      modalities: modalities,
      hourlyRate: hourlyRate,
      dailyRate: dailyRate,
    );
  }
}

class GetWorkerHistoryUseCase {
  GetWorkerHistoryUseCase(this._repository);

  final WorkerRepository _repository;

  Future<Result<List<WorkerJob>>> call({required String workerUserId}) {
    return _repository.workerHistory(workerUserId: workerUserId);
  }
}

class GetWorkerCategoriesUseCase {
  GetWorkerCategoriesUseCase(this._repository);

  final WorkerRepository _repository;

  Future<Result<List<WorkerCategory>>> call() {
    return _repository.categories();
  }
}

class CreateWorkerCategoryUseCase {
  CreateWorkerCategoryUseCase(this._repository);

  final WorkerRepository _repository;

  Future<Result<WorkerCategory>> call({required String name}) {
    return _repository.createCategory(name: name);
  }
}

class UploadWorkerProfilePhotoUseCase {
  UploadWorkerProfilePhotoUseCase(this._repository);

  final WorkerRepository _repository;

  Future<Result<void>> call({
    required String userId,
    String? imageUrl,
    String? imagePublicId,
  }) {
    return _repository.uploadProfilePhoto(
      userId: userId,
      imageUrl: imageUrl,
      imagePublicId: imagePublicId,
    );
  }
}

class DeleteWorkerProfilePhotoUseCase {
  DeleteWorkerProfilePhotoUseCase(this._repository);

  final WorkerRepository _repository;

  Future<Result<void>> call({required String userId}) {
    return _repository.deleteProfilePhoto(userId: userId);
  }
}

class UpdateWorkerLocationUseCase {
  UpdateWorkerLocationUseCase(this._repository);

  final WorkerRepository _repository;

  Future<Result<void>> call({
    required String workerUserId,
    required double latitude,
    required double longitude,
  }) {
    return _repository.updateWorkerLocation(
      workerUserId: workerUserId,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
