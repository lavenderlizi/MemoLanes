import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:memolanes/body/achievement/shared/achievement_common.dart';
import 'package:memolanes/common/component/cards/option_card.dart';
import 'package:memolanes/constants/style_constants.dart';

class AchievementComingSoonCard extends StatelessWidget {
  const AchievementComingSoonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OptionCard(
      children: [
        Padding(
          padding: achievementCardPadding,
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: StyleConstants.softYellow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: StyleConstants.journeyYellow.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: const Color(0xFFA17700),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('achievement.coming_soon_card.title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: StyleConstants.inkColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      context.tr('achievement.coming_soon_card.description'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: StyleConstants.mutedInkColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
