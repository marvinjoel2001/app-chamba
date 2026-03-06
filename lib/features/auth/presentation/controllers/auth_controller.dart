import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/realtime_service.dart';
import '../../data/services/auth_service.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(
    baseUrl: AppConfig.apiBaseUrl,
    client: ref.watch(httpClientProvider),
  );
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(apiServiceProvider));
});

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService();
  ref.onDispose(service.dispose);
  return service;
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authServiceProvider));
});

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

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._authService) : super(const AuthState());

  final AuthService _authService;

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _authService.login(email: email.trim(), password: password);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _authService.logout();
    state = const AuthState();
  }
}
