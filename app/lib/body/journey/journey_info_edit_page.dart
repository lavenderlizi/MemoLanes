import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:memolanes/common/component/app_button.dart';
import 'package:memolanes/body/settings/import_data_page.dart' show ImportType;
import 'package:memolanes/common/component/basic_bottom_sheet.dart';
import 'package:memolanes/common/component/app_option_tile.dart';
import 'package:memolanes/common/component/scroll_views/single_child_scroll_view.dart';
import 'package:memolanes/common/component/tiles/label_tile.dart';
import 'package:memolanes/common/component/tiles/label_tile_content.dart';
import 'package:memolanes/common/utils.dart';
import 'package:memolanes/constants/app_typography.dart';
import 'package:memolanes/constants/style_constants.dart';
import 'package:memolanes/src/rust/api/import.dart' as import_api;
import 'package:memolanes/src/rust/api/utils.dart';
import 'package:memolanes/src/rust/journey_header.dart';

class JourneyInfoEditPage extends StatefulWidget {
  const JourneyInfoEditPage({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.journeyDate,
    required this.note,
    required this.saveData,
    this.previewData,
    this.journeyKind,
    this.importType,
    this.preprocessor,
  });

  final DateTime? startTime;
  final DateTime? endTime;
  final NaiveDate journeyDate;
  final String? note;
  final JourneyKind? journeyKind;
  final Function saveData;
  final Function? previewData;
  final ImportType? importType;
  final import_api.ImportPreprocessor? preprocessor;

  @override
  State<JourneyInfoEditPage> createState() => _JourneyInfoEditPageState();
}

class _JourneyInfoEditPageState extends State<JourneyInfoEditPage> {
  final DateFormat dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  final DateFormat dateFormat = DateFormat("yyyy-MM-dd");
  final DateTime firstDate = DateTime(1990);
  DateTime? _startTime;
  DateTime? _endTime;
  DateTime? _journeyDate;
  String? _note;
  JourneyKind _journeyKind = JourneyKind.defaultKind;
  final TextEditingController _noteController = TextEditingController();
  late import_api.ImportPreprocessor _preprocessor;

