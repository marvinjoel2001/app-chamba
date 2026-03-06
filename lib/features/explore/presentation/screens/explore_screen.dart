import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../request/presentation/screens/request_form_screen.dart';
import '../../../request/presentation/screens/request_status_screen.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({required this.role, super.key});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const ChambaBackground(showGrid: true, child: SizedBox.expand()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0x33282A44),
                        child: Icon(Icons.work_history),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Chamba',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const Spacer(),
                      const CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(
                          'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const _MapDots(),
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 300,
            child: Column(
              children: const [
                _MapControl(icon: Icons.add),
                SizedBox(height: 12),
                _MapControl(icon: Icons.remove),
                SizedBox(height: 12),
                _MapControl(icon: Icons.navigation, highlighted: true),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GlassCard(
              borderRadius: 32,
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Que necesitas hoy? Ej: busco alguien...',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.colorHighlight,
                        child: IconButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RequestFormScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: const [
                        ChambaChip(label: 'Limpieza', selected: true),
                        SizedBox(width: 8),
                        ChambaChip(label: 'Plomeria', selected: false),
                        SizedBox(width: 8),
                        ChambaChip(label: 'Electricidad', selected: false),
                        SizedBox(width: 8),
                        ChambaChip(label: 'Pintura', selected: false),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChambaPrimaryButton(
                          label: role == 'worker'
                              ? 'Ver solicitudes'
                              : 'Estado solicitud',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RequestStatusScreen(),
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
        ],
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({required this.icon, this.highlighted = false});

  final IconData icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 30,
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      child: Icon(icon, color: highlighted ? AppTheme.colorHighlight : Colors.white),
    );
  }
}

class _MapDots extends StatelessWidget {
  const _MapDots();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 30,
          child: CircleAvatar(
            radius: 9,
            backgroundColor: AppTheme.colorPrimary.withValues(alpha: 0.6),
          ),
        ),
        Positioned(
          left: 180,
          top: 120,
          child: CircleAvatar(
            radius: 8,
            backgroundColor: AppTheme.colorPrimary.withValues(alpha: 0.55),
          ),
        ),
        Positioned(
          left: 60,
          top: 220,
          child: CircleAvatar(
            radius: 9,
            backgroundColor: AppTheme.colorPrimary.withValues(alpha: 0.6),
          ),
        ),
        Center(
          child: CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.colorHighlight,
            child: Icon(Icons.location_on, color: Colors.black.withValues(alpha: 0.7)),
          ),
        ),
      ],
    );
  }
}
