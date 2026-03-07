import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  bool available = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.menu),
                  ),
                  const Spacer(),
                  Text(
                    'Radar de Trabajo',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GlassCard(
                borderRadius: 36,
                child: Row(
                  children: [
                    Expanded(
                      child: ChambaChip(
                        label: 'DISPONIBLE',
                        selected: available,
                        onTap: () => setState(() => available = true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChambaChip(
                        label: 'NO DISPONIBLE',
                        selected: !available,
                        onTap: () => setState(() => available = false),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 6,
                    backgroundColor: available
                        ? AppTheme.colorHighlight
                        : AppTheme.colorMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    available
                        ? 'Estas activo, recibiendo solicitudes'
                        : 'Estas pausado temporalmente',
                    style: const TextStyle(color: AppTheme.colorMuted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: SizedBox(
                  height: 420,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: AppTheme.colorSurfaceSoft,
                        ),
                      ),
                      Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.colorPrimary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                      ),
                      Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.colorPrimary.withValues(alpha: 0.55),
                            width: 2,
                          ),
                        ),
                      ),
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppTheme.colorPrimary,
                        child: const Icon(Icons.location_pin, size: 30),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.small(
                          backgroundColor: AppTheme.colorSurfaceSoft,
                          onPressed: () {},
                          child: const Icon(Icons.my_location, color: AppTheme.colorPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'Resumen de Hoy',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Ver detalle'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: _SummaryCard(
                      icon: Icons.work,
                      title: 'TRABAJOS',
                      value: '12',
                      subtitle: '+2 vs ayer',
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: _SummaryCard(
                      icon: Icons.paid,
                      title: 'GANANCIAS',
                      value: '\$1,420',
                      subtitle: 'Sueldo neto',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.colorHighlight),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: AppTheme.colorMuted)),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF25D366))),
        ],
      ),
    );
  }
}

