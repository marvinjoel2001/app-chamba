import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Devuelve la inicial de [value] en mayúscula, o [fallback] si está vacío.
/// Evita crashes de `substring` sobre strings vacíos.
String chambaInitial(Object? value, {String fallback = '?'}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text.substring(0, 1).toUpperCase();
}

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemOverlay,
      child: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            if (showGrid) const _DotGrid(),
            Positioned(
              top: -130,
              left: -125,
              child: _GlowCircle(
                size: 260,
                color: AppTheme.colorPrimary.withValues(alpha: 0.08),
              ),
            ),
            Positioned(
              bottom: -140,
              right: -130,
              child: _GlowCircle(
                size: 260,
                color: AppTheme.colorHighlight.withValues(alpha: 0.10),
              ),
            ),
            child,
          ],
        ),
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
    // En modo claro la tarjeta es una superficie blanca opaca: el blur de
    // fondo ya no se ve y solo costaba GPU en cada frame.
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: elevated ? AppTheme.colorGlassHigh : AppTheme.colorGlass,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppTheme.colorGlassBorder, width: 1),
        boxShadow: elevated ? AppTheme.shadowMd : AppTheme.shadowSm,
      ),
      child: child,
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

    final baseColor =
        widget.isYellow ? AppTheme.colorHighlight : AppTheme.colorPrimary;
    final pressedColor =
        widget.isYellow ? const Color(0xFFE0A200) : AppTheme.colorPrimaryDark;

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: enabled
          ? (_pressed ? pressedColor : baseColor)
          : const Color(0xFFDCD7E8),
      border: null,
      boxShadow: enabled
          ? (_pressed
              ? AppTheme.shadowSm
              : widget.isYellow
                  ? AppTheme.shadowYellow
                  : AppTheme.shadowPrimary)
          : const [],
    );

    final foreground = !enabled
        ? AppTheme.colorMuted
        : widget.isYellow
            ? AppTheme.colorText
            : AppTheme.colorTextOnPurple;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: enabled ? widget.onPressed : null,
      excludeSemantics: true,
      child: GestureDetector(
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
            opacity: enabled ? 1 : 0.85,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
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
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: textSize,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChambaSecondaryButton extends StatefulWidget {
  const ChambaSecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool compact;

  @override
  State<ChambaSecondaryButton> createState() => _ChambaSecondaryButtonState();
}

class _ChambaSecondaryButtonState extends State<ChambaSecondaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final minHeight = widget.compact ? 44.0 : 52.0;
    final horizontalPadding = widget.compact ? 12.0 : 16.0;
    final verticalPadding = widget.compact ? 10.0 : 13.0;
    final iconSize = widget.compact ? 20.0 : 22.0;
    final textSize = widget.compact ? 14.0 : 15.0;
    final iconGap = widget.compact ? 8.0 : 10.0;

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: _pressed ? AppTheme.colorPrimaryTint : Colors.white,
      border: Border.all(
        color: _pressed
            ? AppTheme.colorPrimary.withValues(alpha: 0.35)
            : AppTheme.colorGlassBorderSoft,
        width: 1.2,
      ),
      boxShadow: _pressed ? const [] : AppTheme.shadowSm,
    );

    final foreground = _pressed ? AppTheme.colorPrimary : AppTheme.colorText;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: enabled ? widget.onPressed : null,
      excludeSemantics: true,
      child: GestureDetector(
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
            opacity: enabled ? 1 : 0.5,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
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
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: textSize,
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
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
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? AppTheme.colorTextOnPurple : effectiveColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
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
    _NavItemData(icon: Icons.home_rounded, label: 'Inicio'),
    _NavItemData(icon: Icons.chat_bubble_rounded, label: 'Mensajes'),
    _NavItemData(icon: Icons.person_rounded, label: 'Perfil'),
  ];
  static const _workerItems = [
    _NavItemData(icon: Icons.home_rounded, label: 'Inicio'),
    _NavItemData(
        icon: Icons.account_balance_wallet_rounded, label: 'Billetera'),
    _NavItemData(icon: Icons.chat_bubble_rounded, label: 'Mensajes'),
    _NavItemData(icon: Icons.person_rounded, label: 'Perfil'),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.colorGlassBorder),
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
    final color = selected ? AppTheme.colorPrimary : AppTheme.colorMuted;

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: selected ? 18 : 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.colorPrimaryTint
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 24, color: color),
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
                          decoration: BoxDecoration(
                            color: AppTheme.colorError,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
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
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
                child: Text(label, textAlign: TextAlign.center),
              ),
            ],
          ),
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

class ChambaNetworkImage extends StatelessWidget {
  const ChambaNetworkImage({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return ChambaShimmer(
          child: Container(
            width: width,
            height: height,
            color: AppTheme.colorSurfaceSoft,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          color: AppTheme.colorSurfaceSoft,
          child: const Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              color: AppTheme.colorMuted,
              size: 20,
            ),
          ),
        );
      },
    );
  }
}

class ChambaNetworkAvatar extends StatelessWidget {
  const ChambaNetworkAvatar({
    required this.url,
    this.radius = 24,
    this.fallbackText = '?',
    super.key,
  });

