import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../../../features/offers/presentation/screens/offers_screen.dart';

class RequestStatusScreen extends StatelessWidget {
  const RequestStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                const ChambaBackground(showGrid: true, child: SizedBox.expand()),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Estado del Pedido',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.help_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          GlassCard(
            borderRadius: 28,
            child: Column(
              children: [
                Container(
                  width: 74,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 38,
                  backgroundColor: AppTheme.colorPrimary.withValues(alpha: 0.25),
                  child: const Icon(Icons.radar, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 18),
                Text(
                  'Buscando trabajadores...',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Estamos conectando con los mejores perfiles cerca de ti',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.colorMuted,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: const [
                    Expanded(
                      child: _MetricCard(value: '3', label: 'Notificados'),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(value: '~5 min', label: 'Tiempo est.'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.colorPrimary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 16),
                      SizedBox(width: 8),
                      Text('Recibiras una notificacion cuando alguien acepte'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar solicitud'),
                ),
                const SizedBox(height: 8),
                ChambaPrimaryButton(
                  label: 'Ver ofertas demo',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const OffersScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.colorPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(label, style: const TextStyle(color: AppTheme.colorMuted)),
        ],
      ),
    );
  }
}
