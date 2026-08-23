import 'dart:async';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:memolanes/body/journey/list/journey_layer_filter_menu.dart';
import 'package:memolanes/body/journey/list/journey_list_controller.dart';
import 'package:memolanes/common/app_haptics.dart';
import 'package:memolanes/common/component/custom_popup.dart';
import 'package:memolanes/common/loading_manager.dart';
import 'package:memolanes/constants/app_typography.dart';
import 'package:memolanes/constants/style_constants.dart';
import 'package:memolanes/src/rust/journey_header.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class JourneyListCalendar extends StatelessWidget {
  final JourneyListController controller;
  final DateTime firstDate;
  final bool compact;

  const JourneyListCalendar({
    super.key,
    required this.controller,
    required this.firstDate,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = CalendarDatePicker2Config(
      firstDate: firstDate,
      lastDate: controller.lastDate,
      centerAlignModePicker: true,
      calendarType: CalendarDatePicker2Type.single,
      selectedDayHighlightColor: StyleConstants.primaryGreen,
      controlsHeight: compact ? 38 : null,
      dayMaxWidth: compact ? 30 : null,
      dayTextStyle: (compact ? AppTypography.caption : AppTypography.body)
          .copyWith(color: StyleConstants.inkColor),
      weekdayLabelTextStyle:
          (compact ? AppTypography.micro : AppTypography.label).copyWith(
        color: StyleConstants.mutedInkColor,
      ),
      controlsTextStyle:
          (compact ? AppTypography.sectionLabel : AppTypography.cardTitle)
              .copyWith(color: StyleConstants.inkColor),
      modePickersGap: 8,
      modePickerBuilder: ({
        required viewMode,
        required monthDate,
        isMonthPicker,
      }) {
        if (isMonthPicker == true) {
          return _buildHeaderSelector(
            DateFormat.MMMM(context.locale.toString()).format(monthDate),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeaderSelector(
              MaterialLocalizations.of(context).formatYear(monthDate),
            ),
            const SizedBox(width: 8),
            _buildFilterButton(context),
          ],
        );
      },
      selectableYearPredicate: (year) =>
          controller.yearsWithJourneys.contains(year),
      selectableMonthPredicate: (year, month) =>
          controller.monthsForYear(year).contains(month),
      selectableDayPredicate: (day) =>
          controller.daysForMonth(day.year, day.month).contains(day.day),
      dayBuilder: ({
        required date,
        textStyle,
        decoration,
        isSelected,
        isDisabled,
        isToday,
      }) {
        if (!controller
            .daysForMonth(date.year, date.month)
            .contains(date.day)) {
          return null;
        }
        return Container(
          decoration: decoration,
          child: Center(
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: [
                Text(
                  MaterialLocalizations.of(context).formatDecimal(date.day),
                  style: textStyle,
                ),
                Padding(
                  padding: EdgeInsets.only(top: compact ? 20 : 27.5),
                  child: Container(
                    height: compact ? 3 : 4,
                    width: compact ? 3 : 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: StyleConstants.journeyYellow,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      dynamicCalendarRows: true,
      disabledDayTextStyle:
          (compact ? AppTypography.caption : AppTypography.body).copyWith(
        color: StyleConstants.mutedInkColor.withValues(alpha: 0.5),
      ),
      disabledMonthTextStyle:
          const TextStyle(color: Colors.grey, fontWeight: FontWeight.w400),
      disabledYearTextStyle:
          const TextStyle(color: Colors.grey, fontWeight: FontWeight.w400),
      disableVibration: true,
    );

    return CalendarDatePicker2(
      config: config,
      displayedMonthDate: controller.selectedDate,
      value:
          controller.hasJourneyOnSelectedDate ? [controller.selectedDate] : [],
      onValueChanged: (dates) {
        AppHaptics.selection();
        _runWithLoading(() => controller.selectDate(dates.first));
      },
      onDisplayedMonthChanged: (value) {
        AppHaptics.selection();
        _runWithLoading(() => controller.displayMonth(value));
      },
    );
  }

  Widget _buildHeaderSelector(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style:
                (compact ? AppTypography.sectionLabel : AppTypography.cardTitle)
                    .copyWith(color: StyleConstants.inkColor),
          ),
          const Icon(
            Icons.arrow_drop_down,
            color: StyleConstants.deepGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context) {
    final label = _filterLabel(context);
    final tooltip = '${context.tr('journey.list.filter_layers')}: $label';
    return CustomPopup(
      position: PopupPosition.bottom,
      horizontalOffset: -8,
      verticalOffset: 8,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      contentRadius: 12,
      barrierColor: Colors.transparent,
      content: PointerInterceptor(
        child: JourneyLayerFilterMenu(
          selectedKinds: controller.selectedJourneyKinds,
          onChanged: (kinds) {
            AppHaptics.selection();
            _runWithLoading(() => controller.setJourneyKinds(kinds));
          },
        ),
      ),
      child: PointerInterceptor(
        child: Tooltip(
          message: tooltip,
          child: Semantics(
            label: tooltip,
            button: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: (compact
                            ? AppTypography.sectionLabel
                            : AppTypography.cardTitle)
                        .copyWith(color: StyleConstants.inkColor),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: StyleConstants.deepGreen,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _filterLabel(BuildContext context) {
    if (controller.selectedJourneyKinds.length == 2) {
      return context.tr('journey.list.filter_all_layers');
    }
    return controller.selectedJourneyKinds.single == JourneyKind.defaultKind
        ? context.tr('journey_kind.default')
        : context.tr('journey_kind.flight');
  }

  void _runWithLoading(Future<void> Function() task) {
    unawaited(GlobalLoadingManager.instance.runWithLoading(task));
  }
}