  final String? url;
  final double radius;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppTheme.colorPrimaryTint,
        child: Text(
          fallbackText,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.colorPrimary,
            fontSize: radius * 0.7,
          ),
        ),
      );
    }
    return ClipOval(
      child: ChambaNetworkImage(
        url: url!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeletons de carga
// ─────────────────────────────────────────────────────────────────────────────

/// Aplica un brillo animado (shimmer) sobre [child]. Pensado para envolver
/// formas de [SkeletonBox] sobre fondo transparente: tiñe todo píxel opaco,
/// así que no debe envolver superficies (tarjetas blancas).
class ChambaShimmer extends StatefulWidget {
  const ChambaShimmer({required this.child, super.key});

  final Widget child;

  @override
  State<ChambaShimmer> createState() => _ChambaShimmerState();
}

class _ChambaShimmerState extends State<ChambaShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value * 1.6 - 0.3;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              _skeletonBase,
              Color(0xFFF9F8FD),
              _skeletonBase,
            ],
            stops: [
              (t - 0.25).clamp(0.0, 1.0),
              t.clamp(0.0, 1.0),
              (t + 0.25).clamp(0.0, 1.0),
            ],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

const Color _skeletonBase = Color(0xFFECE9F4);

/// Bloque gris redondeado para construir skeletons.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    this.width,
    this.height = 14,
    this.radius = 8,
    this.circle = false,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: circle ? height : width,
      height: height,
      decoration: BoxDecoration(
        color: _skeletonBase,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// Tarjeta skeleton genérica: avatar/ícono + líneas de texto.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({
    this.leadingSize = 44,
    this.circleLeading = true,
    this.lines = 2,
    this.trailing = false,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 10),
    this.showCard = true,
    super.key,
  });

  final double leadingSize;
  final bool circleLeading;
  final int lines;
  final bool trailing;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final bool showCard;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leadingSize > 0) ...[
          SkeletonBox(
            width: leadingSize,
            height: leadingSize,
            radius: 12,
            circle: circleLeading,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              const FractionallySizedBox(
                widthFactor: 0.62,
                child: SkeletonBox(height: 13),
              ),
              for (var i = 1; i < lines; i++) ...[
                const SizedBox(height: 9),
                FractionallySizedBox(
                  widthFactor: i == lines - 1 ? 0.42 : 0.88,
                  child: const SkeletonBox(height: 10),
                ),
              ],
            ],
          ),
        ),
        if (trailing) ...[
          const SizedBox(width: 12),
          const SkeletonBox(width: 44, height: 12),
        ],
      ],
    );

    return Padding(
      padding: margin,
      child: Container(
        padding: padding,
        decoration: showCard
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.colorGlassBorder),
              )
            : null,
        // El brillo va dentro de la tarjeta: si envolviera la tarjeta, el
        // ShaderMask también teñiría el fondo blanco y no se verían formas.
        child: ChambaShimmer(child: content),
      ),
    );
  }
}

/// Lista de [count] tarjetas skeleton con shimmer. Reemplaza al
/// `CircularProgressIndicator` centrado cuando se carga una lista.
/// Cada [SkeletonListTile] ya trae su propio brillo: no lo envuelvas en
/// [ChambaShimmer].
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    this.count = 6,
    this.lines = 2,
    this.leadingSize = 44,
    this.circleLeading = true,
    this.trailing = false,
    this.padding = const EdgeInsets.only(top: 8),
    this.shrinkWrap = false,
    super.key,
  });

  final int count;
  final int lines;
  final double leadingSize;
  final bool circleLeading;
  final bool trailing;
  final EdgeInsets padding;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: ListView.builder(
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        itemCount: count,
        itemBuilder: (_, __) => SkeletonListTile(
          lines: lines,
          leadingSize: leadingSize,
          circleLeading: circleLeading,
          trailing: trailing,
        ),
      ),
    );
  }
}

/// Estado vacío/error consistente: ícono en círculo tintado, título, texto y
/// acción opcional.
class ChambaEmptyState extends StatelessWidget {
  const ChambaEmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.color = AppTheme.colorPrimary,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: color),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.colorText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.colorMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 22),
            ChambaSecondaryButton(
              label: actionLabel!,
              icon: actionIcon,
              onPressed: onAction,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Skeleton de una conversación: burbujas alternadas izquierda/derecha.
class SkeletonChat extends StatelessWidget {
  const SkeletonChat({this.count = 7, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    const widths = [0.62, 0.48, 0.7, 0.4, 0.56, 0.66, 0.45, 0.6];
    return Semantics(
      label: 'Cargando mensajes',
      child: ChambaShimmer(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          itemBuilder: (context, index) {
            final mine = index.isOdd;
            final width = MediaQuery.sizeOf(context).width *
                widths[index % widths.length];
            return Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SkeletonBox(
                  width: width,
                  height: index % 3 == 0 ? 58 : 40,
                  radius: 16,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Skeleton de una grilla de fotos (portafolio, galerías).
class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({
    this.count = 6,
    this.crossAxisCount = 3,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final int count;
  final int crossAxisCount;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ChambaShimmer(
      child: GridView.builder(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: count,
        itemBuilder: (_, __) => const SkeletonBox(radius: 14, height: 120),
      ),
    );
  }
}

/// Skeleton de un perfil: avatar, nombre, métricas y tarjetas.
class SkeletonProfile extends StatelessWidget {
  const SkeletonProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return ChambaShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          Center(child: SkeletonBox(height: 92, circle: true)),
          SizedBox(height: 16),
          Center(child: SkeletonBox(width: 170, height: 18)),
          SizedBox(height: 10),
          Center(child: SkeletonBox(width: 110, height: 12)),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 64, radius: 16)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 64, radius: 16)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 64, radius: 16)),
            ],
          ),
          SizedBox(height: 20),
          SkeletonBox(height: 110, radius: 20),
          SizedBox(height: 12),
          SkeletonBox(height: 110, radius: 20),
        ],
      ),
    );
  }
}
