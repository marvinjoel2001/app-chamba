import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/features/worker/domain/entities/worker_availability.dart';
import 'package:mobile/features/worker/domain/entities/worker_category.dart';
import 'package:mobile/features/worker/domain/entities/worker_job.dart';
import 'package:mobile/features/worker/domain/entities/worker_radar_summary.dart';
import 'package:mobile/features/worker/domain/entities/worker_skill.dart';
import 'package:mobile/features/worker/domain/repositories/worker_repository.dart';
import 'package:mobile/features/worker/domain/usecases/worker_usecases.dart';

class _FakeWorkerRepository implements WorkerRepository {
  Result<List<WorkerJob>> historyResult;
  Result<WorkerAvailability> availabilityResult;
  Result<WorkerCategory> categoryResult;

  String? lastWorkerUserId;
  bool? lastAvailable;
  String? lastCategoryName;

  _FakeWorkerRepository({
    required this.historyResult,
    required this.availabilityResult,
    required this.categoryResult,
  });

  @override
  Future<Result<List<WorkerJob>>> workerHistory({
    required String workerUserId,
  }) async {
    lastWorkerUserId = workerUserId;
    return historyResult;
  }

  @override
  Future<Result<WorkerAvailability>> setAvailability({
    required String workerUserId,
    required bool available,
  }) async {
    lastWorkerUserId = workerUserId;
    lastAvailable = available;
    return availabilityResult;
  }

  @override
  Future<Result<WorkerCategory>> createCategory({required String name}) async {
    lastCategoryName = name;
    return categoryResult;
  }

  @override
  Future<Result<List<WorkerCategory>>> categories() async =>
      const Success(<WorkerCategory>[]);

  @override
  Future<Result<void>> deleteProfilePhoto({required String userId}) async =>
      const Success(null);

  @override
  Future<Result<void>> updateWorkerLocation({
    required String workerUserId,
    required double latitude,
    required double longitude,
  }) async => const Success(null);

  @override
  Future<Result<List<WorkerSkill>>> updateWorkerSkills({
    required String workerUserId,
    required List<String> skills,
  }) async => const Success(<WorkerSkill>[]);

  @override
  Future<Result<void>> uploadProfilePhoto({
    required String userId,
    String? imageUrl,
    String? imagePublicId,
  }) async => const Success(null);

  @override
  Future<Result<WorkerRadarSummary>> workerRadar({
    required String workerUserId,
  }) async => const Success(
    WorkerRadarSummary(
      jobsToday: 0,
      earningsToday: 0,
      nearbyRequests: 0,
      available: true,
      workRadiusKm: 5,
    ),
  );

  @override
  Future<Result<List<WorkerSkill>>> workerSkills({
    required String workerUserId,
  }) async => const Success(<WorkerSkill>[]);
}

void main() {
  test('GetWorkerHistoryUseCase returns typed jobs', () async {
    final repo = _FakeWorkerRepository(
      historyResult: const Success(<WorkerJob>[]),
      availabilityResult: const Success(WorkerAvailability(available: true)),
      categoryResult: const Success(WorkerCategory(name: 'Plomeria')),
    );
    final usecase = GetWorkerHistoryUseCase(repo);

    final result = await usecase(workerUserId: 'worker-1');

    expect(repo.lastWorkerUserId, 'worker-1');
    expect(result, isA<Success<List<WorkerJob>>>());
  });

  test('SetWorkerAvailabilityUseCase sends expected params', () async {
    final repo = _FakeWorkerRepository(
      historyResult: const Success(<WorkerJob>[]),
      availabilityResult: const Success(WorkerAvailability(available: false)),
      categoryResult: const Success(WorkerCategory(name: 'Plomeria')),
    );
    final usecase = SetWorkerAvailabilityUseCase(repo);

    final result = await usecase(workerUserId: 'worker-2', available: false);

    expect(repo.lastWorkerUserId, 'worker-2');
    expect(repo.lastAvailable, isFalse);
    expect(result, isA<Success<WorkerAvailability>>());
  });

  test('CreateWorkerCategoryUseCase propagates failure', () async {
    final repo = _FakeWorkerRepository(
      historyResult: const Success(<WorkerJob>[]),
      availabilityResult: const Success(WorkerAvailability(available: true)),
      categoryResult: const Error(ValidationFailure('Nombre inválido')),
    );
    final usecase = CreateWorkerCategoryUseCase(repo);

    final result = await usecase(name: '');

    expect(repo.lastCategoryName, '');
    expect(result, isA<Error<WorkerCategory>>());
  });
}
