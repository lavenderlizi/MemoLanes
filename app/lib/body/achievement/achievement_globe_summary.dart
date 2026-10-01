import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:memolanes/body/achievement/shared/achievement_common.dart';
import 'package:memolanes/body/journey/compact_journey_info_card.dart';
import 'package:memolanes/constants/app_typography.dart';
import 'package:memolanes/theme/app_colors.dart';

class AchievementGlobeSummary extends StatelessWidget {
  const AchievementGlobeSummary({super.key, required this.stats});

  final AchievementAreaStats? stats;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _AreaTile(
          icon: Icons.terrain_outlined,
          title: context.tr('achievement.map.ground'),
          value: stats?.groundKm2,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _AreaTile(
          icon: Icons.flight_outlined,
          title: context.tr('achievement.map.flight'),
          value: stats?.flightKm2,
        ),
      ),
    ],
  );
}

class _AreaTile extends StatelessWidget {
  const _AreaTile({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final area = value == null ? null : formatArea(context, value!);
    return JourneyInfoPanelSurface(
      backgroundAlpha: 0.76,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: context.appColors.softGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: context.appColors.deepGreen,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    style: AppTypography.compactButton.copyWith(
                      color: context.appColors.deepGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                area?.value ?? '—',
                style: AppTypography.pageTitle.copyWith(
                  fontSize: 25,
                  color: context.appColors.deepGreen,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              area?.unit ??
                  context.tr('achievement.area_units.square_kilometers'),
              style: AppTypography.caption.copyWith(
                color: context.appColors.mutedInkColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
