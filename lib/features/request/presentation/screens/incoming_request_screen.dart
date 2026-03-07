import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../offers/presentation/screens/counter_offer_screen.dart';

class IncomingRequestScreen extends StatelessWidget {
  const IncomingRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                      const Spacer(),
                      const Text(
                        'NUEVA SOLICITUD ENTRANTE',
                        style: TextStyle(
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.colorMuted,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 22),
                  CircleAvatar(
                    radius: 80,
                    backgroundColor: AppTheme.colorHighlight.withValues(alpha: 0.22),
                    child: const Icon(
                      Icons.format_paint,
                      size: 62,
                      color: AppTheme.colorHighlight,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFFFFE4E3),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'URGENTE',
                        style: TextStyle(
                          color: Color(0xFF8C2622),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Buscan un pintor',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A 2.1 km de tu ubicacion',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.colorMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Column(
                      children: [
                        const Text(
                          'PRESUPUESTO OFRECIDO',
                          style: TextStyle(
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.colorMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Bs 100/dia',
                          style:
                              Theme.of(context).textTheme.displayMedium?.copyWith(
                                    color: AppTheme.colorHighlight,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 10),
                        ChambaChip(label: 'Hoy, 14:00 PM', selected: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Se requiere pintor con experiencia para retoques en fachada de vivienda unifamiliar.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 22),
                  ChambaPrimaryButton(
                    label: 'ACEPTAR PRECIO',
                    icon: Icons.check_circle,
                    isYellow: true,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Precio aceptado')),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ChambaPrimaryButton(
                    label: 'OFERTAR MI PRECIO',
                    icon: Icons.payments,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CounterOfferScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('No me interesa'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

