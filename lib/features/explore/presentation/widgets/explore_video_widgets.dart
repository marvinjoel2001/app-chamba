import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/job_schedule_format.dart';

/// Botón de video junto al micrófono: graba el trabajo con la guía.
class VideoRecordButton extends StatelessWidget {
  const VideoRecordButton({
    required this.hasVideo,
    required this.onTap,
    super.key,
  });

  final bool hasVideo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          'Graba el trabajo: te guío qué mostrar y lo que digas se escribe solo',
      triggerMode: TooltipTriggerMode.longPress,
      child: Semantics(
        button: true,
        label: 'Grabar video del trabajo',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: hasVideo
                    ? AppTheme.colorSuccess
                    : AppTheme.colorPrimary.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.colorPrimary.withValues(alpha: 0.14),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              hasVideo ? Icons.check_rounded : Icons.videocam_outlined,
              color: hasVideo ? AppTheme.colorSuccess : AppTheme.colorPrimary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// Globo que explica el botón de video las primeras veces.
class VideoHintCallout extends StatelessWidget {
  const VideoHintCallout({
    required this.onTry,
    required this.onClose,
    super.key,
  });

  final VoidCallback onTry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Material(
              color: AppTheme.colorText,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: onTry,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.videocam_outlined,
                            color: AppTheme.colorHighlight, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Muestra el trabajo en video',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Te voy diciendo qué grabar y lo que digas se escribe solo.',
                              style: TextStyle(
                                color: Color(0xFFD9D4E6),
                                fontSize: 12.5,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        tooltip: 'Cerrar',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Piquito que apunta al botón de video.
          Padding(
            padding: const EdgeInsets.only(right: 38),
            child: CustomPaint(
              size: const Size(16, 8),
              painter: _CalloutTailPainter(AppTheme.colorText),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalloutTailPainter extends CustomPainter {
  const _CalloutTailPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CalloutTailPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// "Video listo · 0:24" bajo el texto, con opción de quitarlo.
class PendingVideoChip extends StatelessWidget {
  const PendingVideoChip({
    required this.duration,
    required this.onRemove,
    super.key,
  });

  final Duration duration;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final seconds = duration.inSeconds;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppTheme.colorSuccessSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_rounded,
              color: AppTheme.colorSuccess, size: 16),
          const SizedBox(width: 6),
          Text(
            'Video listo · 0:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: AppTheme.colorSuccess,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          InkWell(
            onTap: onRemove,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded,
                  color: AppTheme.colorSuccess, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// Trabajo ya asignado para otro día, en el inicio del cliente.
class ScheduledJobCard extends StatelessWidget {
  const ScheduledJobCard({
    required this.job,
    required this.onTap,
    this.extraCount = 0,
    super.key,
  });

  final Map<String, dynamic> job;
  final VoidCallback onTap;
  final int extraCount;

  @override
  Widget build(BuildContext context) {
    final worker = job['worker'] as Map<String, dynamic>?;
    final when = formatJobStart(
      job['startDate']?.toString(),
      days: (job['days'] as num?)?.toInt(),
    );
    final title = job['title']?.toString() ?? 'Trabajo';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.colorGlassBorder),
            boxShadow: AppTheme.shadowLg,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.colorPrimaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_available_rounded,
                    color: AppTheme.colorPrimary, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$when · $title',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.colorText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      worker != null
                          ? '${worker['name']} confirmado · programado'
                          : 'Programado',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.colorMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (extraCount > 0)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.colorHighlight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+$extraCount',
                    style: const TextStyle(
                      color: Color(0xFF412402),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.colorMuted),
            ],
          ),
        ),
      ),
    );
  }
}
