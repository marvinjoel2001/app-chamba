import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/sound_effect_service.dart';

class ConfettiCelebration {
  ConfettiCelebration._();

  static OverlayEntry? _activeEntry;
  static DateTime? _lastShownAt;

  /// Muestra una lluvia de confetis en pantalla completa con animación y sonido.
  static void show(
    BuildContext context, {
    String title = '🎉 ¡OFERTA ACEPTADA!',
    String subtitle = '¡El trabajo ha sido confirmado con éxito!',
    Duration duration = const Duration(milliseconds: 3800),
    bool playSound = true,
  }) {
    final now = DateTime.now();
    if (_lastShownAt != null &&
        now.difference(_lastShownAt!) < const Duration(milliseconds: 3500)) {
      // Ignorar llamadas repetidas en rápida sucesión (evita doble overlay y doble sonido)
      return;
    }
    _lastShownAt = now;

    // Si ya existe un overlay activo, removerlo antes de crear uno nuevo
    if (_activeEntry != null) {
      try {
        _activeEntry!.remove();
      } catch (_) {}
      _activeEntry = null;
    }

    if (playSound) {
      SoundEffectService.playAcceptedSound();
    }

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ConfettiOverlayWidget(
        title: title,
        subtitle: subtitle,
        duration: duration,
        onFinished: () {
          if (_activeEntry == entry) {
            _activeEntry = null;
          }
          try {
            entry.remove();
          } catch (_) {}
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
  }
}

class _ConfettiOverlayWidget extends StatefulWidget {
  const _ConfettiOverlayWidget({
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.onFinished,
  });

  final String title;
  final String subtitle;
  final Duration duration;
  final VoidCallback onFinished;

  @override
  State<_ConfettiOverlayWidget> createState() => _ConfettiOverlayWidgetState();
}

class _ConfettiOverlayWidgetState extends State<_ConfettiOverlayWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final List<_ConfettiParticle> _particles;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _particles = List.generate(75, (_) => _ConfettiParticle(_random));

    _animCtrl.forward().then((_) {
      if (mounted) {
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _animCtrl,
        builder: (context, child) {
          final progress = _animCtrl.value;
          final fadeIn = (progress / 0.15).clamp(0.0, 1.0);
          final fadeOut = ((1.0 - progress) / 0.2).clamp(0.0, 1.0);
          final opacity = fadeIn * fadeOut;

          final cardScale = progress < 0.2
              ? Curves.elasticOut.transform(progress / 0.2)
              : 1.0;

          return Opacity(
            opacity: opacity,
            child: Stack(
              children: [
                // Partículas de confeti
                CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _ConfettiPainter(
                    progress: progress,
                    particles: _particles,
                  ),
                ),

                // Tarjeta central de celebración
                Center(
                  child: Transform.scale(
                    scale: cardScale,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1B2433), Color(0xFF101722)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF00D26A).withValues(alpha: 0.6),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D26A).withValues(alpha: 0.35),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00E676), Color(0xFF00A859)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00D26A)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ConfettiParticle {
  _ConfettiParticle(math.Random random) {
    color = _palette[random.nextInt(_palette.length)];
    startX = random.nextDouble();
    startY = random.nextDouble() * 0.35;
    targetX = startX + (random.nextDouble() - 0.5) * 0.6;
    speed = 0.5 + random.nextDouble() * 0.8;
    wobbleSpeed = 3.0 + random.nextDouble() * 5.0;
    wobbleRadius = 20.0 + random.nextDouble() * 40.0;
    rotationSpeed = (random.nextDouble() - 0.5) * 12.0;
    size = 7.0 + random.nextDouble() * 9.0;
    shape = _ParticleShape.values[random.nextInt(_ParticleShape.values.length)];
  }

  static const List<Color> _palette = [
    Color(0xFF00D26A),
    Color(0xFF8A2BE2),
    Color(0xFFFFD700),
    Color(0xFF00E5FF),
    Color(0xFFFF4081),
    Color(0xFFFF9100),
    Colors.white,
  ];

  late final Color color;
  late final double startX;
  late final double startY;
  late final double targetX;
  late final double speed;
  late final double wobbleSpeed;
  late final double wobbleRadius;
  late final double rotationSpeed;
  late final double size;
  late final _ParticleShape shape;
}

enum _ParticleShape { rectangle, circle, ribbon, star }

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.particles});

  final double progress;
  final List<_ConfettiParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (progress * p.speed).clamp(0.0, 1.0);
      final currentY = (p.startY * size.height) + (t * size.height * 1.1);
      final wobble = math.sin(progress * p.wobbleSpeed * math.pi * 2) * p.wobbleRadius;
      final currentX = (p.startX + (p.targetX - p.startX) * t) * size.width + wobble;

      if (currentY > size.height + 20) continue;

      final paint = Paint()
        ..color = p.color
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(progress * p.rotationSpeed * math.pi);

      // Efecto 3D flipping
      final flip = math.cos(progress * p.rotationSpeed * 2.0);
      canvas.scale(1.0, flip.abs().clamp(0.2, 1.0));

      switch (p.shape) {
        case _ParticleShape.rectangle:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: p.size * 1.4,
                height: p.size * 0.7,
              ),
              const Radius.circular(2),
            ),
            paint,
          );
          break;
        case _ParticleShape.circle:
          canvas.drawCircle(Offset.zero, p.size * 0.45, paint);
          break;
        case _ParticleShape.ribbon:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: p.size * 2.2,
                height: p.size * 0.4,
              ),
              const Radius.circular(3),
            ),
            paint,
          );
          break;
        case _ParticleShape.star:
          final path = Path();
          const points = 5;
          final outer = p.size * 0.65;
          final inner = outer * 0.45;
          for (var i = 0; i < points * 2; i++) {
            final r = i.isEven ? outer : inner;
            final angle = (i * math.pi) / points - (math.pi / 2);
            final x = r * math.cos(angle);
            final y = r * math.sin(angle);
            if (i == 0) {
              path.moveTo(x, y);
            } else {
              path.lineTo(x, y);
            }
          }
          path.close();
          canvas.drawPath(path, paint);
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
