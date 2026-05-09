import '../../data/datasources/explore_remote_datasource.dart';
import '../../data/repositories/explore_repository_impl.dart';
import '../../domain/usecases/explore_usecases.dart';

class ExploreDependencies {
  ExploreDependencies._();

  static final _repository = ExploreRepositoryImpl(
    const ExploreRemoteDataSourceImpl(),
  );

  static final explore = ExploreUseCase(_repository);
  static final previewRequestCategories = PreviewRequestCategoriesUseCase(
    _repository,
  );
}
