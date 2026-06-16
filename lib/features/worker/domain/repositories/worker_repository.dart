import '../../../../core/errors/result.dart';
import '../entities/worker_availability.dart';
import '../entities/worker_category.dart';
import '../entities/worker_job.dart';
import '../entities/worker_modalities.dart';
import '../entities/worker_radar_summary.dart';
import '../entities/worker_skill.dart';

abstract class WorkerRepository {
  Future<Result<WorkerRadarSummary>> workerRadar({
    required String workerUserId,
  });

  Future<Result<WorkerAvailability>> setAvailability({
    required String workerUserId,
    required bool available,
  });

  Future<Result<List<WorkerSkill>>> workerSkills({
    required String workerUserId,
  });

  Future<Result<List<WorkerSkill>>> updateWorkerSkills({
    required String workerUserId,
    required List<String> skills,
  });

  Future<Result<WorkerModalities>> workerModalities({
    required String workerUserId,
  });

  Future<Result<WorkerModalities>> updateWorkerModalities({
    required String workerUserId,
    required List<String> modalities,
    double? hourlyRate,
    double? dailyRate,
  });

  Future<Result<List<WorkerJob>>> workerHistory({required String workerUserId});

  Future<Result<List<WorkerCategory>>> categories();

  Future<Result<WorkerCategory>> createCategory({required String name});

  Future<Result<void>> uploadProfilePhoto({
    required String userId,
    String? imageUrl,
    String? imagePublicId,
  });

  Future<Result<void>> deleteProfilePhoto({required String userId});

  Future<Result<void>> updateWorkerLocation({
    required String workerUserId,
    required double latitude,
    required double longitude,
  });
}
