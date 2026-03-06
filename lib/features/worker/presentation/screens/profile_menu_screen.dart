import 'package:flutter/material.dart';

import '../../../../core/widgets/chamba_widgets.dart';
import '../../../request/presentation/screens/empty_requests_screen.dart';
import '../../../review/presentation/screens/rating_screen.dart';
import '../../../tracking/presentation/screens/tracking_screen.dart';
import 'radar_screen.dart';
import 'skills_selection_screen.dart';

class ProfileMenuScreen extends StatelessWidget {
  const ProfileMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Perfil y demos',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              const GlassCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(
                        'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
                      ),
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mario Guzman', style: TextStyle(fontSize: 22)),
                        Text('Worker verified'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _NavTile(
                title: 'Radar de trabajo',
                subtitle: 'Toggle disponible/no disponible + mapa',
                icon: Icons.radar,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const RadarScreen()),
                  );
                },
              ),
              _NavTile(
                title: 'Seleccion de habilidades',
                subtitle: 'Paso de onboarding del trabajador',
                icon: Icons.grid_view_rounded,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SkillsSelectionScreen(),
                    ),
                  );
                },
              ),
              _NavTile(
                title: 'Rastreo de servicio',
                subtitle: 'Tracking de llegada + acciones',
                icon: Icons.location_searching,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const TrackingScreen()),
                  );
                },
              ),
              _NavTile(
                title: 'Estado sin solicitudes',
                subtitle: 'Vista vacia + refresh',
                icon: Icons.inbox_outlined,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EmptyRequestsScreen(),
                    ),
                  );
                },
              ),
              _NavTile(
                title: 'Calificacion final',
                subtitle: 'Rating con estrellas y comentario',
                icon: Icons.star_rate,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const RatingScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
