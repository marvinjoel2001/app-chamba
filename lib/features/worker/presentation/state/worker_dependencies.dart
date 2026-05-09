import '../../data/datasources/worker_remote_datasource.dart';
import '../../data/repositories/worker_repository_impl.dart';
import '../../domain/usecases/worker_usecases.dart';
import '../../../../core/services/mobile_backend_service.dart';

class WorkerDependencies {
  WorkerDependencies._();

  static final _repository = WorkerRepositoryImpl(
    const WorkerRemoteDataSourceImpl(MobileBackendService.instance),
  );

  static final getWorkerRadar = GetWorkerRadarUseCase(_repository);
  static final setWorkerAvailability = SetWorkerAvailabilityUseCase(
    _repository,
  );
  static final getWorkerSkills = GetWorkerSkillsUseCase(_repository);
  static final updateWorkerSkills = UpdateWorkerSkillsUseCase(_repository);
  static final getWorkerHistory = GetWorkerHistoryUseCase(_repository);
  static final getWorkerCategories = GetWorkerCategoriesUseCase(_repository);
  static final createWorkerCategory = CreateWorkerCategoryUseCase(_repository);
  static final uploadWorkerProfilePhoto = UploadWorkerProfilePhotoUseCase(
    _repository,
  );
  static final deleteWorkerProfilePhoto = DeleteWorkerProfilePhotoUseCase(
    _repository,
  );
  static final updateWorkerLocation = UpdateWorkerLocationUseCase(_repository);
}
