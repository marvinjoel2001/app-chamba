import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Envuelve la card de una solicitud recién llegada y la hace destellar un
/// rato para que el worker distinga de un vistazo cuál es la nueva dentro de
/// la lista.
///
/// Con [active] en false no anima ni pinta nada: devuelve el hijo tal cual,
/// así se puede envolver toda la lista sin costo.
class NewRequestPulse extends StatefulWidget {
  const NewRequestPulse({
    required this.active,
    required this.child,
    this.borderRadius = 16,
    super.key,
  });

  final bool active;
  final Widget child;
  final double borderRadius;

  @override
  State<NewRequestPulse> createState() => _NewRequestPulseState();
}

class _NewRequestPulseState extends State<NewRequestPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(NewRequestPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: AppTheme.colorSuccess.withValues(alpha: 0.15 + 0.35 * t),
                blurRadius: 12 + 18 * t,
                spreadRadius: 1 + 2 * t,
              ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: AppTheme.colorSuccess.withValues(alpha: 0.45 + 0.45 * t),
              width: 1.5 + t,
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
