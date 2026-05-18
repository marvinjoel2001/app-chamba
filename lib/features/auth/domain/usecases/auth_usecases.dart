import '../../../../core/errors/result.dart';
import '../entities/auth_payload_entity.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthPayloadEntity>> call({
    required String identifier,
    required String password,
  }) {
    return _repository.login(identifier: identifier, password: password);
  }
}

class CheckIdentifierUseCase {
  CheckIdentifierUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthPayloadEntity>> call({required String identifier}) {
    return _repository.checkIdentifier(identifier: identifier);
  }
}

class RegisterUseCase {
  RegisterUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthPayloadEntity>> call({
    required String role,
    required String email,
    String? phone,
    String? countryCode,
    String? ciNumber,
    required String firstName,
    String? lastName,
    required String password,
  }) {
    return _repository.register(
      role: role,
      email: email,
      phone: phone,
      countryCode: countryCode,
      ciNumber: ciNumber,
      firstName: firstName,
      lastName: lastName,
      password: password,
    );
  }
}

class LogoutUseCase {
  LogoutUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call() {
    return _repository.logout();
  }
}
