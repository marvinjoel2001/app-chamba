import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/realtime_service.dart';
import '../../../../core/services/app_permissions_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../shell/presentation/screens/main_shell_screen.dart';
import '../../../worker/presentation/state/worker_dependencies.dart';
import '../../../worker/presentation/screens/skills_selection_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/screens/blocked_screen.dart';
import 'required_permissions_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double progress = 0.1;
  Timer? timer;
  String _statusText = 'Cargando...';
  bool _isSlowBackend = false;
  bool _resolving = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    // Arranque rápido: la barra se llena en ~1 segundo y se resuelve la ruta.
    // Si el backend tarda (p. ej. servidor dormido), la barra sigue avanzando
    // lento y se informa al usuario, pero no se bloquea el arranque normal.
    timer = Timer.periodic(const Duration(milliseconds: 120), (tick) {
      if (!mounted) return;
      final elapsedMs = DateTime.now().difference(_startTime!).inMilliseconds;

      setState(() {
        if (!_resolving) {
          progress = (progress + 0.12).clamp(0.0, 0.9);
        } else {
          progress = (progress + 0.01).clamp(0.0, 0.95);
          if (elapsedMs > 9000 && !_isSlowBackend) {
            _isSlowBackend = true;
            _statusText = 'El servidor está despertando...';
          } else if (elapsedMs > 3500 && !_isSlowBackend) {
            _statusText = 'Conectando con el servidor...';
          }
        }
      });

      if (!_resolving && progress >= 0.9 && elapsedMs >= 900) {
        _resolving = true;
        _resolveInitialRoute();
      }
    });
  }

  Future<void> _resolveInitialRoute() async {
    await SessionStore.hydrate();

    if (!mounted) {
      return;
    }

    final user = SessionStore.currentUser;
    if (user == null) {
      _go(const LoginScreen());
      return;
    }

    if (user.isBlocked) {
      _go(const BlockedScreen());
      return;
    }

    RealtimeService.instance.connect(userId: user.id);

    Widget nextScreen = MainShellScreen(role: user.type);

    if (user.type == 'worker') {
      final result = await WorkerDependencies.getWorkerSkills(
        workerUserId: user.id,
      );
      var shouldOpenSkills = false;
      result.fold(
        onSuccess: (skills) {
          shouldOpenSkills = skills.isEmpty;
        },
        onFailure: (_) {},
      );
      if (!mounted) {
        return;
      }
      if (shouldOpenSkills) {
        nextScreen = const SkillsSelectionScreen(forceToHomeAfterSave: true);
      }
    }

    if (!mounted) {
      return;
    }

    final allPermissionsGranted =
        await AppPermissionsService.areAllRequiredPermissionsGranted(user.type);
    if (!mounted) {
      return;
    }
    if (!allPermissionsGranted) {
      nextScreen = RequiredPermissionsScreen(role: user.type, nextScreen: nextScreen);
    }

    _go(nextScreen);
  }

  void _go(Widget screen) {
    timer?.cancel();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/backgrounds/backgroundSplash.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.colorPrimary.withValues(alpha: 0.5),
                          blurRadius: 50,
                          spreadRadius: 15,
                        ),
                      ],
                    ),
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.colorGlassDarkSoft,
                      ),
                      padding: const EdgeInsets.all(28),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/icon/icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Chamba',
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
                  const Spacer(),
                  SizedBox(
                    width: 220,
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: progress,
                          color: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        const SizedBox(height: 20),
                        AnimatedOpacity(
                          opacity: progress > 0.1 ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Column(
                            children: [
                              Text(
                                _statusText,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      letterSpacing: 1.2,
                                    ),
                              ),
                              if (_isSlowBackend) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Esto puede tomar hasta 30 segundos',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppTheme.colorHighlight
                                            .withOpacity(0.8),
                                        fontSize: 11,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
