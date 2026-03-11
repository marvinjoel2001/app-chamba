import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../../core/network/realtime_service.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';
import '../../../shell/presentation/screens/main_shell_screen.dart';
import '../../../worker/presentation/screens/skills_selection_screen.dart';
import 'role_selection_screen.dart';

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
        MaterialPageRoute<void>(builder: (_) => const RoleSelectionScreen()),
      );
      return;
    }

    RealtimeService.instance.connect(userId: user.id);

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
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const SkillsSelectionScreen(forceToHomeAfterSave: true),
            ),
          );
          return;
        }
      } catch (_) {}
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => MainShellScreen(role: user.type)),
    );
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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.colorPrimary.withValues(alpha: 0.35),
                      width: 8,
                    ),
                  ),
                  child: const CircleAvatar(
                    backgroundColor: AppTheme.colorSurfaceSoft,
                    child: Icon(
                      Icons.handshake,
                      size: 84,
                      color: AppTheme.colorHighlight,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Chamba',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'CONNECTING OPPORTUNITIES',
                  style: TextStyle(
                    color: AppTheme.colorPrimary,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Text(
                      'Initializing...',
                      style: TextStyle(fontSize: 20),
                    ),
                    const Spacer(),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progress,
                  color: AppTheme.colorPrimary,
                  backgroundColor: AppTheme.colorPrimary.withValues(
                    alpha: 0.25,
                  ),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
