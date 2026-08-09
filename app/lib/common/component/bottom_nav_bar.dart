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

  static const double height = 72;
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
        borderRadius: BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(
            color: StyleConstants.inkColor.withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.7),
            blurRadius: 10,
            spreadRadius: -4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.78),
                      Colors.white.withValues(alpha: 0.48),
                      StyleConstants.softGreen.withValues(alpha: 0.42),
                    ],
                    stops: const [0, 0.52, 1],
                  ),
                  borderRadius: BorderRadius.circular(27),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.82),
                    width: 1.2,
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                top: 1,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.95),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedAlign(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                alignment: _selectionAlignment,
                child: FractionallySizedBox(
                  widthFactor: 0.2,
                  heightFactor: 1,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.72),
                            StyleConstants.primaryGreen.withValues(alpha: 0.48),
                            StyleConstants.journeyYellow.withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: StyleConstants.deepGreen
                                .withValues(alpha: 0.12),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              badges.Badge(
                showBadge: index == 4 && hasUpdateNotification(),
                position: badges.BadgePosition.topEnd(top: -4, end: -5),
                badgeStyle: const badges.BadgeStyle(
                  badgeColor: StyleConstants.journeyYellow,
                  padding: EdgeInsets.all(4),
                ),
                child: AnimatedScale(
                  scale: isSelected ? 1.08 : 1,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected
                        ? StyleConstants.deepGreen
                        : StyleConstants.mutedInkColor,
                    size: 23,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: isSelected
                        ? StyleConstants.deepGreen
                        : StyleConstants.mutedInkColor,
                    fontSize: 10,
                    height: 1,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
