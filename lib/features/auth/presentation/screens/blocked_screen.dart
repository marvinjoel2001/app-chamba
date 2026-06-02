import 'package:flutter/material.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import 'login_screen.dart';

class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await SessionStore.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: GlassCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.block,
                        size: 80,
                        color: AppTheme.colorError,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Acceso Denegado',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tu cuenta ha sido bloqueada por un administrador. Si crees que esto es un error, por favor contacta a soporte.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.colorMuted,
                            ),
                      ),
                      const SizedBox(height: 32),
                      ChambaPrimaryButton(
                        label: 'VOLVER AL INICIO',
                        onPressed: () => _logout(context),
                      ),
                    ],
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
