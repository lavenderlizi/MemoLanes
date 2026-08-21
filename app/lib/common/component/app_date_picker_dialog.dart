import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:memolanes/common/app_haptics.dart';
import 'package:memolanes/common/component/app_button.dart';
import 'package:memolanes/common/component/app_dialog.dart';
import 'package:memolanes/constants/app_typography.dart';
import 'package:memolanes/constants/style_constants.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

const _fullHeaderMinViewportWidth = 380.0;

/// Shows the compact calendar dialog shared by Journey and Time Machine.
Future<DateTime?> showAppDatePickerDialog(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  bool highlightInitialDate = false,
  double glassBackgroundAlpha = 0.84,
}) {
  assert(!firstDate.isAfter(lastDate));
  assert(!initialDate.isBefore(firstDate));
  assert(!initialDate.isAfter(lastDate));
  assert(glassBackgroundAlpha >= 0 && glassBackgroundAlpha <= 1);

  return showDialog<DateTime>(
    context: context,
    barrierColor: StyleConstants.inkColor.withValues(alpha: 0.2),
    builder: (_) => PointerInterceptor(
      child: _AppDatePickerDialog(
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        highlightInitialDate: highlightInitialDate,
        glassBackgroundAlpha: glassBackgroundAlpha,
      ),
    ),
  );
}

class _AppDatePickerDialog extends StatefulWidget {
  const _AppDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.highlightInitialDate,
    required this.glassBackgroundAlpha,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool highlightInitialDate;
  final double glassBackgroundAlpha;

  @override
  State<_AppDatePickerDialog> createState() => _AppDatePickerDialogState();
}

class _AppDatePickerDialogState extends State<_AppDatePickerDialog> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  Widget _buildDay({
    required DateTime date,
    required TextStyle? textStyle,
    required bool? isSelected,
  }) {
    final selected = isSelected == true;
    final showInitialDate = widget.highlightInitialDate &&
        DateUtils.isSameDay(date, widget.initialDate);

    return Center(
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: selected
            ? const BoxDecoration(
                shape: BoxShape.circle,
                color: StyleConstants.primaryGreen,
              )
            : showInitialDate
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: StyleConstants.primaryGreen,
                      width: 2,
                    ),
                  )
                : null,
        child: Text(
          MaterialLocalizations.of(context).formatDecimal(date.day),
          style: selected
              ? AppTypography.caption.copyWith(
                  color: StyleConstants.inkColor,
                )
              : textStyle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final useCompactHeader =
        MediaQuery.sizeOf(context).width < _fullHeaderMinViewportWidth;
    final config = CalendarDatePicker2Config(
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      calendarType: CalendarDatePicker2Type.single,
      centerAlignModePicker: true,
      disableMonthPicker: useCompactHeader,
      controlsHeight: 38,
      dayMaxWidth: 30,
      dynamicCalendarRows: true,
      disableVibration: true,
      daySplashColor: Colors.transparent,
      selectedDayHighlightColor: Colors.transparent,
      dayTextStyle: AppTypography.caption.copyWith(
        color: StyleConstants.inkColor,
      ),
      selectedDayTextStyle: AppTypography.caption.copyWith(
        color: StyleConstants.inkColor,
      ),
      todayTextStyle: AppTypography.label.copyWith(
        color: StyleConstants.deepGreen,
        fontWeight: FontWeight.w700,
      ),
      weekdayLabelTextStyle: AppTypography.micro.copyWith(
        color: StyleConstants.mutedInkColor,
      ),
      controlsTextStyle: AppTypography.sectionLabel.copyWith(
        color: StyleConstants.deepGreen,
      ),
      disabledDayTextStyle: AppTypography.caption.copyWith(
        color: StyleConstants.mutedInkColor.withValues(alpha: 0.42),
      ),
      lastMonthIcon: const Icon(
        Icons.chevron_left_rounded,
        color: StyleConstants.deepGreen,
        size: 20,
      ),
      nextMonthIcon: const Icon(
        Icons.chevron_right_rounded,
        color: StyleConstants.deepGreen,
        size: 20,
      ),
      dayBuilder: ({
        required date,
        textStyle,
        decoration,
        isSelected,
        isDisabled,
        isToday,
      }) {
        return _buildDay(
          date: date,
          textStyle: textStyle,
          isSelected: isSelected,
        );
      },
    );

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: AppDialogSurface(
          style: AppDialogSurfaceStyle.glass,
          glassBackgroundAlpha: widget.glassBackgroundAlpha,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 290,
                  child: CalendarDatePicker2(
                    config: config,
                    value: [_selectedDate],
                    onValueChanged: (dates) {
                      final selected = dates.firstOrNull;
                      if (selected == null) return;
                      AppHaptics.selection();
                      setState(() => _selectedDate = selected);
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 112,
                      child: AppButton(
                        label: localizations.cancelButtonLabel,
                        icon: Icons.close_rounded,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.compact,
                        expand: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 112,
                      child: AppButton(
                        label: localizations.okButtonLabel,
                        icon: Icons.check_rounded,
                        variant: AppButtonVariant.primary,
                        size: AppButtonSize.compact,
                        expand: true,
                        onPressed: () =>
                            Navigator.of(context).pop(_selectedDate),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
