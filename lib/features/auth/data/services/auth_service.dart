import '../../../../core/session/session_store.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';

class AuthService {
  Future<void> login({required String email, required String password}) async {
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Correo/telefono y clave son obligatorios.');
    }

    final response = await MobileBackendService.login(
      identifier: email.trim(),
      password: password.trim(),
    );

    final userJson = response['user'];
    if (userJson is! Map<String, dynamic>) {
      throw Exception('Respuesta de login invalida.');
    }

    SessionStore.currentUser = SessionUser.fromJson(userJson);
  }

  Future<void> register({
    required String role,
    required String email,
    String? phone,
    required String firstName,
    String? lastName,
    required String password,
  }) async {
    if (email.trim().isEmpty ||
        firstName.trim().isEmpty ||
        password.trim().isEmpty) {
      throw Exception('Nombre, correo y clave son obligatorios.');
    }

    final response = await MobileBackendService.register(
      type: role.trim(),
      email: email.trim(),
      phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
      firstName: firstName.trim(),
      lastName: lastName?.trim().isEmpty == true ? null : lastName?.trim(),
      password: password.trim(),
    );

    final userJson = response['user'];
    if (userJson is! Map<String, dynamic>) {
      throw Exception('Respuesta de registro invalida.');
    }

    SessionStore.currentUser = SessionUser.fromJson(userJson);
  }

  Future<void> logout() async {
    SessionStore.clear();
  }
}
