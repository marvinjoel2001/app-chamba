import 'dart:async';

import '../../../../core/session/session_store.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/push/push_notification_service.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';

class AuthService {
  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    if (identifier.isEmpty || password.isEmpty) {
      throw Exception('Correo/teléfono y contraseña son obligatorios.');
    }

    final response = await MobileBackendService.login(
      identifier: identifier.trim(),
      password: password.trim(),
    );

    final userJson = response['user'];
    if (userJson is! Map<String, dynamic>) {
      throw Exception('Respuesta de login invalida.');
    }

    await SessionStore.setCurrentUser(SessionUser.fromJson(userJson));
    unawaited(_syncPushTokenBestEffort());
  }

  Future<void> checkIdentifierExists({required String identifier}) async {
    if (identifier.trim().isEmpty) {
      throw Exception('Ingresa tu correo o teléfono.');
    }

    final response = await MobileBackendService.checkIdentifier(
      identifier: identifier.trim(),
    );

    final exists = response['exists'] == true;
    if (!exists) {
      throw Exception('No encontramos una cuenta con ese correo o teléfono.');
    }
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
      throw Exception('Nombre, correo y contraseña son obligatorios.');
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

    await SessionStore.setCurrentUser(SessionUser.fromJson(userJson));
    unawaited(_syncPushTokenBestEffort());
  }

  Future<void> logout() async {
    RealtimeService.instance.dispose();
    await SessionStore.clear();
  }

  Future<void> _syncPushTokenBestEffort() async {
    try {
      await const PushNotificationService().syncTokenForCurrentUser().timeout(
        const Duration(seconds: 6),
      );
    } catch (_) {}
  }
}
