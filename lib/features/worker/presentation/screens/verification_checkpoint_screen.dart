import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../shell/presentation/screens/main_shell_screen.dart';
import 'identity_verification_screen.dart';

class VerificationCheckpointScreen extends StatelessWidget {
  const VerificationCheckpointScreen({this.isPending = false, super.key});

  final bool isPending;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPending ? Icons.search : Icons.verified_user_outlined,
                  size: 80,
                  color: isPending ? Colors.orange : AppTheme.colorPrimary,
                ),
                const SizedBox(height: 24),
                Text(
                  isPending ? 'Verificación en proceso' : 'Verificación de Identidad',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: isPending ? Colors.orange : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  isPending
                      ? 'Tu verificación se encuentra en proceso. Te notificaremos cuando sea aprobada.'
                      : 'Si quieres empezar a trabajar o agarrar trabajos, debes verificar tu identidad',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                if (isPending)
                  ChambaPrimaryButton(
                    label: 'Volver',
                    isYellow: true,
                    onPressed: () => Navigator.of(context).pop(),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute<void>(
                                builder: (_) => const MainShellScreen(role: 'worker'),
                              ),
                              (route) => false,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.white),
                          ),
                          child: Text(
                            'Omitir / Luego',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ChambaPrimaryButton(
                          label: 'Verificar ahora',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const IdentityVerificationScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
