import 'package:flutter/material.dart';
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
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: Color(0xFF0F172A),
            size: 28,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 18,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 18,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge pill: Nueva solicitud
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Nueva solicitud',
                  style: TextStyle(
                    color: Color(0xFF7C3AED),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              const Text(
                '¿Cómo quieres contratar?',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  height: 1.18,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              const Text(
                'Elige la modalidad que mejor se adapte a tu necesidad.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),

              // 1. Tarjeta: Por trabajo
              _ModalityCard(
                imagePath: 'assets/images/modalities/modality_job.png',
                cardBgColor: const Color(0xFFFAFAFE),
                borderColor: const Color(0xFFE9D5FF),
                title: 'Por trabajo',
                badgeText: 'Precio cerrado',
                badgeBgColor: const Color(0xFF7C3AED),
                description: 'Acuerda un precio fijo por el trabajo completo.',
                tagBgColor: const Color(0xFFEDE9FE),
                tagTextColor: const Color(0xFF7C3AED),
                tags: const ['Tareas específicas', 'Proyectos puntuales'],
                arrowBgColor: const Color(0xFFF3E8FF),
                arrowColor: const Color(0xFF7C3AED),
                onTap: () => _selectModality(context, 'fixed'),
              ),
              const SizedBox(height: 16),

              // 2. Tarjeta: Por hora
              _ModalityCard(
                imagePath: 'assets/images/modalities/modality_hour.png',
                cardBgColor: const Color(0xFFF0F9FF),
                borderColor: const Color(0xFFBAE6FD),
                title: 'Por hora',
                badgeText: 'Pagas por horas trabajadas',
                badgeBgColor: const Color(0xFF0284C7),
                description:
                    'El tiempo se registra en la app y pagas solo por las horas trabajadas.',
                tagBgColor: const Color(0xFFE0F2FE),
                tagTextColor: const Color(0xFF0284C7),
                tags: const ['Trabajos flexibles', 'Sin alcance definido'],
                arrowBgColor: const Color(0xFFE0F2FE),
                arrowColor: const Color(0xFF0284C7),
                onTap: () => _selectModality(context, 'hourly'),
              ),
              const SizedBox(height: 16),

              // 3. Tarjeta: Por día
              _ModalityCard(
                imagePath: 'assets/images/modalities/modality_day.png',
                cardBgColor: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFFBBF7D0),
                title: 'Por día',
                badgeText: 'Pagas una jornada completa',
                badgeBgColor: const Color(0xFF16A34A),
                description:
                    'Contrata por día completo de trabajo (jornada de 8 horas).',
                tagBgColor: const Color(0xFFDCFCE7),
                tagTextColor: const Color(0xFF16A34A),
                tags: const ['Jornada de 8 horas', 'Trabajo continuo'],
                arrowBgColor: const Color(0xFFDCFCE7),
                arrowColor: const Color(0xFF16A34A),
                onTap: () => _selectModality(context, 'daily'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalityCard extends StatelessWidget {
  const _ModalityCard({
    required this.imagePath,
    required this.cardBgColor,
    required this.borderColor,
    required this.title,
    required this.badgeText,
    required this.badgeBgColor,
    required this.description,
    required this.tagBgColor,
    required this.tagTextColor,
    required this.tags,
    required this.arrowBgColor,
    required this.arrowColor,
    required this.onTap,
  });

  final String imagePath;
  final Color cardBgColor;
  final Color borderColor;
  final String title;
  final String badgeText;
  final Color badgeBgColor;
  final String description;
  final Color tagBgColor;
  final Color tagTextColor;
  final List<String> tags;
  final Color arrowBgColor;
  final Color arrowColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: arrowColor.withValues(alpha: 0.08),
        highlightColor: arrowColor.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBgColor,
            border: Border.all(color: borderColor, width: 1.2),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: arrowColor.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 3D Illustrated Icon
              SizedBox(
                width: 86,
                height: 86,
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 14),

              // Content Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Solid Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),

                    // Description
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Tags Row
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: tagBgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: tagTextColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Circular Chevron Button
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: arrowBgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: arrowColor,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
