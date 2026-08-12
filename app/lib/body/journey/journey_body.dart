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
  const JourneyBody({
    super.key,
    this.onJourneySelected,
    this.compactPicker = false,
  });

  /// When supplied, tapping a row selects it instead of opening the details
  /// page. This lets the existing calendar/list work inside the map picker.
  final Future<void> Function(JourneyHeader journey)? onJourneySelected;

  /// Removes the full-page heading and tightens spacing for the floating map
  /// picker. The calendar remains above a separately scrollable journey list.
  final bool compactPicker;

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
  final ScrollController _journeyListController = ScrollController();

  DateTime _selectedDate = DateTime.now();
  late final DateTime? _firstDate;
  final lastDate = DateTime.now();
  late List<int> _yearsWithJourneyList;
  late List<int> _monthsWithJourneyList;
  late List<int> _daysWithJourneyList;
  bool _isLoadingFirstDate = true;
  int _journeyListRequestId = 0;
  int _calendarRequestId = 0;

  bool get _isSelectionMode => widget.onJourneySelected != null;
  bool get _isCompactPicker => _isSelectionMode && widget.compactPicker;

  @override
  void initState() {
    super.initState();
    _initialize();
    _updateJourneyHeaderList();
  }

  @override
  void dispose() {
    _journeyListController.dispose();
    super.dispose();
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
    final requestId = ++_journeyListRequestId;
    final journeyHeaderList = await api.listJourneyOnDate(
        year: _selectedDate.year,
        month: _selectedDate.month,
        day: _selectedDate.day);
    if (!mounted || requestId != _journeyListRequestId) return;
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
      controlsHeight: _isCompactPicker ? 38 : null,
      dayMaxWidth: _isCompactPicker ? 30 : null,
      dayTextStyle: TextStyle(
        color: StyleConstants.inkColor,
        fontSize: _isCompactPicker ? 12 : null,
      ),
      weekdayLabelTextStyle: TextStyle(
        color: StyleConstants.mutedInkColor,
        fontSize: _isCompactPicker ? 11 : null,
        fontWeight: FontWeight.bold,
      ),
      controlsTextStyle: TextStyle(
        color: StyleConstants.inkColor,
        fontSize: _isCompactPicker ? 13 : 15,
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
                    padding: EdgeInsets.only(
                      top: _isCompactPicker ? 20 : 27.5,
                    ),
                    child: Container(
                      height: _isCompactPicker ? 3 : 4,
                      width: _isCompactPicker ? 3 : 4,
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
      disabledDayTextStyle: TextStyle(
        color: Colors.grey,
        fontSize: _isCompactPicker ? 12 : null,
        fontWeight: FontWeight.w400,
      ),
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
        final requestId = ++_calendarRequestId;
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
        final monthsWithJourneys = value.year != _selectedDate.year
            ? await api.monthsWithJourney(year: jumpToDate.year)
            : _monthsWithJourneyList;
        final daysWithJourneys = await api.daysWithJourney(
            month: jumpToDate.month, year: jumpToDate.year);
        if (!mounted || requestId != _calendarRequestId) return;
        setState(() {
          _monthsWithJourneyList = monthsWithJourneys;
          _daysWithJourneyList = daysWithJourneys;
          _selectedDate = jumpToDate;
        });
        _updateJourneyHeaderList();
      },
    );
  }

  Widget _buildJourneyHeaderList() {
    final journeyList = ListView.builder(
      controller: _journeyListController,
      padding: EdgeInsets.only(
        right: _isCompactPicker ? 12 : 0,
        bottom: _isSelectionMode ? 20 : StyleConstants.navBarSafeArea + 5,
      ),
      itemCount: _journeyHeaderList.length,
      itemBuilder: (context, index) {
        final journeyHeader = _journeyHeaderList[index];
        return LabelTile(
          label: journeyHeader.start != null
              ? DateFormat("yyyy-MM-dd HH:mm:ss")
                  .format(journeyHeader.start!.toLocal())
              : naiveDateToString(date: journeyHeader.journeyDate),
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
          onTap: () async {
            final onJourneySelected = widget.onJourneySelected;
            if (onJourneySelected != null) {
              AppHaptics.selection();
              await onJourneySelected(journeyHeader);
              return;
            }
            navigatorPush(
              context,
              page: JourneyInfoPage(
                journeyHeader: journeyHeader,
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

    if (!_isCompactPicker) return journeyList;

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          StyleConstants.deepGreen.withValues(alpha: 0.72),
        ),
        trackColor: WidgetStatePropertyAll(
          StyleConstants.softGreen.withValues(alpha: 0.88),
        ),
        trackBorderColor: const WidgetStatePropertyAll(
          StyleConstants.lineColor,
        ),
      ),
      child: Scrollbar(
        controller: _journeyListController,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        thickness: 6,
        radius: const Radius.circular(99),
        scrollbarOrientation: ScrollbarOrientation.right,
        child: journeyList,
      ),
    );
  }

  Widget _buildLandscapeBody(DateTime firstDate) {
    final bottomPadding =
        _isSelectionMode ? 20.0 : StyleConstants.navBarSafeArea + 5;

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
        padding: EdgeInsets.fromLTRB(
          _isCompactPicker ? 14 : 20,
          _isCompactPicker ? 12 : 28,
          _isCompactPicker ? 14 : 20,
          _isSelectionMode ? 24 : 140,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isCompactPicker)
              _JourneyPageHeader(selectionMode: _isSelectionMode),
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
        padding: EdgeInsets.fromLTRB(
          _isCompactPicker ? 12 : 16,
          _isCompactPicker ? 10 : 22,
          _isCompactPicker ? 12 : 16,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isCompactPicker) ...[
              _JourneyPageHeader(selectionMode: _isSelectionMode),
              const SizedBox(height: 18),
            ],
            Container(
              decoration: BoxDecoration(
                color: StyleConstants.surfaceColor,
                borderRadius: BorderRadius.circular(_isCompactPicker ? 18 : 22),
                border: Border.all(color: StyleConstants.lineColor),
              ),
              child: _buildDatePickerWithValue(firstDate),
            ),
            SizedBox(height: _isCompactPicker ? 10 : 16),
            Text(
              context.tr('journey.records_title'),
              style: TextStyle(
                color: StyleConstants.inkColor,
                fontSize: _isCompactPicker ? 14 : 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: _isCompactPicker ? 6 : 10),
            Expanded(child: _buildJourneyHeaderList()),
          ],
        ),
      );
    }
  }
}

class _JourneyPageHeader extends StatelessWidget {
  const _JourneyPageHeader({required this.selectionMode});

  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(selectionMode
              ? 'journey.picker_title'
              : 'journey.editor_overview_title'),
          style: TextStyle(
            color: StyleConstants.inkColor,
            fontSize: selectionMode ? 24 : 28,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          context.tr(selectionMode
              ? 'journey.picker_subtitle'
              : 'journey.editor_overview_subtitle'),
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
