import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import 'request_form_screen.dart';

class RequestModalityScreen extends StatelessWidget {
  const RequestModalityScreen({
    required this.initialPrompt,
    this.initialTitle,
    this.suggestedCategories = const [],
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    this.preselectedCategory,
    this.preselectedWorkerId,
    super.key,
  });

  final String initialPrompt;
  final String? initialTitle;
  final List<Map<String, dynamic>> suggestedCategories;
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;
  final String? preselectedCategory;
  final String? preselectedWorkerId;

  void _selectModality(BuildContext context, String modality) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RequestFormScreen(
          modality: modality,
          initialPrompt: initialPrompt,
          initialTitle: initialTitle,
          suggestedCategories: suggestedCategories,
          initialLatitude: initialLatitude,
          initialLongitude: initialLongitude,
          initialAddress: initialAddress,
          preselectedCategory: preselectedCategory,
          preselectedWorkerId: preselectedWorkerId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nueva solicitud',
                style: TextStyle(
                  color: AppTheme.colorPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '¿Cómo quieres contratar?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF090D16),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Elige la modalidad que mejor se adapte\na tu necesidad.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              
              _ModalityCard(
                icon: Icons.work_outline,
                iconColor: AppTheme.colorPrimary,
                iconBgColor: AppTheme.colorPrimary.withOpacity(0.1),
                title: 'Por trabajo',
                subtitle: 'Precio cerrado',
                subtitleColor: AppTheme.colorPrimary,
                description: 'Acuerda un precio fijo por el trabajo completo.',
                tags: const ['Tareas específicas', 'Proyectos puntuales'],
                onTap: () => _selectModality(context, 'fixed'),
              ),
              const SizedBox(height: 16),
              
              _ModalityCard(
                icon: Icons.access_time,
                iconColor: Colors.blue,
                iconBgColor: Colors.blue.withOpacity(0.1),
                title: 'Por hora',
                subtitle: 'Pagas por horas trabajadas',
                subtitleColor: Colors.blue,
                description: 'El tiempo se registra en la app y pagas solo por las horas trabajadas.',
                tags: const ['Trabajos flexibles', 'Sin alcance definido'],
                onTap: () => _selectModality(context, 'hourly'),
              ),
              const SizedBox(height: 16),
              
              _ModalityCard(
                icon: Icons.calendar_today_outlined,
                iconColor: Colors.green,
                iconBgColor: Colors.green.withOpacity(0.1),
                title: 'Por día',
                subtitle: 'Pagas una jornada completa',
                subtitleColor: Colors.green,
                description: 'Contrata por día completo de trabajo\n(jornada de 8 horas).',
                tags: const ['Jornadas completas', 'Proyectos de varios días'],
                onTap: () => _selectModality(context, 'daily'),
              ),
              
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.colorPrimary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppTheme.colorPrimary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Todos los pagos están protegidos por Chamba.',
                            style: TextStyle(
                              color: AppTheme.colorPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Solo pagas cuando el trabajo esté completo.',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalityCard extends StatelessWidget {
  const _ModalityCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    required this.description,
    required this.tags,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final Color subtitleColor;
  final String description;
  final List<String> tags;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF090D16),
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ideal para:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: iconBgColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      color: iconColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
