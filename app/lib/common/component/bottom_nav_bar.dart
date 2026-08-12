import 'dart:ui';

import 'package:badges/badges.dart' as badges;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:memolanes/common/app_haptics.dart';
import 'package:memolanes/constants/style_constants.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.hasUpdateNotification,
  });

  final int selectedIndex;
  final Function(int) onIndexChanged;
  final Function hasUpdateNotification;

  static const double height = 58;
  static const double designHorizontalMargin = 24;

  Alignment get _selectionAlignment => switch (selectedIndex) {
        0 => Alignment.centerLeft,
        1 => const Alignment(-0.5, 0),
        2 => Alignment.center,
        3 => const Alignment(0.5, 0),
        _ => Alignment.centerRight,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: StyleConstants.inkColor.withValues(alpha: 0.14),
            blurRadius: 32,
            spreadRadius: -9,
            offset: const Offset(0, 13),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.38),
            blurRadius: 12,
            spreadRadius: -5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.36),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.62),
                    width: 1.1,
                  ),
                ),
              ),
              // A small environmental reflection, kept local so the main
              // glass surface stays neutral instead of becoming a gradient.
              Positioned(
                right: -28,
                bottom: -28,
                width: 190,
                height: 72,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.bottomRight,
                      radius: 1,
                      colors: [
                        StyleConstants.primaryGreen.withValues(alpha: 0.2),
                        StyleConstants.softGreen.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.48, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                top: 1,
                height: 1.4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.9),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 42,
                right: 42,
                bottom: 1,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        StyleConstants.softGreen.withValues(alpha: 0.54),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedAlign(
                duration: const Duration(milliseconds: 460),
                curve: Curves.easeOutCubic,
                alignment: _selectionAlignment,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(selectedIndex),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.linear,
                  builder: (context, progress, child) {
                    const expansionEnd = 0.38;
                    final expansionProgress =
                        (progress / expansionEnd).clamp(0.0, 1.0);
                    final settlingProgress =
                        ((progress - expansionEnd) / (1 - expansionEnd))
                            .clamp(0.0, 1.0);
                    final expansion = progress <= expansionEnd
                        ? Curves.easeOutCubic.transform(expansionProgress)
                        : 1 - Curves.easeOutCubic.transform(settlingProgress);

                    return Transform.scale(
                      scaleX: 1 + expansion * 0.16,
                      scaleY: 1 + expansion * 0.12,
                      alignment: Alignment.center,
                      child: child,
                    );
                  },
                  child: FractionallySizedBox(
                    widthFactor: 0.2,
                    heightFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 5),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: StyleConstants.primaryGreen
                                  .withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(19),
                              boxShadow: [
                                BoxShadow(
                                  color: StyleConstants.deepGreen
                                      .withValues(alpha: 0.1),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: Row(
                  children: [
                    _buildNavItem(
                      context,
                      Icons.explore_outlined,
                      Icons.explore_rounded,
                      'navigation.record',
                      0,
                    ),
                    _buildNavItem(
                      context,
                      Icons.history_toggle_off_rounded,
                      Icons.history_rounded,
                      'navigation.time_machine',
                      1,
                    ),
                    _buildNavItem(
                      context,
                      Icons.edit_road_outlined,
                      Icons.edit_road_rounded,
                      'navigation.edit',
                      2,
                    ),
                    _buildNavItem(
                      context,
                      Icons.emoji_events_outlined,
                      Icons.emoji_events_rounded,
                      'navigation.achievement',
                      3,
                    ),
                    _buildNavItem(
                      context,
                      Icons.tune_rounded,
                      Icons.tune_rounded,
                      'navigation.settings',
                      4,
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

  Widget _buildNavItem(BuildContext context, IconData icon, IconData activeIcon,
      String labelKey, int index) {
    final isSelected = selectedIndex == index;
    final label = context.tr(labelKey);

    return Expanded(
      child: Semantics(
        selected: isSelected,
        button: true,
        label: label,
        child: InkWell(
          onTap: () {
            if (!isSelected) AppHaptics.selection();
            onIndexChanged(index);
          },
          borderRadius: BorderRadius.circular(22),
          child: Center(
            child: badges.Badge(
              showBadge: index == 4 && hasUpdateNotification(),
              position: badges.BadgePosition.topEnd(top: -4, end: -5),
              badgeStyle: const badges.BadgeStyle(
                badgeColor: StyleConstants.journeyYellow,
                padding: EdgeInsets.all(4),
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: isSelected ? 1 : 0),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeInOutCubic,
                builder: (context, progress, _) {
                  // Both selecting and deselecting pass through the midpoint.
                  // Blur peaks there, hiding the glyph swap and creating a
                  // short refraction-like focus transition.
                  final blurProgress = 4 * progress * (1 - progress);
                  final blurSigma = blurProgress * 2.2;
                  final scale = 1 + progress * 0.1 + blurProgress * 0.045;
                  final color = Color.lerp(
                    StyleConstants.mutedInkColor,
                    StyleConstants.deepGreen,
                    progress,
                  );

                  return Transform.scale(
                    scale: scale,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: blurSigma,
                        sigmaY: blurSigma,
                        tileMode: TileMode.decal,
                      ),
                      child: Icon(
                        isSelected ? activeIcon : icon,
                        color: color,
                        size: 27 + progress * 2,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
