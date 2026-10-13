import 'package:flutter/material.dart';

/// Role-colored navigation. The generated wave is decorative; every tab and
/// unread badge remains a native, interactive Flutter control.
class ChambaWaveBottomNav extends StatelessWidget {
  const ChambaWaveBottomNav({
    required this.role,
    required this.currentIndex,
    required this.onTap,
    this.badgeIndex,
    this.unreadCount = 0,
    super.key,
  });

  final String role;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int? badgeIndex;
  final int unreadCount;

  static const _clientItems = [
    _WaveNavItem('Inicio', 'home'),
    _WaveNavItem('Notificaciones', 'bell'),
    _WaveNavItem('Perfil', 'profile'),
  ];
  static const _workerItems = [
    _WaveNavItem('Inicio', 'briefcase'),
    _WaveNavItem('Billetera', 'wallet'),
    _WaveNavItem('Notificaciones', 'bell'),
    _WaveNavItem('Perfil', 'profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final worker = role == 'worker';
    final items = worker ? _workerItems : _clientItems;
    final textScale = MediaQuery.textScalerOf(context).scale(11) / 11;
    final height = 84.0 + (textScale > 1 ? (textScale - 1) * 42 : 0);
    final accent = worker ? const Color(0xFFFFB800) : const Color(0xFF7C3AFF);
    final labelColor =
        worker ? const Color(0xFF9D6000) : const Color(0xFF7130E8);
    final radius = BorderRadius.circular(28);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 260);
    final selectedIndex = currentIndex.clamp(0, items.length - 1);
    final selectedDecoration = BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: worker
            ? const [Color(0xFFFFCC18), Color(0xFFFFAD00)]
            : const [Color(0xFF9855FF), Color(0xFF7130FF)],
      ),
      boxShadow: [
        BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 13,
            offset: const Offset(0, 4))
      ],
    );

    return RepaintBoundary(
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: SizedBox(
              key: const ValueKey('chamba-wave-surface'),
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/navigation/${worker ? 'worker' : 'client'}-wave.png',
                    // Preserve both ends and the entire shallow valley. Cover
                    // would crop the wide wave on narrow phone screens.
                    fit: BoxFit.fill,
                    cacheWidth: 1200,
                    filterQuality: FilterQuality.medium,
                    excludeFromSemantics: true,
                  ),
                  Material(
                    type: MaterialType.transparency,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: List.generate(items.length, (index) {
                          final item = items[index];
                          final selected = index == selectedIndex;
                          final count = index == badgeIndex ? unreadCount : 0;
                          return Expanded(
                            child: Semantics(
                              key: ValueKey('chamba-nav-tab-$index'),
                              button: true,
                              selected: selected,
                              onTap: () => onTap(index),
                              label: count > 0
                                  ? '${item.label}, $count sin leer'
                                  : item.label,
                              excludeSemantics: true,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => onTap(index),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(1, 6, 1, 4),
                                  child: Column(
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          SizedBox(
                                            width: 56,
                                            height: 56,
                                            child: Center(
                                              child: Image.asset(
                                                'assets/images/navigation/${item.asset}.png',
                                                width: 28,
                                                height: 28,
                                                cacheWidth: 120,
                                                color: const Color(0xFF6E638D),
                                                colorBlendMode: BlendMode.srcIn,
                                                filterQuality:
                                                    FilterQuality.medium,
                                                excludeFromSemantics: true,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Expanded(
                                        child: AnimatedDefaultTextStyle(
                                          duration: duration,
                                          style: TextStyle(
                                            fontFamily: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.fontFamily,
                                            fontSize: 11,
                                            height: 1.15,
                                            fontWeight: selected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: selected
                                                ? labelColor
                                                : const Color(0xFF6E638D),
                                          ),
                                          child: Text(item.label,
                                              textAlign: TextAlign.center,
                                              maxLines: textScale > 1 ? 3 : 1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  // Paint the active icon inside its moving circle, above the
                  // stationary icons. Otherwise a fading white icon can become
                  // invisible on the pale surface while the circle is moving.
                  IgnorePointer(
                    child: LayoutBuilder(builder: (context, constraints) {
                      final tabWidth =
                          (constraints.maxWidth - 12) / items.length;
                      double circleLeft(int index) =>
                          6 + tabWidth * (index + 0.5) - 28;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedPositioned(
                            key: const ValueKey('chamba-nav-selection'),
                            duration: duration,
                            curve: Curves.easeInOutCubic,
                            left: circleLeft(selectedIndex),
                            top: 6,
                            width: 56,
                            height: 56,
                            child: DecoratedBox(
                              decoration: selectedDecoration,
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: duration == Duration.zero
                                      ? Duration.zero
                                      : const Duration(milliseconds: 130),
                                  transitionBuilder: (child, animation) =>
                                      FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: Tween<double>(begin: 0.86, end: 1)
                                          .animate(animation),
                                      child: child,
                                    ),
                                  ),
                                  child: Image.asset(
                                    'assets/images/navigation/${items[selectedIndex].asset}.png',
                                    key: ValueKey(items[selectedIndex].asset),
                                    width: 32,
                                    height: 32,
                                    cacheWidth: 120,
                                    color: Colors.white,
                                    colorBlendMode: BlendMode.srcIn,
                                    filterQuality: FilterQuality.medium,
                                    excludeFromSemantics: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (unreadCount > 0 &&
                              badgeIndex != null &&
                              badgeIndex! >= 0 &&
                              badgeIndex! < items.length)
                            Positioned(
                              left: circleLeft(badgeIndex!),
                              top: 6,
                              width: 56,
                              height: 56,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    top: badgeIndex == selectedIndex ? 0 : 7,
                                    right: badgeIndex == selectedIndex ? -3 : 1,
                                    child: _UnreadBadge(count: unreadCount),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    }),
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

class _WaveNavItem {
  const _WaveNavItem(this.label, this.asset);
  final String label;
  final String asset;
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
        decoration: BoxDecoration(
          color: const Color(0xFFE5484D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          textAlign: TextAlign.center,
          // Keep the compact badge readable without changing its hit target.
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: Theme.of(context).textTheme.bodySmall?.fontFamily,
            color: Colors.white,
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
