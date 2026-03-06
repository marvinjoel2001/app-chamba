import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';

class EmptyRequestsScreen extends StatelessWidget {
  const EmptyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const Spacer(),
                    Text(
                      'Chamba',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 30),
                const GlassCard(
                  child: SizedBox(
                    height: 260,
                    child: Center(
                      child: Icon(
                        Icons.nightlight_round,
                        size: 120,
                        color: AppTheme.colorPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'No hay solicitudes\ncerca aun',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Parece que todo esta tranquilo por ahora. Te avisaremos en cuanto aparezca una nueva oportunidad cerca de ti.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.colorMuted,
                  ),
                ),
                const Spacer(),
                ChambaPrimaryButton(
                  label: 'Actualizar busqueda',
                  icon: Icons.refresh,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Busqueda actualizada')),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
