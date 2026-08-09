import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:memolanes/body/journey/journey_info_page.dart';
import 'package:memolanes/common/component/tiles/label_tile.dart';
import 'package:memolanes/common/component/tiles/label_tile_content.dart';
import 'package:memolanes/common/app_haptics.dart';
import 'package:memolanes/constants/index.dart';
import 'package:memolanes/src/rust/api/api.dart' as api;
import 'package:memolanes/src/rust/api/utils.dart';
import 'package:memolanes/common/utils.dart';
import 'package:memolanes/src/rust/journey_header.dart';
import 'package:memolanes/utils/nav_helper.dart';

class JourneyBody extends StatefulWidget {
  const JourneyBody({super.key});

  @override
  State<JourneyBody> createState() => _JourneyBodyState();
}

class _JourneyBodyState extends State<JourneyBody> {
  static const _landscapeContentPadding = 16.0;
  static const _landscapeColumnGap = 16.0;
  static const _landscapeCalendarMinWidth = 320.0;
  static const _landscapeCalendarMaxWidth = 360.0;
  static const _landscapeListMinWidth = 280.0;

  List<JourneyHeader> _journeyHeaderList = [];

  DateTime _selectedDate = DateTime.now();
  late final DateTime? _firstDate;
  final lastDate = DateTime.now();
  late List<int> _yearsWithJourneyList;
  late List<int> _monthsWithJourneyList;
  late List<int> _daysWithJourneyList;
  bool _isLoadingFirstDate = true;

  @override
  void initState() {
    super.initState();
    _initialize();
    _updateJourneyHeaderList();
  }

  Future<void> _initialize() async {
    NaiveDate? earliestDate = await api.earliestJourneyDate();
    if (earliestDate != null) {
      _firstDate = naiveDateToDateTime(earliestDate);
    } else {
      _firstDate = null;
    }
    _yearsWithJourneyList = await api.yearsWithJourney();
    _monthsWithJourneyList =
        await api.monthsWithJourney(year: _selectedDate.year);
    _daysWithJourneyList = await api.daysWithJourney(
        year: _selectedDate.year, month: _selectedDate.month);
    if (!mounted) return;
    setState(() {
      _isLoadingFirstDate = false;
    });
  }

  void _updateJourneyHeaderList() async {
    final journeyHeaderList = await api.listJourneyOnDate(
        year: _selectedDate.year,
        month: _selectedDate.month,
        day: _selectedDate.day);
    if (!mounted) return;
    setState(() {
      _journeyHeaderList = journeyHeaderList.reversed.toList();
    });
  }

