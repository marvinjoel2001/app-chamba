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
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Stack(
        children: [
          if (showGrid) const _DotGrid(),
          Positioned(
            top: -130,
            left: -125,
            child: _GlowCircle(
              size: 240,
              color: AppTheme.colorPrimary.withValues(alpha: 0.05),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -130,
            child: _GlowCircle(
              size: 250,
              color: AppTheme.colorHighlight.withValues(alpha: 0.05),
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
    final blur = elevated ? 12.0 : 10.0;
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
                  ? AppTheme.colorGlassBorder
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
    this.compact = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isYellow;
  final bool compact;

  @override
  State<ChambaPrimaryButton> createState() => _ChambaPrimaryButtonState();
}

class _ChambaPrimaryButtonState extends State<ChambaPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final minHeight = widget.compact ? 44.0 : 52.0;
    final horizontalPadding = widget.compact ? 12.0 : 16.0;
    final verticalPadding = widget.compact ? 10.0 : 13.0;
    final iconSize = widget.compact ? 20.0 : 24.0;
    final textSize = widget.compact ? 14.0 : 16.0;
    final iconGap = widget.compact ? 8.0 : 10.0;

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

    final foreground =
        widget.isYellow ? AppTheme.colorText : AppTheme.colorTextOnPurple;

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
            constraints: BoxConstraints(minHeight: minHeight),
            decoration: decoration,
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: foreground, size: iconSize),
                  SizedBox(width: iconGap),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: textSize,
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
    this.icon,
    this.color,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.colorPrimary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? effectiveColor
              : effectiveColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected
                ? effectiveColor
                : effectiveColor.withValues(alpha: 0.20),
          ),
          boxShadow: selected ? AppTheme.shadowSm : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? AppTheme.colorTextOnPurple : effectiveColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.colorTextOnPurple : effectiveColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
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
    _NavItemData(icon: Icons.chat_bubble, label: 'Mensajes'),
    _NavItemData(icon: Icons.person, label: 'Perfil'),
  ];
  static const _workerItems = [
    _NavItemData(icon: Icons.home_filled, label: 'Inicio'),
    _NavItemData(icon: Icons.account_balance_wallet, label: 'Billetera'),
    _NavItemData(icon: Icons.chat_bubble, label: 'Mensajes'),
    _NavItemData(icon: Icons.person, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final items = role == 'worker' ? _workerItems : _clientItems;
    return _buildNav(context, items, currentIndex, onTap, 0, null);
  }
}

/// Bottom nav con badge de mensajes no leídos
class ChambaBottomNavWithBadge extends StatelessWidget {
  const ChambaBottomNavWithBadge({
    required this.role,
    required this.currentIndex,
    required this.unreadCount,
    required this.messagesTabIndex,
    required this.onTap,
    super.key,
  });

  final String role;
  final int currentIndex;
  final int unreadCount;
  final int messagesTabIndex;
  final ValueChanged<int> onTap;

  static const _clientItems = [
    _NavItemData(icon: Icons.home_filled, label: 'Inicio'),
    _NavItemData(icon: Icons.chat_bubble, label: 'Mensajes'),
    _NavItemData(icon: Icons.person, label: 'Perfil'),
  ];
  static const _workerItems = [
    _NavItemData(icon: Icons.home_filled, label: 'Inicio'),
    _NavItemData(icon: Icons.account_balance_wallet, label: 'Billetera'),
    _NavItemData(icon: Icons.chat_bubble, label: 'Mensajes'),
    _NavItemData(icon: Icons.person, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final items = role == 'worker' ? _workerItems : _clientItems;
    return _buildNav(
      context,
      items,
      currentIndex,
      onTap,
      messagesTabIndex,
      unreadCount,
    );
  }
}

Widget _buildNav(
  BuildContext context,
  List<_NavItemData> items,
  int currentIndex,
  ValueChanged<int> onTap,
  int badgeIndex,
  int? badgeCount,
) {
  return RepaintBoundary(
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.colorBackgroundAlt,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.colorGlassBorderSoft),
          boxShadow: AppTheme.shadowMd,
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = index == currentIndex;
            final showBadge = index == badgeIndex && (badgeCount ?? 0) > 0;
            return Expanded(
              child: _BottomNavItem(
                icon: item.icon,
                label: item.label,
                selected: selected,
                badgeCount: showBadge ? badgeCount : null,
                onTap: () => onTap(index),
              ),
            );
          }),
        ),
      ),
    ),
  );
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
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? AppTheme.colorPrimary : AppTheme.colorMuted;
    const labelColor = AppTheme.colorMuted;

    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 24, color: iconColor),
                if (badgeCount != null && badgeCount! > 0)
                  Positioned(
                    top: -6,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      decoration: const BoxDecoration(
                        color: AppTheme.colorError,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badgeCount! > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: labelColor,
              ),
              child: Text(label, textAlign: TextAlign.center),
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0.0, 1.0],
        ),
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
