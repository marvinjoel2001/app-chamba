import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/realtime_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../shell/presentation/screens/main_shell_screen.dart';
import '../../../worker/presentation/state/worker_dependencies.dart';
import '../../../worker/presentation/screens/skills_selection_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/screens/blocked_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double progress = 0.1;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 180), (tick) {
      setState(() {
        progress = (progress + 0.1).clamp(0.0, 1.0);
      });

      if (progress >= 1) {
        timer?.cancel();
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
      return;
    }

    if (user.isBlocked) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const BlockedScreen()),
      );
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

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => nextScreen));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
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
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: Container(
                      width: 150,
                      height: 150,
                      color: AppTheme.colorGlassDarkSoft,
                      padding: const EdgeInsets.all(24),
                      child: Image.asset(
                        'assets/images/icon/icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
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
                  width: 200,
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: progress,
                        color: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 16),
                      AnimatedOpacity(
                        opacity: progress > 0.1 ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          'Cargando...',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
