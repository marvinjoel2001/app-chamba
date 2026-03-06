import '../../../../core/network/api_service.dart';

class AuthService {
  AuthService(this._apiService);

  final ApiService _apiService;

  Future<void> login({required String email, required String password}) async {
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Correo/telefono y clave son obligatorios.');
    }

    // Placeholder integration point for backend authentication.
    // Current fake login keeps UI flow active until OTP endpoint is added.
    // Example target API:
    // await _apiService.post('/auth/otp/request', body: {'phone': email});

    await Future<void>.delayed(const Duration(milliseconds: 450));
  }

  Future<void> logout() async {
    // Placeholder integration point for backend logout/session revoke.
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  ApiService get apiService => _apiService;
}
