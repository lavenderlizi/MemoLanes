import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:memolanes/body/achievement/shared/achievement_common.dart';
import 'package:memolanes/body/journey/compact_journey_info_card.dart';
import 'package:memolanes/constants/app_typography.dart';
import 'package:memolanes/theme/app_colors.dart';

typedef AchievementRegionCardData = ({
  int id,
  String name,
  double visitedKm2,
  double totalKm2,
});

class AchievementRegionStrip extends StatefulWidget {
  const AchievementRegionStrip({
    super.key,
    required this.regions,
    required this.country,
    required this.onRanking,
    required this.selectedId,
    required this.onSelected,
  });

  final List<AchievementRegionCardData> regions;
  final AchievementRegionCardData country;
  final VoidCallback onRanking;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  static double heightForContext(BuildContext context) =>
      102 + MediaQuery.textScalerOf(context).scale(42);

  @override
  State<AchievementRegionStrip> createState() => _AchievementRegionStripState();
}

class _AchievementRegionStripState extends State<AchievementRegionStrip> {
  late final PageController _pages;
  int _selectionRevision = 0;
  bool _followingSelection = false;

  int get _selectedPage {
    final index = widget.regions.indexWhere(
      (region) => region.id == widget.selectedId,
    );
    return index < 0 ? 0 : index + 1;
  }

  @override
  void initState() {
    super.initState();
    _pages = PageController(initialPage: _selectedPage, viewportFraction: 0.9);
  }

  @override
  void didUpdateWidget(AchievementRegionStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId == widget.selectedId) return;
    _revealSelection();
  }

  void _revealSelection() {
    final revision = ++_selectionRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pages.hasClients || revision != _selectionRevision) {
        return;
      }
      final index = _selectedPage;
      // User swipes already select this page. Do not restart their scrolling.
      if (!_followingSelection && (_pages.page ?? 0).round() == index) return;
      _followingSelection = true;
      _pages
          .animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
          )
          .whenComplete(() {
            if (mounted && revision == _selectionRevision) {
              _followingSelection = false;
            }
          });
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  String _area(double value) {
    final area = formatArea(context, value);
    return '${area.value} ${area.unit}';
  }

  @override
  Widget build(
    BuildContext context,
  ) => NotificationListener<ScrollStartNotification>(
    onNotification: (notification) {
      if (notification.dragDetails != null) {
        ++_selectionRevision;
        _followingSelection = false;
      }
      return false;
    },
    child: PageView.builder(
      controller: _pages,
      padEnds: false,
      itemCount: widget.regions.length + 1,
      onPageChanged: (index) {
        if (!_followingSelection) {
          widget.onSelected(index == 0 ? null : widget.regions[index - 1].id);
        }
      },
      itemBuilder: (context, index) {
        final isCountry = index == 0;
        final region = isCountry ? widget.country : widget.regions[index - 1];
        final selected = isCountry
            ? widget.selectedId == null
            : widget.selectedId == region.id;
        final progress = region.totalKm2 <= 0
            ? 0.0
            : (region.visitedKm2 / region.totalKm2).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 10, 4),
          child: JourneyInfoPanelSurface(
            backgroundAlpha: 0.9,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => widget.onSelected(isCountry ? null : region.id),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: selected
                        ? Border.all(
                            color: context.appColors.deepGreen,
                            width: 1.5,
                          )
                        : null,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              region.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.surfaceTitle.copyWith(
                                color: context.appColors.deepGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (isCountry)
                            TextButton.icon(
                              onPressed: widget.onRanking,
                              style: TextButton.styleFrom(
                                foregroundColor: context.appColors.deepGreen,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                minimumSize: const Size(0, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: AppTypography.micro,
                              ),
                              icon: const Icon(Icons.sort_rounded, size: 16),
                              label: Text(
                                context.tr('achievement.map.ranking'),
                              ),
                            )
                          else
                            Icon(
                              selected
                                  ? Icons.my_location_rounded
                                  : Icons.north_east_rounded,
                              size: 15,
                              color: context.appColors.deepGreen,
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        context.tr(
                          'achievement.map.region_explored',
                          args: [_area(region.visitedKm2)],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.compactButton.copyWith(
                          color: context.appColors.inkColor,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.tr(
                                'achievement.map.total_label',
                                args: [_area(region.totalKm2)],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: context.appColors.mutedInkColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            context.tr(
                              'achievement.map.region_unlocked',
                              args: [(progress * 100).toStringAsFixed(2)],
                            ),
                            style: TextStyle(
                              fontSize: 10,
                              color: context.appColors.deepGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          color: context.appColors.deepGreen,
                          backgroundColor: context.appColors.softGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
