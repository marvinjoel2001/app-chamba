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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.colorBackground, AppTheme.colorBackgroundAccent],
        ),
      ),
      child: Stack(
        children: [
          if (showGrid) const _DotGrid(),
          Positioned(
            top: -120,
            right: -80,
            child: _GlowCircle(
              size: 260,
              color: AppTheme.colorPrimary.withValues(alpha: 0.25),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -90,
            child: _GlowCircle(
              size: 280,
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
    this.borderRadius = 24,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppTheme.colorGlass,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppTheme.colorGlassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

class ChambaPrimaryButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor:
            isYellow ? AppTheme.colorHighlight : AppTheme.colorPrimary,
        foregroundColor: isYellow ? Colors.black : Colors.white,
        minimumSize: const Size.fromHeight(58),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon),
            const SizedBox(width: 10),
          ],
          Text(label),
        ],
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.colorPrimary
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: selected
                ? AppTheme.colorPrimary
                : Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class ChambaBottomNav extends StatelessWidget {
  const ChambaBottomNav({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF130E1D),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        selectedItemColor: AppTheme.colorPrimary,
        unselectedItemColor: const Color(0xFF8692AC),
        onTap: onTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Ofertas'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Mensajes'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
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
      child: CustomPaint(
        painter: _DotGridPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.colorPrimary.withValues(alpha: 0.2);

    const spacing = 36.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
