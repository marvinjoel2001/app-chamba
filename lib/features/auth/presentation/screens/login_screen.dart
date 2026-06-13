import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/services/mobile_backend_service.dart';
import 'google_account_type_screen.dart';

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

  Future<void> _continueWithGoogle() async {
    setState(() => _checkingIdentifier = true);
    try {
      final googleSignIn = GoogleSignIn();
      final account = await googleSignIn.signIn();
      if (account == null) {
        setState(() => _checkingIdentifier = false);
        return;
      }
      
      final auth = await account.authentication;
      if (auth.idToken == null) {
        throw Exception('No se pudo obtener el token de Google');
      }

      final result = await MobileBackendService.instance.loginWithGoogle(idToken: auth.idToken!);
      
      if (result['requiresRegistration'] == true) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GoogleAccountTypeScreen(
              googleData: result['googleData'],
            ),
          ),
        );
      } else {
        final userData = result['user'] as Map<String, dynamic>;

        await SessionStore.setCurrentUser(SessionUser.fromJson(userData));

        if (!mounted) return;
        _handleAuthenticated();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _checkingIdentifier = false);
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
                                  onPressed: _checkingIdentifier || authState.isLoading
                                      ? null
                                      : _continueWithGoogle,
                                  icon: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: SvgPicture.string(
                                        '''<svg xmlns="http://www.w3.org/2000/svg" x="0px" y="0px" width="100" height="100" viewBox="0 0 48 48">
<path fill="#FFC107" d="M43.611,20.083H42V20H24v8h11.303c-1.649,4.657-6.08,8-11.303,8c-6.627,0-12-5.373-12-12c0-6.627,5.373-12,12-12c3.059,0,5.842,1.154,7.961,3.039l5.657-5.657C34.046,6.053,29.268,4,24,4C12.955,4,4,12.955,4,24c0,11.045,8.955,20,20,20c11.045,0,20-8.955,20-20C44,22.659,43.862,21.35,43.611,20.083z"></path><path fill="#FF3D00" d="M6.306,14.691l6.571,4.819C14.655,15.108,18.961,12,24,12c3.059,0,5.842,1.154,7.961,3.039l5.657-5.657C34.046,6.053,29.268,4,24,4C16.318,4,9.656,8.337,6.306,14.691z"></path><path fill="#4CAF50" d="M24,44c5.166,0,9.86-1.977,13.409-5.192l-6.19-5.238C29.211,35.091,26.715,36,24,36c-5.202,0-9.619-3.317-11.283-7.946l-6.522,5.025C9.505,39.556,16.227,44,24,44z"></path><path fill="#1976D2" d="M43.611,20.083H42V20H24v8h11.303c-0.792,2.237-2.231,4.166-4.087,5.571c0.001-0.001,0.002-0.001,0.003-0.002l6.19,5.238C36.971,39.205,44,34,44,24C44,22.659,43.862,21.35,43.611,20.083z"></path>
</svg>''',
                                        width: 18,
                                        height: 18,
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
