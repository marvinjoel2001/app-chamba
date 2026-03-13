import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ChambaBackground extends StatelessWidget {
  const ChambaBackground({
    required this.child,
    this.showGrid = false,
    super.key,
  });

  final Widget child;
  final bool showGrid;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.colorBackground, AppTheme.colorBackgroundAccent],
        ),
      ),
      child: Stack(
        children: [
          if (showGrid) const _DotGrid(),
          Positioned(
            top: -140,
            right: -70,
            child: _GlowCircle(
              size: 320,
              color: AppTheme.colorPrimary.withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: _GlowCircle(
              size: 340,
              color: AppTheme.colorHighlight.withValues(alpha: 0.12),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.elevated = false,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final blur = elevated ? 32.0 : 24.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: elevated ? AppTheme.colorGlassHigh : AppTheme.colorGlass,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: elevated
                  ? Colors.white.withValues(alpha: 0.85)
                  : AppTheme.colorGlassBorder,
              width: 1,
            ),
            boxShadow: elevated ? AppTheme.shadowLg : AppTheme.shadowMd,
          ),
          child: child,
        ),
      ),
    );
  }
}

class ChambaPrimaryButton extends StatefulWidget {
  const ChambaPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isYellow = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isYellow;

  @override
  State<ChambaPrimaryButton> createState() => _ChambaPrimaryButtonState();
}

class _ChambaPrimaryButtonState extends State<ChambaPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: widget.isYellow ? AppTheme.colorHighlight : AppTheme.colorPrimary,
      border: null,
      boxShadow: enabled
          ? (_pressed
                ? AppTheme.shadowSm
                : widget.isYellow
                ? AppTheme.shadowYellow
                : AppTheme.shadowMd)
          : const [],
    );

    final foreground = widget.isYellow
        ? AppTheme.colorText
        : AppTheme.colorTextOnPurple;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        scale: _pressed ? 0.97 : 1,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1 : 0.6,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            decoration: decoration,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: foreground),
                  const SizedBox(width: 10),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChambaChip extends StatelessWidget {
  const ChambaChip({
    required this.label,
    required this.selected,
    this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.colorPrimary
              : AppTheme.colorPrimary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected
                ? AppTheme.colorPrimary
                : AppTheme.colorPrimary.withValues(alpha: 0.20),
          ),
          boxShadow: selected ? AppTheme.shadowSm : const [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.colorPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class ChambaBottomNav extends StatelessWidget {
  const ChambaBottomNav({
    required this.role,
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final String role;
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _clientItems = [
    _NavItemData(icon: Icons.home_filled, label: 'Inicio'),
    _NavItemData(icon: Icons.work, label: 'Ofertas'),
    _NavItemData(icon: Icons.chat_bubble, label: 'Mensajes'),
    _NavItemData(icon: Icons.person, label: 'Perfil'),
  ];
  static const _workerItems = [
    _NavItemData(icon: Icons.home_filled, label: 'Inicio'),
    _NavItemData(icon: Icons.radar, label: 'Radar'),
    _NavItemData(icon: Icons.history, label: 'Historial'),
    _NavItemData(icon: Icons.person, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final items = role == 'worker' ? _workerItems : _clientItems;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
              boxShadow: AppTheme.shadowMd,
            ),
            child: Row(
              children: List.generate(items.length, (index) {
                final item = items[index];
                final selected = index == currentIndex;
                return Expanded(
                  child: _BottomNavItem(
                    icon: item.icon,
                    label: item.label,
                    selected: selected,
                    onTap: () => onTap(index),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected
        ? AppTheme.colorPrimary
        : const Color(0xFFA78BCA);
    const labelColor = Color(0xFFA78BCA);

    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: iconColor),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: labelColor,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DotGrid extends StatelessWidget {
  const _DotGrid();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _DotGridPainter(), size: Size.infinite),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.colorPrimary.withValues(alpha: 0.08);

    const spacing = 34.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.15, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
