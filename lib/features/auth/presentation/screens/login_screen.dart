import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/realtime_service.dart';
import '../../../../core/services/app_permissions_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../onboarding/presentation/screens/required_permissions_screen.dart';
import '../../../shell/presentation/screens/main_shell_screen.dart';
import '../state/auth_dependencies.dart';
import '../../../worker/presentation/state/worker_dependencies.dart';
import '../../../worker/presentation/screens/skills_selection_screen.dart';
import '../controllers/auth_controller.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _identifierVerified = false;
  bool _checkingIdentifier = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthenticated() async {
    final user = SessionStore.currentUser;
    if (user == null || !mounted) {
      return;
    }

    Widget nextScreen = MainShellScreen(
      role: SessionStore.currentUser?.type ?? 'client',
    );

    if (user.type == 'worker') {
      final result = await WorkerDependencies.getWorkerSkills(
        workerUserId: user.id,
      );
      result.fold(
        onSuccess: (skills) {
          if (skills.isEmpty) {
            nextScreen = const SkillsSelectionScreen(
              forceToHomeAfterSave: true,
            );
          }
        },
        onFailure: (_) {},
      );
    }

    if (!mounted) return;

    RealtimeService.instance.connect(userId: user.id);

    final allPermissionsGranted =
        await AppPermissionsService.areAllRequiredPermissionsGranted(user.type);
    if (!mounted) return;

    final destination = allPermissionsGranted
        ? nextScreen
        : RequiredPermissionsScreen(role: user.type, nextScreen: nextScreen);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => destination),
      (route) => false,
    );
  }

  Future<void> _continueWithIdentifier() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _checkingIdentifier = true;
    });

    final result = await AuthDependencies.checkIdentifier(
      identifier: _identifierController.text,
    );
    result.fold(
      onSuccess: (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _identifierVerified = true;
        });
      },
      onFailure: (failure) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
    if (mounted) {
      setState(() {
        _checkingIdentifier = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage!.isNotEmpty &&
          previous?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }

      if (next.isAuthenticated && previous?.isAuthenticated != true) {
        _handleAuthenticated();
      }
    });

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/backgrounds/backgroundLogin.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icono redondo grande
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTheme.colorPrimary.withValues(alpha: 0.5),
                              blurRadius: 50,
                              spreadRadius: 15,
                            ),
                          ],
                        ),
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.colorGlassDarkSoft,
                          ),
                          padding: const EdgeInsets.all(24),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/icon/icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Título Chamba
                    Text(
                      'Chamba',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        shadows: [
                          BoxShadow(
                            color: AppTheme.colorPrimary.withValues(alpha: 0.6),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Subtítulo
                    Text(
                      'Conecta con clientes\ny oportunidades',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                            height: 1.3,
                          ),
                    ),
                    const SizedBox(height: 40),
                    // Card de login
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: AppTheme.glassContainerDecoration(),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Iniciar sesión',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(color: AppTheme.colorText),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _identifierVerified
                                      ? 'Ahora ingresa tu contraseña'
                                      : 'Ingresa tu teléfono o correo para continuar',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: AppTheme.colorMuted),
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _identifierController,
                                  enabled: !_identifierVerified &&
                                      !_checkingIdentifier,
                                  style: const TextStyle(
                                      color: AppTheme.colorText),
                                  decoration: AppTheme.glassInputDecoration(
                                    labelText: 'Correo o teléfono',
                                    icon: Icons.person_outline,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Ingresa tu correo o teléfono';
                                    }
                                    return null;
                                  },
                                ),
                                if (_identifierVerified) ...[
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    style: const TextStyle(
                                      color: AppTheme.colorText,
                                    ),
                                    decoration: AppTheme.glassInputDecoration(
                                      labelText: 'Contraseña',
                                      icon: Icons.lock_outline,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: AppTheme.colorMuted,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          });
                                        },
                                      ),
                                    ),
                                    validator: (value) {
                                      if (!_identifierVerified) {
                                        return null;
                                      }
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Ingresa tu contraseña';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                                const SizedBox(height: 20),
                                ChambaPrimaryButton(
                                  label: _checkingIdentifier
                                      ? 'Verificando...'
                                      : !_identifierVerified
                                          ? 'Siguiente'
                                          : authState.isLoading
                                              ? 'Ingresando...'
                                              : 'Entrar',
                                  onPressed: authState.isLoading ||
                                          _checkingIdentifier
                                      ? null
                                      : () async {
                                          if (!_formKey.currentState!
                                              .validate()) {
                                            return;
                                          }

                                          if (!_identifierVerified) {
                                            await _continueWithIdentifier();
                                            return;
                                          }

                                          await ref
                                              .read(authControllerProvider
                                                  .notifier)
                                              .login(
                                                identifier:
                                                    _identifierController.text,
                                                password:
                                                    _passwordController.text,
                                              );
                                        },
                                ),
                                const SizedBox(height: 16),
                                // Divider con "o"
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: AppTheme.colorMuted
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      child: Text(
                                        'o',
                                        style: TextStyle(
                                          color: AppTheme.colorMuted
                                              .withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: AppTheme.colorMuted
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Botón Google
                                OutlinedButton.icon(
                                  onPressed: () {
                                    // TODO: Implementar login con Google
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Login con Google próximamente')),
                                    );
                                  },
                                  icon: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'G',
                                        style: TextStyle(
                                          color: AppTheme.colorPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  label: const Text(
                                    'Continuar con Google',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: AppTheme.colorMuted
                                          .withValues(alpha: 0.3),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_identifierVerified)
                                  TextButton(
                                    onPressed: authState.isLoading
                                        ? null
                                        : () {
                                            setState(() {
                                              _identifierVerified = false;
                                              _passwordController.clear();
                                            });
                                          },
                                    child: const Text('Cambiar usuario'),
                                  ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const RegisterScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text('Crear cuenta'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
