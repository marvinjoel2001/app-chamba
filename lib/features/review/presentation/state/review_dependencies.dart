import '../../data/datasources/review_remote_datasource.dart';
import '../../data/repositories/review_repository_impl.dart';
import '../../domain/usecases/review_usecases.dart';

class ReviewDependencies {
  ReviewDependencies._();

  static final _repository = ReviewRepositoryImpl(
    const ReviewRemoteDataSourceImpl(),
  );

  static final getOffers = GetReviewOffersUseCase(_repository);
  static final createReview = CreateReviewUseCase(_repository);
}
