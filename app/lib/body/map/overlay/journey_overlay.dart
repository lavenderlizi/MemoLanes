import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:memolanes/body/journey/compact_journey_info_card.dart';
import 'package:memolanes/body/journey/journey_body.dart';
import 'package:memolanes/common/simple_date_utils.dart';
import 'package:memolanes/constants/app_typography.dart';
import 'package:memolanes/common/app_layout.dart';
import 'package:memolanes/src/rust/journey_header.dart';
import 'package:memolanes/theme/app_colors.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// A compact button reveals the calendar without recreating its selection state.
class JourneyOverlay extends StatefulWidget {
  const JourneyOverlay({
    super.key,
    required this.onJourneySelected,
    required this.isLoading,
    required this.refreshRevision,
    this.selectedDate,
    this.onDateSelected,
    this.onExpandedChanged,
    this.isOpening = false,
    this.detail,
  });

  static const collapsedHeight = 32.0;

  /// Shared with map fitting so tracks stay above the expanded calendar too.
  static double pickerHeightForContext(BuildContext context) {
    return AppLayoutScope.of(context).pickerBounds.height;
  }

  final Future<void> Function(JourneyHeader journey) onJourneySelected;
  final bool isLoading;
  final bool isOpening;
  final int refreshRevision;
  final SimpleDate? selectedDate;
  final ValueChanged<SimpleDate>? onDateSelected;
  final ValueChanged<bool>? onExpandedChanged;
  final Widget? detail;

  @override
  State<JourneyOverlay> createState() => _JourneyOverlayState();
}

class _JourneyOverlayState extends State<JourneyOverlay> {
  bool _expanded = false;

  void _togglePicker() {
    setState(() => _expanded = !_expanded);
    widget.onExpandedChanged?.call(_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayoutScope.of(context);
    if (!layout.chromeReady) return const SizedBox.shrink();
    final frame = layout.pickerBounds;
    final pickerHeight = JourneyOverlay.pickerHeightForContext(context);

    return Stack(
      children: [
        Offstage(
          offstage: widget.detail != null,
          child: Stack(
            children: [
              Positioned(
                left: frame.left,
                right: layout.size.width - frame.right,
                bottom: layout.size.height - frame.bottom,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: frame.width,
                    child: AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      firstCurve: Curves.easeInOutCubic,
                      secondCurve: Curves.easeInOutCubic,
                      sizeCurve: Curves.easeInOutCubic,
                      alignment: Alignment.bottomCenter,
                      crossFadeState: _expanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      layoutBuilder:
                          (topChild, topKey, bottomChild, bottomKey) => Stack(
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
                        child: PointerInterceptor(
                          child: SizedBox(
                            width: 116,
                            height: JourneyOverlay.collapsedHeight,
                            child: JourneyInfoPanelSurface(
                              backgroundAlpha: 0.76,
                              child: Tooltip(
                                message: context.tr('journey.picker_title'),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    key: const ValueKey(
                                      'journey-picker-expand',
                                    ),
                                    onTap: _togglePicker,
                                    borderRadius: BorderRadius.circular(24),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              context.tr(
                                                'journey.picker_title',
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: AppTypography.compactButton
                                                  .copyWith(
                                                    color: context
                                                        .appColors
                                                        .deepGreen,
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
                        ),
                      ),
                      secondChild: PointerInterceptor(
                        child: SizedBox(
                          height: pickerHeight,
                          child: _JourneyPickerCard(
                            onJourneySelected: widget.onJourneySelected,
                            onDateSelected: widget.onDateSelected,
                            selectedDate: widget.selectedDate,
                            isLoading: widget.isLoading,
                            isOpening: widget.isOpening,
                            refreshRevision: widget.refreshRevision,
                            onToggle: _togglePicker,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ?widget.detail,
      ],
    );
  }
}

class _JourneyPickerCard extends StatelessWidget {
  const _JourneyPickerCard({
    required this.onJourneySelected,
    required this.onDateSelected,
    required this.selectedDate,
    required this.isLoading,
    required this.isOpening,
    required this.refreshRevision,
    required this.onToggle,
  });

  final Future<void> Function(JourneyHeader journey) onJourneySelected;
  final ValueChanged<SimpleDate>? onDateSelected;
  final SimpleDate? selectedDate;
  final bool isLoading;
  final bool isOpening;
  final int refreshRevision;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return JourneyInfoPanelSurface(
      backgroundAlpha: 0.76,
      child: AbsorbPointer(
        absorbing: isOpening,
        child: Column(
          children: [
            GestureDetector(
              key: const ValueKey('journey-picker-toggle'),
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
                        Icons.route_rounded,
                        size: 17,
                        color: context.appColors.deepGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('journey.picker_title'),
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
            SizedBox(
              height: 2,
              child: isLoading
                  ? LinearProgressIndicator(color: context.appColors.deepGreen)
                  : Divider(
                      height: 1,
                      color: context.appColors.lineColor.withValues(alpha: 0.9),
                    ),
            ),
            Expanded(
              // Wait for the initial default date before mounting the calendar.
              // Later map loads retain the calendar and remain selectable.
              child: selectedDate == null && isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : JourneyBody(
                      onJourneySelected: onJourneySelected,
                      initialDate: selectedDate,
                      onDateSelected: onDateSelected,
                      refreshRevision: refreshRevision,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