  Widget _buildDatePickerWithValue(DateTime firstDate) {
    final config = CalendarDatePicker2Config(
      firstDate: firstDate,
      lastDate: DateTime.now(),
      centerAlignModePicker: true,
      calendarType: CalendarDatePicker2Type.single,
      selectedDayHighlightColor: StyleConstants.primaryGreen,
      dayTextStyle: const TextStyle(
        color: StyleConstants.inkColor,
      ),
      weekdayLabelTextStyle: const TextStyle(
        color: StyleConstants.mutedInkColor,
        fontWeight: FontWeight.bold,
      ),
      controlsTextStyle: const TextStyle(
        color: StyleConstants.inkColor,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
      selectableYearPredicate: (year) => _yearsWithJourneyList.contains(year),
      selectableMonthPredicate: (year, month) =>
          _monthsWithJourneyList.contains(month),
      selectableDayPredicate: (day) => _daysWithJourneyList.contains(day.day),
      dayBuilder: ({
        required date,
        textStyle,
        decoration,
        isSelected,
        isDisabled,
        isToday,
      }) {
        Widget? dayWidget;
        if (_daysWithJourneyList.contains(date.day)) {
          dayWidget = Container(
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
                    padding: const EdgeInsets.only(top: 27.5),
                    child: Container(
                      height: 4,
                      width: 4,
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
        }
        return dayWidget;
      },
      dynamicCalendarRows: true,
      disabledDayTextStyle:
          const TextStyle(color: Colors.grey, fontWeight: FontWeight.w400),
      disabledMonthTextStyle:
          const TextStyle(color: Colors.grey, fontWeight: FontWeight.w400),
      disabledYearTextStyle:
          const TextStyle(color: Colors.grey, fontWeight: FontWeight.w400),
      // Turn off CalendarDatePicker2's own vibration; it varies by platform.
      // We call AppHaptics on date/month changes instead.
      // TODO: Fix CalendarDatePicker2's built-in vibration being inconsistent
      //       across platforms (local patch or upstream), so we can rely on it.
      disableVibration: true,
    );
    return CalendarDatePicker2(
      config: config,
      value: [_selectedDate],
      onValueChanged: (dates) {
        AppHaptics.selection();
        setState(() => _selectedDate = dates.first);
        _updateJourneyHeaderList();
      },
      onDisplayedMonthChanged: (value) async {
        AppHaptics.selection();
        DateTime jumpToDate =
            DateTime(value.year, value.month, _selectedDate.day);
        DateTime jumpToDateMonthLastDay =
            DateTime(value.year, value.month + 1, 0);
        if (_selectedDate.day > jumpToDateMonthLastDay.day) {
          jumpToDate = jumpToDateMonthLastDay;
        }
        if (lastDate.isBefore(jumpToDate)) {
          jumpToDate = lastDate;
        }
        if (firstDate.isAfter(jumpToDate)) {
          jumpToDate = firstDate;
        }
        if (value.year != _selectedDate.year) {
          _monthsWithJourneyList =
              await api.monthsWithJourney(year: jumpToDate.year);
        }

        _daysWithJourneyList = await api.daysWithJourney(
            month: jumpToDate.month, year: jumpToDate.year);
        if (!mounted) return;
        setState(() {
          _selectedDate = jumpToDate;
        });
        _updateJourneyHeaderList();
      },
    );
  }

  Widget _buildJourneyHeaderList() {
    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: StyleConstants.navBarSafeArea + 5,
      ),
      itemCount: _journeyHeaderList.length,
      itemBuilder: (context, index) {
        return LabelTile(
          label: _journeyHeaderList[index].start != null
              ? DateFormat("yyyy-MM-dd HH:mm:ss")
                  .format(_journeyHeaderList[index].start!.toLocal())
              : naiveDateToString(date: _journeyHeaderList[index].journeyDate),
          trailing: LabelTileContent(showArrow: true),
          prefix: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: StyleConstants.softGreen,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.route_rounded,
                color: StyleConstants.deepGreen,
                size: 18,
              ),
            ),
          ),
          onTap: () {
            navigatorPush(
              context,
              page: JourneyInfoPage(
                journeyHeader: _journeyHeaderList[index],
              ),
            ).then((refresh) async {
              if (refresh != null && refresh) {
                _yearsWithJourneyList = await api.yearsWithJourney();
                _monthsWithJourneyList =
                    await api.monthsWithJourney(year: _selectedDate.year);
                _daysWithJourneyList = await api.daysWithJourney(
                    year: _selectedDate.year, month: _selectedDate.month);
                if (!mounted) return;
                _updateJourneyHeaderList();
              }
            });
          },
        );
      },
    );
  }

  Widget _buildLandscapeBody(DateTime firstDate) {
    const bottomPadding = StyleConstants.navBarSafeArea + 5;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth -
            _landscapeContentPadding * 2 -
            _landscapeColumnGap;
        final preferredCalendarWidth = availableWidth * 0.42;
        final maxCalendarWidth = (availableWidth - _landscapeListMinWidth)
            .clamp(0.0, _landscapeCalendarMaxWidth)
            .toDouble();
        final minCalendarWidth = maxCalendarWidth < _landscapeCalendarMinWidth
            ? maxCalendarWidth
            : _landscapeCalendarMinWidth;
        final calendarWidth = preferredCalendarWidth
            .clamp(minCalendarWidth, maxCalendarWidth)
            .toDouble();

        return Padding(
          padding: const EdgeInsets.all(_landscapeContentPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: calendarWidth,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: bottomPadding),
                  child: _buildDatePickerWithValue(firstDate),
                ),
              ),
              const SizedBox(width: _landscapeColumnGap),
              Expanded(
                child: _buildJourneyHeaderList(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingFirstDate) {
      return const Center(child: CircularProgressIndicator());
    }
    final firstDate = _firstDate;
    if (firstDate == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _JourneyPageHeader(),
            Expanded(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 360),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: StyleConstants.surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: StyleConstants.lineColor),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                          color: StyleConstants.softYellow,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.map_outlined,
                          color: StyleConstants.inkColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('journey.no_data'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: StyleConstants.mutedInkColor,
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      final isLandscape =
          MediaQuery.of(context).orientation == Orientation.landscape;
      if (isLandscape) {
        return _buildLandscapeBody(firstDate);
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _JourneyPageHeader(),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: StyleConstants.surfaceColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: StyleConstants.lineColor),
              ),
              child: _buildDatePickerWithValue(firstDate),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('journey.records_title'),
              style: const TextStyle(
                color: StyleConstants.inkColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(child: _buildJourneyHeaderList()),
          ],
        ),
      );
    }
  }
}

class _JourneyPageHeader extends StatelessWidget {
  const _JourneyPageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('journey.editor_overview_title'),
          style: const TextStyle(
            color: StyleConstants.inkColor,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          context.tr('journey.editor_overview_subtitle'),
          style: const TextStyle(
            color: StyleConstants.mutedInkColor,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
