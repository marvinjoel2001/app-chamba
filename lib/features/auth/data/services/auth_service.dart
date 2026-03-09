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

  Future<void> logout() async {
    SessionStore.clear();
  }
}
