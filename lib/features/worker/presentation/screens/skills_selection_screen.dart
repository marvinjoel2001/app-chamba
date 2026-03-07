import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';

class SkillsSelectionScreen extends StatefulWidget {
  const SkillsSelectionScreen({super.key});

  @override
  State<SkillsSelectionScreen> createState() => _SkillsSelectionScreenState();
}

class _SkillsSelectionScreenState extends State<SkillsSelectionScreen> {
  final Set<String> selected = {'Construccion', 'Plomeria'};

  final skills = const [
    ('Construccion', Icons.handyman),
    ('Electricidad', Icons.flash_on),
    ('Plomeria', Icons.plumbing),
    ('Jardineria', Icons.yard),
    ('Transporte', Icons.local_shipping),
    ('Limpieza', Icons.cleaning_services),
    ('Mecanica', Icons.work),
    ('Carpinteria', Icons.architecture),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const Spacer(),
                    Text(
                      'Perfil de Trabajador',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    const SizedBox(width: 42),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Paso 4 de 5',
                  style: TextStyle(color: AppTheme.colorMuted),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: 0.8,
                  backgroundColor: AppTheme.colorPrimary.withValues(alpha: 0.2),
                  color: AppTheme.colorPrimary,
                  borderRadius: BorderRadius.circular(20),
                  minHeight: 10,
                ),
                const SizedBox(height: 22),
                Text(
                  'En que eres bueno?',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Selecciona tus habilidades principales para recibir mejores ofertas de trabajo cerca de ti.',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.colorMuted,
                      ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    itemCount: skills.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemBuilder: (context, index) {
                      final (label, icon) = skills[index];
                      final isSelected = selected.contains(label);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selected.remove(label);
                            } else {
                              selected.add(label);
                            }
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.colorPrimary.withValues(alpha: 0.1) : AppTheme.colorSurfaceSoft,
                            borderRadius: BorderRadius.circular(34),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.colorPrimary
                                  : const Color(0xFFCBD4E9),
                              width: 2,
                            ),
                            boxShadow: isSelected
                                ? const [
                                    BoxShadow(
                                      color: Color(0x447A2BC4),
                                      blurRadius: 18,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Stack(
                            children: [
                              if (isSelected)
                                const Positioned(
                                  right: 10,
                                  top: 10,
                                  child: CircleAvatar(
                                    radius: 13,
                                    backgroundColor: AppTheme.colorHighlight,
                                    child: Icon(Icons.check, size: 16, color: Colors.black),
                                  ),
                                ),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: AppTheme.colorPrimary
                                          .withValues(alpha: 0.35),
                                      child: Icon(icon, size: 30),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                ChambaPrimaryButton(
                  label: 'Continuar',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Habilidades guardadas: ${selected.length}')),
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

