import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/auth_dependencies.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthState {
  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isAuthenticated;
  final String? errorMessage;

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState();
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await AuthDependencies.login(
      identifier: identifier.trim(),
      password: password,
    );

    result.fold(
      onSuccess: (_) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          clearError: true,
        );
      },
      onFailure: (failure) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          errorMessage: failure.message,
        );
      },
    );
  }

  Future<void> register({
    required String role,
    required String email,
    String? phone,
    required String firstName,
    String? lastName,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await AuthDependencies.register(
      role: role,
      email: email.trim(),
      phone: phone,
      firstName: firstName.trim(),
      lastName: lastName?.trim(),
      password: password,
    );

    result.fold(
      onSuccess: (_) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          clearError: true,
        );
      },
      onFailure: (failure) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          errorMessage: failure.message,
        );
      },
    );
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await AuthDependencies.logout();
    state = const AuthState();
  }
}
