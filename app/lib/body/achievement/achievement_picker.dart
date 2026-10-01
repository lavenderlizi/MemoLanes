import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:memolanes/body/journey/compact_journey_info_card.dart';
import 'package:memolanes/constants/app_typography.dart';
import 'package:memolanes/theme/app_colors.dart';

/// Matches the journey picker's glass surface, header and anchored crossfade.
class AchievementPicker extends StatelessWidget {
  const AchievementPicker({
    super.key,
    required this.expanded,
    required this.height,
    required this.onToggle,
    required this.child,
  });

  final bool expanded;
  final double height;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedCrossFade(
    duration: const Duration(milliseconds: 250),
    firstCurve: Curves.easeInOutCubic,
    secondCurve: Curves.easeInOutCubic,
    sizeCurve: Curves.easeInOutCubic,
    alignment: Alignment.bottomCenter,
    crossFadeState: expanded
        ? CrossFadeState.showSecond
        : CrossFadeState.showFirst,
    layoutBuilder: (topChild, topKey, bottomChild, bottomKey) => Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          key: bottomKey,
          left: 0,
          right: 0,
          bottom: 0,
          child: bottomChild,
        ),
        Positioned(key: topKey, child: topChild),
      ],
    ),
    firstChild: Center(
      child: SizedBox(
        width: 116,
        height: 32,
        child: JourneyInfoPanelSurface(
          backgroundAlpha: 0.76,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('achievement-picker-expand'),
              onTap: onToggle,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('achievement.title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTypography.compactButton.copyWith(
                          color: context.appColors.deepGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 19,
                      color: context.appColors.deepGreen,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    secondChild: SizedBox(
      height: height,
      child: JourneyInfoPanelSurface(
        backgroundAlpha: 0.76,
        child: Column(
          children: [
            GestureDetector(
              key: const ValueKey('achievement-picker-collapse'),
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 9, 8),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: context.appColors.softGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.emoji_events_outlined,
                        size: 17,
                        color: context.appColors.deepGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('achievement.title'),
                        style: AppTypography.surfaceTitle.copyWith(
                          color: context.appColors.deepGreen,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: context.appColors.deepGreen,
                    ),
                  ],
                ),
              ),
            ),
            Divider(
              height: 2,
              color: context.appColors.lineColor.withValues(alpha: 0.9),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: child,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
