import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/worker_availability.dart';
import '../../domain/entities/worker_category.dart';
import '../../domain/entities/worker_job.dart';
import '../../domain/entities/worker_modalities.dart';
import '../../domain/entities/worker_radar_summary.dart';
import '../../domain/entities/worker_skill.dart';
import '../../domain/repositories/worker_repository.dart';
import '../datasources/worker_remote_datasource.dart';
import '../models/worker_availability_model.dart';
import '../models/worker_category_model.dart';
import '../models/worker_job_model.dart';
import '../models/worker_modalities_model.dart';
import '../models/worker_radar_summary_model.dart';
import '../models/worker_skill_model.dart';

class WorkerRepositoryImpl implements WorkerRepository {
  WorkerRepositoryImpl(this._remote);

  final WorkerRemoteDataSource _remote;

  @override
  Future<Result<WorkerRadarSummary>> workerRadar({
    required String workerUserId,
  }) async {
    try {
      final response = await _remote.workerRadar(workerUserId: workerUserId);
      return Success(WorkerRadarSummaryModel.fromJson(response));
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }

  @override
  Future<Result<WorkerAvailability>> setAvailability({
    required String workerUserId,
    required bool available,
  }) async {
    try {
      final response = await _remote.setAvailability(
        workerUserId: workerUserId,
        available: available,
      );
      return Success(WorkerAvailabilityModel.fromJson(response));
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }

  @override
  Future<Result<List<WorkerSkill>>> workerSkills({
    required String workerUserId,
  }) async {
    try {
      final response = await _remote.workerSkills(workerUserId: workerUserId);
      final rawSkills = (response['skills'] as List<dynamic>? ?? const []);
      final skills = rawSkills
          .map(WorkerSkillModel.fromDynamic)
          .where((skill) => skill.name.trim().isNotEmpty)
          .toList(growable: false);
      return Success(skills);
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }

  @override
  Future<Result<List<WorkerSkill>>> updateWorkerSkills({
    required String workerUserId,
    required List<String> skills,
  }) async {
    try {
      final response = await _remote.updateWorkerSkills(
        workerUserId: workerUserId,
        skills: skills,
      );
      final rawSkills = (response['skills'] as List<dynamic>? ?? skills);
      final normalized = rawSkills
          .map(WorkerSkillModel.fromDynamic)
          .where((skill) => skill.name.trim().isNotEmpty)
          .toList(growable: false);
      return Success(normalized);
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }

  @override
  Future<Result<WorkerModalities>> workerModalities({
    required String workerUserId,
  }) async {
    try {
      final response = await _remote.workerModalities(
        workerUserId: workerUserId,
      );
      return Success(WorkerModalitiesModel.fromJson(response));
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }

  @override
  Future<Result<WorkerModalities>> updateWorkerModalities({
    required String workerUserId,
    required List<String> modalities,
    double? hourlyRate,
    double? dailyRate,
  }) async {
    try {
      final response = await _remote.updateWorkerModalities(
        workerUserId: workerUserId,
        modalities: modalities,
        hourlyRate: hourlyRate,
        dailyRate: dailyRate,
      );
      return Success(WorkerModalitiesModel.fromJson(response));
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }

  @override
  Future<Result<List<WorkerJob>>> workerHistory({
    required String workerUserId,
  }) async {
    try {
      final response = await _remote.workerHistory(workerUserId: workerUserId);
      final rawJobs = (response['jobs'] as List<dynamic>? ?? const []);
      final jobs = rawJobs
          .whereType<Map<String, dynamic>>()
          .map(WorkerJobModel.fromJson)
          .toList(growable: false);
      return Success(jobs);
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }

  @override
  Future<Result<List<WorkerCategory>>> categories() async {
    try {
      final response = await _remote.categories();
      final rawCategories =
          (response['categories'] as List<dynamic>? ?? const []);
      final categories = rawCategories
          .whereType<Map<String, dynamic>>()
          .map(WorkerCategoryModel.fromJson)
          .where((category) => category.name.trim().isNotEmpty)
          .toList(growable: false);
      return Success(categories);
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }

  @override
  Future<Result<WorkerCategory>> createCategory({required String name}) async {
    try {
      final response = await _remote.createCategory(name: name);
      final categoryMap = response['category'] as Map<String, dynamic>?;
      final category = WorkerCategoryModel.fromJson(
        categoryMap ?? <String, dynamic>{'name': name.trim()},
      );
      return Success(category);
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }

  @override
  Future<Result<void>> uploadProfilePhoto({
    required String userId,
    String? imageUrl,
    String? imagePublicId,
  }) async {
    try {
      await _remote.uploadProfilePhoto(
        userId: userId,
        imageUrl: imageUrl,
        imagePublicId: imagePublicId,
      );
      return const Success(null);
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }

  @override
  Future<Result<void>> deleteProfilePhoto({required String userId}) async {
    try {
      await _remote.deleteProfilePhoto(userId: userId);
      return const Success(null);
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }

  @override
  Future<Result<void>> updateWorkerLocation({
    required String workerUserId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _remote.updateWorkerLocation(
        workerUserId: workerUserId,
        latitude: latitude,
        longitude: longitude,
      );
      return const Success(null);
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }
}
