import '../../../../core/errors/result.dart';
import '../entities/auth_payload_entity.dart';

abstract class AuthRepository {
  Future<Result<AuthPayloadEntity>> login({
    required String identifier,
    required String password,
  });

  Future<Result<AuthPayloadEntity>> checkIdentifier({
    required String identifier,
  });

  Future<Result<AuthPayloadEntity>> register({
    required String role,
    required String email,
    String? phone,
    required String firstName,
    String? lastName,
    required String password,
  });

  Future<Result<void>> logout();
}
