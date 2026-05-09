import 'dart:async';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../../core/push/push_notification_service.dart';
import '../../../../core/session/session_store.dart';
import '../../domain/entities/auth_payload_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_payload_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);

  final AuthRemoteDataSource _remote;

  @override
  Future<Result<AuthPayloadEntity>> login({
    required String identifier,
    required String password,
  }) async {
    if (identifier.trim().isEmpty || password.trim().isEmpty) {
      return const Error(
        ValidationFailure('Correo/teléfono y contraseña son obligatorios.'),
      );
    }

    try {
      final response = await _remote.login(
        identifier: identifier.trim(),
        password: password.trim(),
      );

      final userJson = response['user'];
      if (userJson is! Map<String, dynamic>) {
        return const Error(ServerFailure('Respuesta de login invalida.'));
      }

      await SessionStore.setCurrentUser(SessionUser.fromJson(userJson));
      unawaited(_syncPushTokenBestEffort());
      return Success(AuthPayloadModel.fromJson(response));
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }

  @override
  Future<Result<AuthPayloadEntity>> checkIdentifier({
    required String identifier,
  }) async {
    if (identifier.trim().isEmpty) {
      return const Error(ValidationFailure('Ingresa tu correo o teléfono.'));
    }

    try {
      final response = await _remote.checkIdentifier(
        identifier: identifier.trim(),
      );
      final exists = response['exists'] == true;
      if (!exists) {
        return const Error(
          ValidationFailure(
            'No encontramos una cuenta con ese correo o teléfono.',
          ),
        );
      }
      return Success(AuthPayloadModel.fromJson(response));
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }

  @override
  Future<Result<AuthPayloadEntity>> register({
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
      return const Error(
        ValidationFailure('Nombre, correo y contraseña son obligatorios.'),
      );
    }

    try {
      final response = await _remote.register(
        role: role.trim(),
        email: email.trim(),
        phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
        firstName: firstName.trim(),
        lastName: lastName?.trim().isEmpty == true ? null : lastName?.trim(),
        password: password.trim(),
      );

      final userJson = response['user'];
      if (userJson is! Map<String, dynamic>) {
        return const Error(ServerFailure('Respuesta de registro invalida.'));
      }

      await SessionStore.setCurrentUser(SessionUser.fromJson(userJson));
      unawaited(_syncPushTokenBestEffort());
      return Success(AuthPayloadModel.fromJson(response));
    } catch (error) {
      return Error(mapToFailure(error));
    }
  }

  @override
  Future<Result<void>> logout() async {
    RealtimeService.instance.dispose();
    await SessionStore.clear();
    return const Success(null);
  }

  Future<void> _syncPushTokenBestEffort() async {
    try {
      await const PushNotificationService().syncTokenForCurrentUser().timeout(
        const Duration(seconds: 6),
      );
    } catch (_) {}
  }
}
