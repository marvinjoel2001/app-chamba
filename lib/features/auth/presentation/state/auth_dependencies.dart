import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/usecases/auth_usecases.dart';

class AuthDependencies {
  AuthDependencies._();

  static final _repository = AuthRepositoryImpl(
    const AuthRemoteDataSourceImpl(),
  );

  static final login = LoginUseCase(_repository);
  static final checkIdentifier = CheckIdentifierUseCase(_repository);
  static final register = RegisterUseCase(_repository);
  static final logout = LogoutUseCase(_repository);
}
