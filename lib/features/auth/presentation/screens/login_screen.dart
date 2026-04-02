import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';
import '../../../shell/presentation/screens/main_shell_screen.dart';
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

    if (user.type == 'worker') {
      try {
        final result = await MobileBackendService.workerSkills(
          workerUserId: user.id,
        );
        final skills = (result['skills'] as List<dynamic>? ?? const []);
        if (!mounted) {
          return;
        }
        if (skills.isEmpty) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const SkillsSelectionScreen(forceToHomeAfterSave: true),
            ),
            (_) => false,
          );
          return;
        }
      } catch (_) {}
    }

    RealtimeService.instance.connect(userId: user.id);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) =>
            MainShellScreen(role: SessionStore.currentUser?.type ?? 'client'),
      ),
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

    try {
      await ref
          .read(authServiceProvider)
          .checkIdentifierExists(identifier: _identifierController.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _identifierVerified = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _checkingIdentifier = false;
        });
      }
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
      body: ChambaBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassContainerDecoration(),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 92,
                                height: 92,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.colorSurfaceSoft,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.colorPrimary.withValues(
                                      alpha: 0.24,
                                    ),
                                  ),
                                ),
                                child: Image.asset(
                                  'assets/images/branding/chamba_handshake_icon.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Iniciar sesión',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(color: AppTheme.colorText),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _identifierVerified
                                  ? 'Ahora ingresa tu contraseña'
                                  : 'Ingresa tu correo o teléfono para continuar',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppTheme.colorMuted),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _identifierController,
                              enabled:
                                  !_identifierVerified && !_checkingIdentifier,
                              style: const TextStyle(color: AppTheme.colorText),
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
                                obscureText: true,
                                style: const TextStyle(
                                  color: AppTheme.colorText,
                                ),
                                decoration: AppTheme.glassInputDecoration(
                                  labelText: 'Contraseña',
                                  icon: Icons.lock_outline,
                                ),
                                validator: (value) {
                                  if (!_identifierVerified) {
                                    return null;
                                  }
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Ingresa tu contraseña';
                                  }
                                  return null;
                                },
                              ),
                            ],
                            const SizedBox(height: 18),
                            ChambaPrimaryButton(
                              label: _checkingIdentifier
                                  ? 'Verificando...'
                                  : !_identifierVerified
                                  ? 'Siguiente'
                                  : authState.isLoading
                                  ? 'Ingresando...'
                                  : 'Entrar',
                              onPressed:
                                  authState.isLoading || _checkingIdentifier
                                  ? null
                                  : () async {
                                      if (!_formKey.currentState!.validate()) {
                                        return;
                                      }

                                      if (!_identifierVerified) {
                                        await _continueWithIdentifier();
                                        return;
                                      }

                                      await ref
                                          .read(authControllerProvider.notifier)
                                          .login(
                                            identifier:
                                                _identifierController.text,
                                            password: _passwordController.text,
                                          );
                                    },
                            ),
                            const SizedBox(height: 8),
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
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Volver'),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
