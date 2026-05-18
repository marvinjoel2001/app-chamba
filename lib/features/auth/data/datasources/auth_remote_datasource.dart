import '../../../../core/services/mobile_backend_service.dart';

abstract class AuthRemoteDataSource {
  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  });

  Future<Map<String, dynamic>> checkIdentifier({required String identifier});

  Future<Map<String, dynamic>> register({
    required String role,
    required String email,
    String? phone,
    String? countryCode,
    String? ciNumber,
    required String firstName,
    String? lastName,
    required String password,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl();

  @override
  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) {
    return MobileBackendService.instance.login(
      identifier: identifier,
      password: password,
    );
  }

  @override
  Future<Map<String, dynamic>> checkIdentifier({required String identifier}) {
    return MobileBackendService.instance.checkIdentifier(identifier: identifier);
  }

  @override
  Future<Map<String, dynamic>> register({
    required String role,
    required String email,
    String? phone,
    String? countryCode,
    String? ciNumber,
    required String firstName,
    String? lastName,
    required String password,
  }) {
    return MobileBackendService.instance.register(
      type: role,
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
