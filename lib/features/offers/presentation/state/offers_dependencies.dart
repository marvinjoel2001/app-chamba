import '../../data/datasources/offers_remote_datasource.dart';
import '../../data/repositories/offers_repository_impl.dart';
import '../../domain/usecases/offers_usecases.dart';

class OffersDependencies {
  OffersDependencies._();

  static final _repository = OffersRepositoryImpl(
    const OffersRemoteDataSourceImpl(),
  );

  static final getOffers = GetOffersUseCase(_repository);
  static final getWorkerProfile = GetWorkerProfileUseCase(_repository);
  static final acceptOffer = AcceptOfferUseCase(_repository);
  static final counterOffer = CounterOfferUseCase(_repository);
}