  Future<DateTime?> selectDateAndTime(
      BuildContext context, DateTime? datetime) async {
    final now = DateTime.now();
    datetime ??= now;
    DateTime? selectedDateTime = await showDatePicker(
      context: context,
      initialDate: datetime,
      firstDate: firstDate,
      lastDate: now,
    );

    if (selectedDateTime == null) return null;
    if (!context.mounted) return null;

    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: datetime.hour, minute: datetime.minute),
    );

    if (selectedTime == null) return null;

    return DateTime(
      selectedDateTime.year,
      selectedDateTime.month,
      selectedDateTime.day,
      selectedTime.hour,
      selectedTime.minute,
    );
  }

  @override
  void initState() {
    super.initState();
    setState(() {
      _startTime = widget.startTime;
      _endTime = widget.endTime;
      _journeyDate = naiveDateToDateTime(widget.journeyDate);
      _note = widget.note;
      _journeyKind = widget.journeyKind ?? _journeyKind;
      _noteController.text = _note ?? "";
    });
    _noteController.addListener(() {
      setState(() {
        _note = _noteController.text;
      });
    });
    _preprocessor =
        widget.preprocessor ?? import_api.ImportPreprocessor.generic;
    _selectPreprocessor(_preprocessor);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _saveData(BuildContext context) async {
    if (_journeyDate == null) {
      Fluttertoast.showToast(msg: context.tr("journey.journey_date_is_empty"));
      return;
    }
    _note ??= "";
    import_api.JourneyInfo journeyInfo = import_api.JourneyInfo(
        journeyDate: dateTimeToNaiveDate(_journeyDate!),
        startTime: _startTime,
        endTime: _endTime,
        note: _note,
        journeyKind: _journeyKind);
    if (widget.importType != null) {
      await widget.saveData(journeyInfo, _preprocessor);
    } else {
      await widget.saveData(journeyInfo);
    }
    if (!context.mounted) return;
    popCurrentRoute(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQueryData.fromView(View.of(context)).size.width;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: 440,
        minHeight: 420,
      ),
      child: MlSingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LabelTile(
            label: context.tr("journey.start_time"),
            position: LabelTilePosition.single,
            trailing: LabelTileContent(
                content: _startTime != null
                    ? dateTimeFormat.format(_startTime!.toLocal())
                    : ""),
            onTap: () async {
              DateTime? time = await selectDateAndTime(context, _startTime);
              if (time != null) {
                setState(() {
                  _startTime = time;
                });
              }
            },
          ),
          LabelTile(
            label: context.tr("journey.end_time"),
            position: LabelTilePosition.single,
            trailing: LabelTileContent(
                content: _endTime != null
                    ? dateTimeFormat.format(_endTime!.toLocal())
                    : ""),
            onTap: () async {
              DateTime? time = await selectDateAndTime(context, _endTime);
              if (time != null) {
                setState(() {
                  _endTime = time;
                });
              }
            },
          ),
          LabelTile(
            label: context.tr("journey.journey_date"),
            position: LabelTilePosition.single,
            trailing: LabelTileContent(
                content: _journeyDate != null
                    ? dateFormat.format(_journeyDate!)
                    : ''),
            onTap: () async {
              DateTime? time = await showDatePicker(
                context: context,
                initialDate: _journeyDate,
                firstDate: firstDate,
                lastDate: DateTime.now(),
              );
              if (time != null) {
                setState(() {
                  _journeyDate = time;
                });
              }
            },
          ),
          if (widget.importType != null)
            widget.importType == ImportType.fow
                ? SizedBox.shrink()
                : LabelTile(
                    label: context.tr("journey.preprocessor"),
                    infoLabelOnTap: () => showCommonDialog(
                      context,
                      context.tr("preprocessor.description_md"),
                      markdown: true,
                    ),
                    position: LabelTilePosition.single,
                    trailing: LabelTileContent(
                      content: switch (_preprocessor) {
                        import_api.ImportPreprocessor.none =>
                          context.tr("preprocessor.none"),
                        import_api.ImportPreprocessor.generic =>
                          context.tr("preprocessor.generic"),
                        import_api.ImportPreprocessor.flightTrack =>
                          context.tr("preprocessor.flightTrack"),
                        import_api.ImportPreprocessor.spare =>
                          context.tr("preprocessor.spare"),
                      },
                      showArrow: true,
                    ),
                    onTap: () => _showJourneyPreprocessorCard(context),
                  ),
          LabelTile(
            label: context.tr("journey.journey_kind"),
            position: LabelTilePosition.single,
            trailing: LabelTileContent(
                content: _journeyKind == JourneyKind.defaultKind
                    ? context.tr("journey_kind.default")
                    : context.tr("journey_kind.flight"),
                showArrow: true),
            onTap: () => _showJourneyKindCard(context),
          ),
          LabelTile(
            label: context.tr("journey.note"),
            position: LabelTilePosition.single,
            maxHeight: 150,
            trailing: SizedBox(
              width: width * 0.6,
              child: TextField(
                controller: _noteController,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                maxLines: 5,
                minLines: 1,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  hintText: context.tr("common.please_enter"),
                  hintStyle: AppTypography.body.copyWith(
                    color: StyleConstants.mutedInkColor,
                  ),
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          SizedBox(
            width: 280,
            child: AppButton(
              label: context.tr("common.save"),
              onPressed: () => _saveData(context),
              expand: true,
            ),
          ),
        ],
      ),
    );
  }

  void _showJourneyKindCard(BuildContext context) {
    showBasicCard(
      context,
      title: context.tr("journey.journey_kind"),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppOptionTile(
            icon: Icons.landscape_outlined,
            title: context.tr("journey_kind.default"),
            selected: _journeyKind == JourneyKind.defaultKind,
            trailing: AppOptionTileTrailing.selection,
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _journeyKind = JourneyKind.defaultKind;
              });
            },
          ),
          const SizedBox(height: 8),
          AppOptionTile(
            icon: Icons.flight_rounded,
            title: context.tr("journey_kind.flight"),
            selected: _journeyKind == JourneyKind.flight,
            trailing: AppOptionTileTrailing.selection,
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _journeyKind = JourneyKind.flight;
              });
            },
          ),
        ],
      ),
    );
  }

  void _selectPreprocessor(import_api.ImportPreprocessor processor) {
    setState(() {
      _preprocessor = processor;
    });
    widget.previewData?.call(_preprocessor);
  }

  void _showJourneyPreprocessorCard(BuildContext context) {
    showBasicCard(
      context,
      title: context.tr("journey.preprocessor"),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppOptionTile(
            icon: Icons.block_rounded,
            title: context.tr("preprocessor.none"),
            selected: _preprocessor == import_api.ImportPreprocessor.none,
            trailing: AppOptionTileTrailing.selection,
            onTap: () {
              Navigator.of(context).pop();
              _selectPreprocessor(import_api.ImportPreprocessor.none);
            },
          ),
          const SizedBox(height: 8),
          AppOptionTile(
            icon: Icons.route_outlined,
            title: context.tr("preprocessor.generic"),
            selected: _preprocessor == import_api.ImportPreprocessor.generic,
            trailing: AppOptionTileTrailing.selection,
            onTap: () {
              Navigator.of(context).pop();
              _selectPreprocessor(import_api.ImportPreprocessor.generic);
            },
          ),
          const SizedBox(height: 8),
          AppOptionTile(
            icon: Icons.flight_takeoff_rounded,
            title: context.tr("preprocessor.flightTrack"),
            selected:
                _preprocessor == import_api.ImportPreprocessor.flightTrack,
            trailing: AppOptionTileTrailing.selection,
            onTap: () {
              Navigator.of(context).pop();
              _selectPreprocessor(import_api.ImportPreprocessor.flightTrack);
            },
          ),
          const SizedBox(height: 8),
          AppOptionTile(
            icon: Icons.scatter_plot_outlined,
            title: context.tr("preprocessor.spare"),
            selected: _preprocessor == import_api.ImportPreprocessor.spare,
            trailing: AppOptionTileTrailing.selection,
            onTap: () {
              Navigator.of(context).pop();
              _selectPreprocessor(import_api.ImportPreprocessor.spare);
            },
          ),
        ],
      ),
    );
  }
}
