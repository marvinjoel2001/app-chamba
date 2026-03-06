import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int stars = 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Center(
              child: GlassCard(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        width: 74,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const CircleAvatar(
                        radius: 58,
                        backgroundImage: NetworkImage(
                          'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Como fue tu Chamba?',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tu opinion ayuda a mejorar la comunidad y califica el desempeno del trabajador.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.colorMuted,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final selected = index < stars;
                          return IconButton(
                            onPressed: () => setState(() => stars = index + 1),
                            icon: Icon(
                              Icons.star,
                              size: 46,
                              color: selected
                                  ? AppTheme.colorHighlight
                                  : const Color(0xFF334566),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 14),
                      const TextField(
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Escribe aqui tu experiencia con el servicio...',
                        ),
                      ),
                      const SizedBox(height: 18),
                      ChambaPrimaryButton(
                        label: 'CALIFICAR',
                        isYellow: true,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Calificacion enviada: $stars estrellas')),
                          );
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Omitir por ahora'),
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
