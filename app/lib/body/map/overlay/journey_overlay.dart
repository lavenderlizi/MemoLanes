import 'dart:math' as math;

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:memolanes/body/journey/journey_body.dart';
import 'package:memolanes/body/journey/journey_export.dart';
import 'package:memolanes/body/journey/journey_track_edit_page.dart';
import 'package:memolanes/common/app_haptics.dart';
import 'package:memolanes/common/component/app_button.dart';
import 'package:memolanes/common/component/app_dialog.dart';
import 'package:memolanes/common/component/app_option_tile.dart';
import 'package:memolanes/common/component/base_map_webview.dart';
import 'package:memolanes/common/component/liquid_glass_surface.dart';
import 'package:memolanes/common/utils.dart';
import 'package:memolanes/constants/style_constants.dart';
import 'package:memolanes/src/rust/api/api.dart' as api;
import 'package:memolanes/src/rust/api/edit_session.dart' show EditSession;
import 'package:memolanes/src/rust/api/import.dart' show JourneyInfo;
import 'package:memolanes/src/rust/api/utils.dart';
import 'package:memolanes/src/rust/journey_header.dart';
import 'package:memolanes/utils/nav_helper.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// Journeys keeps the current map visible without Record mode's three map
/// controls. Its picker is an in-page floating card, so the app navigation bar
/// remains visible and unobstructed below it.
class JourneyOverlay extends StatefulWidget {
  const JourneyOverlay({
    super.key,
    required this.onJourneyMapChanged,
  });

  final void Function(
    api.MapRendererProxy? proxy,
    MapBounds? bounds,
    String? journeyId,
  ) onJourneyMapChanged;

  @override
  State<JourneyOverlay> createState() => _JourneyOverlayState();
}

class _JourneyOverlayState extends State<JourneyOverlay> {
  bool _isLoadingJourney = false;
  bool _isEditingInformation = false;
  JourneyHeader? _selectedJourney;

  Future<void> _openJourneyDetails(JourneyHeader journey) async {
    if (_isLoadingJourney) return;
    setState(() => _isLoadingJourney = true);

    try {
      final rendererAndBounds = await api.getMapRendererProxyForJourney(
        journeyId: journey.id,
      );
      if (!mounted) return;
      widget.onJourneyMapChanged(
        rendererAndBounds.$1,
        rendererAndBounds.$2,
        journey.id,
      );
      setState(() {
        _selectedJourney = journey;
        _isEditingInformation = false;
      });
    } finally {
      if (mounted) setState(() => _isLoadingJourney = false);
    }
  }

  void _returnToPicker() {
    AppHaptics.light();
    widget.onJourneyMapChanged(null, null, null);
    setState(() {
      _selectedJourney = null;
      _isEditingInformation = false;
    });
  }

  Future<void> _refreshSelectedJourney() async {
    final selected = _selectedJourney;
    if (selected == null) return;

    final allJourneys = await api.listAllJourneys();
    JourneyHeader? latest;
    for (final journey in allJourneys) {
      if (journey.id == selected.id) {
        latest = journey;
        break;
      }
    }
    if (!mounted || _selectedJourney?.id != selected.id) return;
    if (latest == null) {
      _returnToPicker();
      return;
    }

    final rendererAndBounds = await api.getMapRendererProxyForJourney(
      journeyId: latest.id,
    );
    if (!mounted || _selectedJourney?.id != selected.id) return;
    widget.onJourneyMapChanged(
      rendererAndBounds.$1,
      rendererAndBounds.$2,
      latest.id,
    );
    setState(() => _selectedJourney = latest);
  }

  Future<void> _saveJourneyInformation(JourneyInfo journeyInfo) async {
    final selected = _selectedJourney;
    if (selected == null) return;
    await api.updateJourneyMetadata(id: selected.id, journeyInfo: journeyInfo);
  }

  Future<void> _deleteSelectedJourney() async {
    final selected = _selectedJourney;
    if (selected == null) return;
    final shouldDelete = await showCommonDialog(
      context,
      context.tr('journey.delete_journey_message'),
      hasCancel: true,
      title: context.tr('journey.delete_journey_title'),
      confirmButtonText: context.tr('common.delete'),
      confirmVariant: AppButtonVariant.danger,
    );
    if (!shouldDelete) return;
    await api.deleteJourney(journeyId: selected.id);
    if (!mounted) return;
    _returnToPicker();
  }

  Future<void> _exportSelectedJourney() async {
    final selected = _selectedJourney;
    if (selected == null) return;
    await showJourneyExportPicker(context, selected);
  }

  Future<void> _openTrackEditor() async {
    final selected = _selectedJourney;
    if (selected == null) return;
    final session = await EditSession.newInstance(journeyId: selected.id);
    if (!mounted) return;
    if (session == null) {
      await showCommonDialog(
        context,
        context.tr('journey.editor.bitmap_not_supported'),
      );
      return;
    }
    await navigatorPush<bool>(
      context,
      page: JourneyTrackEditPage(editSession: session),
    );
    if (!mounted) return;
    await _refreshSelectedJourney();
  }

  Future<void> _showEditChoice() async {
    final choice = await showDialog<_JourneyEditChoice>(
      context: context,
      barrierColor: StyleConstants.inkColor.withValues(alpha: 0.2),
      builder: (dialogContext) => PointerInterceptor(
        child: _JourneyEditChoiceDialog(
          onSelected: (choice) => Navigator.of(dialogContext).pop(choice),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _JourneyEditChoice.information:
        setState(() => _isEditingInformation = true);
        break;
      case _JourneyEditChoice.track:
        await _openTrackEditor();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final viewPadding = mediaQuery.viewPadding;
    final bottom =
        StyleConstants.mapPrimaryControlBottomInsetForContext(context);
    final availableHeight = math.max(
      260.0,
      mediaQuery.size.height - bottom - viewPadding.top - 12,
    );
    final preferredHeight =
        (mediaQuery.size.height * 0.62).clamp(390.0, 530.0).toDouble();
    final pickerHeight = math.min(preferredHeight, availableHeight);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final pickerMaxWidth = isLandscape ? 720.0 : 480.0;
    final selectedJourney = _selectedJourney;

    return Stack(
      children: [
        Positioned(
          left: viewPadding.left + 16,
          right: viewPadding.right + 16,
          bottom: bottom,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            reverseDuration: const Duration(milliseconds: 210),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0, 0.035),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: selectedJourney != null
                ? Align(
                    key: ValueKey('journey-information-${selectedJourney.id}'),
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: math.min(mediaQuery.size.width - 32, 430.0),
                      child: PointerInterceptor(
                        child: _JourneyDetailCard(
                          journey: selectedJourney,
                          isEditing: _isEditingInformation,
                          onExport: _exportSelectedJourney,
                          onEdit: _showEditChoice,
                          onDelete: _deleteSelectedJourney,
                          onSave: _saveJourneyInformation,
                          onSaved: () async {
                            await _refreshSelectedJourney();
                            if (!mounted) return;
                            setState(() => _isEditingInformation = false);
                          },
                        ),
                      ),
                    ),
                  )
                : Align(
                    key: const ValueKey('journey-picker'),
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: math.min(
                        mediaQuery.size.width -
                            viewPadding.left -
                            viewPadding.right -
                            32,
                        pickerMaxWidth,
                      ),
                      height: pickerHeight,
                      child: PointerInterceptor(
                        child: _JourneyPickerCard(
                          onJourneySelected: _openJourneyDetails,
                          isLoading: _isLoadingJourney,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        if (selectedJourney != null)
          Positioned(
            left: viewPadding.left + 16,
            top: viewPadding.top + 14,
            child: PointerInterceptor(
              child: _JourneyBackButton(onPressed: _returnToPicker),
            ),
          ),
      ],
    );
  }
}

class _JourneyPickerCard extends StatelessWidget {
  const _JourneyPickerCard({
    required this.onJourneySelected,
    required this.isLoading,
  });

  final Future<void> Function(JourneyHeader journey) onJourneySelected;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return _JourneyPanelSurface(
      backgroundAlpha: 0.76,
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 9, 8),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: StyleConstants.softGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.route_rounded,
                        size: 17,
                        color: StyleConstants.deepGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('journey.picker_title'),
                        style: const TextStyle(
                          color: StyleConstants.deepGreen,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: StyleConstants.lineColor.withValues(alpha: 0.9),
              ),
              Expanded(
                child: JourneyBody(
                  compactPicker: true,
                  onJourneySelected: onJourneySelected,
                ),
              ),
            ],
          ),
          if (isLoading)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.42),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: StyleConstants.deepGreen,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _JourneyPanelSurface extends StatelessWidget {
  const _JourneyPanelSurface({
    required this.child,
    this.backgroundAlpha = 0.84,
  });

  final Widget child;
  final double backgroundAlpha;

  @override
  Widget build(BuildContext context) {
    return AppDialogSurface(
      style: AppDialogSurfaceStyle.glass,
      glassBackgroundAlpha: backgroundAlpha,
      child: child,
    );
  }
}

class _JourneyBackButton extends StatelessWidget {
  const _JourneyBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSurface(
      circular: true,
      backgroundAlpha: 0.62,
      blurSigma: 28,
      reflectionAlpha: 0.1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 42,
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: StyleConstants.deepGreen,
              semanticLabel:
                  MaterialLocalizations.of(context).backButtonTooltip,
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyDetailCard extends StatefulWidget {
  const _JourneyDetailCard({
    required this.journey,
    required this.isEditing,
    required this.onExport,
    required this.onEdit,
    required this.onDelete,
    required this.onSave,
    required this.onSaved,
  });

  final JourneyHeader journey;
  final bool isEditing;
  final VoidCallback onExport;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function(JourneyInfo journeyInfo) onSave;
  final Future<void> Function() onSaved;

  @override
  State<_JourneyDetailCard> createState() => _JourneyDetailCardState();
}

class _JourneyDetailCardState extends State<_JourneyDetailCard> {
  static final DateTime _firstDate = DateTime(1990);

  late DateTime _journeyDate;
  DateTime? _startTime;
  DateTime? _endTime;
  late JourneyKind _journeyKind;
  final TextEditingController _noteController = TextEditingController();
  bool _saving = false;

  JourneyHeader get journey => widget.journey;

  @override
  void initState() {
    super.initState();
    _resetFields();
  }

  @override
  void didUpdateWidget(covariant _JourneyDetailCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!oldWidget.isEditing && widget.isEditing) ||
        (oldWidget.journey.revision != widget.journey.revision &&
            !widget.isEditing)) {
      _resetFields();
    }
  }

  void _resetFields() {
    _journeyDate = naiveDateToDateTime(journey.journeyDate);
    _startTime = journey.start;
    _endTime = journey.end;
    _journeyKind = journey.journeyKind;
    _noteController.text = journey.note ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  DateTime _validInitialDate(DateTime date) {
    final now = DateTime.now();
    if (date.isBefore(_firstDate)) return _firstDate;
    if (date.isAfter(now)) return now;
    return date;
  }

  Future<DateTime?> _selectDateAndTime(DateTime? current) async {
    final seed = current?.toLocal() ?? DateTime.now();
    final date = await showDialog<DateTime>(
      context: context,
      barrierColor: StyleConstants.inkColor.withValues(alpha: 0.2),
      builder: (dialogContext) => PointerInterceptor(
        child: _CompactJourneyDateDialog(
          initialDate: _validInitialDate(seed),
          firstDate: _firstDate,
          lastDate: DateTime.now(),
        ),
      ),
    );
    if (date == null || !mounted) return null;
    final time = await showDialog<TimeOfDay>(
      context: context,
      barrierColor: StyleConstants.inkColor.withValues(alpha: 0.2),
      builder: (dialogContext) => PointerInterceptor(
        child: _CompactJourneyTimeDialog(
          initialTime: TimeOfDay.fromDateTime(seed),
        ),
      ),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _selectJourneyDate() async {
    final selected = await showDialog<DateTime>(
      context: context,
      barrierColor: StyleConstants.inkColor.withValues(alpha: 0.2),
      builder: (dialogContext) => PointerInterceptor(
        child: _CompactJourneyDateDialog(
          initialDate: _validInitialDate(_journeyDate),
          firstDate: _firstDate,
          lastDate: DateTime.now(),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _journeyDate = selected);
  }

  Future<void> _selectJourneyKind() async {
    final selected = await showDialog<JourneyKind>(
      context: context,
      barrierColor: StyleConstants.inkColor.withValues(alpha: 0.2),
      builder: (dialogContext) => PointerInterceptor(
        child: Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 42),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: AppDialogCard(
              title: context.tr('journey.journey_kind'),
              surfaceStyle: AppDialogSurfaceStyle.glass,
              maxHeightFactor: 0.5,
              contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _EditChoiceTile(
                    icon: Icons.landscape_outlined,
                    title: context.tr('journey_kind.default'),
                    selected: _journeyKind == JourneyKind.defaultKind,
                    selectionMode: true,
                    onTap: () => Navigator.of(dialogContext)
                        .pop(JourneyKind.defaultKind),
                  ),
                  const SizedBox(height: 8),
                  _EditChoiceTile(
                    icon: Icons.flight_rounded,
                    title: context.tr('journey_kind.flight'),
                    selected: _journeyKind == JourneyKind.flight,
                    selectionMode: true,
                    onTap: () =>
                        Navigator.of(dialogContext).pop(JourneyKind.flight),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _journeyKind = selected);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        JourneyInfo(
          journeyDate: dateTimeToNaiveDate(_journeyDate),
          startTime: _startTime,
          endTime: _endTime,
          note: _noteController.text,
          journeyKind: _journeyKind,
        ),
      );
      await widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEditing;
    final displayedKind = isEditing ? _journeyKind : journey.journeyKind;
    final kind = switch (displayedKind) {
      JourneyKind.defaultKind => context.tr('journey_kind.default'),
      JourneyKind.flight => context.tr('journey_kind.flight'),
    };
    final timeFormat = DateFormat('yyyy-MM-dd HH:mm');
    final dateFormat = DateFormat('yyyy-MM-dd');
    final start = (isEditing ? _startTime : journey.start)?.toLocal();
    final end = (isEditing ? _endTime : journey.end)?.toLocal();
    final note = journey.note?.trim();

    return _JourneyPanelSurface(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 13),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: StyleConstants.softGreen.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.route_rounded,
                    size: 17,
                    color: StyleConstants.deepGreen,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    context.tr('journey.journey_info_page_title'),
                    style: const TextStyle(
                      color: StyleConstants.deepGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            _CompactJourneyField(
              icon: Icons.calendar_today_rounded,
              label: context.tr('journey.journey_date'),
              value: isEditing
                  ? dateFormat.format(_journeyDate)
                  : naiveDateToString(date: journey.journeyDate),
              onTap: isEditing ? _selectJourneyDate : null,
            ),
            _CompactJourneyField(
              icon: Icons.sell_outlined,
              label: context.tr('journey.journey_kind'),
              value: kind,
              onTap: isEditing ? _selectJourneyKind : null,
            ),
            _CompactJourneyField(
              icon: Icons.schedule_rounded,
              label: context.tr('journey.start_time'),
              value: start == null ? '—' : timeFormat.format(start),
              onTap: isEditing
                  ? () async {
                      final selected = await _selectDateAndTime(_startTime);
                      if (selected != null && mounted) {
                        setState(() => _startTime = selected);
                      }
                    }
                  : null,
            ),
            _CompactJourneyField(
              icon: Icons.schedule_rounded,
              label: context.tr('journey.end_time'),
              value: end == null ? '—' : timeFormat.format(end),
              onTap: isEditing
                  ? () async {
                      final selected = await _selectDateAndTime(_endTime);
                      if (selected != null && mounted) {
                        setState(() => _endTime = selected);
                      }
                    }
                  : null,
            ),
            if (isEditing)
              _CompactJourneyField(
                icon: Icons.notes_rounded,
                label: context.tr('journey.note'),
                trailing: TextField(
                  controller: _noteController,
                  minLines: 1,
                  maxLines: 2,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: StyleConstants.deepGreen,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: context.tr('common.please_enter'),
                    hintStyle: const TextStyle(
                      color: StyleConstants.mutedInkColor,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              )
            else if (note != null && note.isNotEmpty)
              _CompactJourneyField(
                icon: Icons.notes_rounded,
                label: context.tr('journey.note'),
                value: note,
                maxLines: 2,
              ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: isEditing
                  ? Center(
                      key: const ValueKey('save-journey-information'),
                      child: SizedBox(
                        width: 180,
                        child: _JourneyActionButton(
                          icon: Icons.check_rounded,
                          label: context.tr('common.save'),
                          variant: AppButtonVariant.primary,
                          onPressed: _saving ? null : _save,
                          loading: _saving,
                        ),
                      ),
                    )
                  : Row(
                      key: const ValueKey('journey-actions'),
                      children: [
                        Expanded(
                          child: _JourneyActionButton(
                            icon: Icons.ios_share_rounded,
                            label: context.tr('common.export'),
                            onPressed: widget.onExport,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _JourneyActionButton(
                            icon: Icons.edit_outlined,
                            label: context.tr('common.edit'),
                            variant: AppButtonVariant.tonal,
                            onPressed: widget.onEdit,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _JourneyActionButton(
                            icon: Icons.delete_outline_rounded,
                            label: context.tr('common.delete'),
                            variant: AppButtonVariant.danger,
                            onPressed: widget.onDelete,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactJourneyField extends StatelessWidget {
  const _CompactJourneyField({
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.maxLines = 1,
  }) : assert(value != null || trailing != null);

  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  icon,
                  size: 15,
                  color: StyleConstants.mutedInkColor,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 92,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: StyleConstants.mutedInkColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: trailing ??
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            value!,
                            maxLines: maxLines,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: StyleConstants.deepGreen,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (onTap != null) ...[
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 17,
                            color: StyleConstants.deepGreen,
                          ),
                        ],
                      ],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyActionButton extends StatelessWidget {
  const _JourneyActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.secondary,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      icon: icon,
      variant: variant,
      size: AppButtonSize.compact,
      onPressed: onPressed,
      loading: loading,
      expand: true,
    );
  }
}

class _CompactJourneyDateDialog extends StatefulWidget {
  const _CompactJourneyDateDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_CompactJourneyDateDialog> createState() =>
      _CompactJourneyDateDialogState();
}

class _CompactJourneyDateDialogState extends State<_CompactJourneyDateDialog> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final config = CalendarDatePicker2Config(
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      calendarType: CalendarDatePicker2Type.single,
      centerAlignModePicker: true,
      controlsHeight: 38,
      dayMaxWidth: 30,
      dynamicCalendarRows: true,
      disableVibration: true,
      daySplashColor: Colors.transparent,
      selectedDayHighlightColor: Colors.transparent,
      dayTextStyle: const TextStyle(
        color: StyleConstants.inkColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      selectedDayTextStyle: const TextStyle(
        color: StyleConstants.inkColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      todayTextStyle: const TextStyle(
        color: StyleConstants.deepGreen,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      weekdayLabelTextStyle: const TextStyle(
        color: StyleConstants.mutedInkColor,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
      controlsTextStyle: const TextStyle(
        color: StyleConstants.deepGreen,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
      disabledDayTextStyle: TextStyle(
        color: StyleConstants.mutedInkColor.withValues(alpha: 0.42),
        fontSize: 12,
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
        final isCurrentSelection = isSelected == true;
        final isOriginalDate = DateUtils.isSameDay(date, widget.initialDate);

        return Center(
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: isCurrentSelection
                ? const BoxDecoration(
                    shape: BoxShape.circle,
                    color: StyleConstants.primaryGreen,
                  )
                : isOriginalDate
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
              style: isCurrentSelection
                  ? const TextStyle(
                      color: StyleConstants.inkColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    )
                  : textStyle,
            ),
          ),
        );
      },
    );

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: _JourneyPanelSurface(
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
                      child: _JourneyActionButton(
                        icon: Icons.close_rounded,
                        label:
                            MaterialLocalizations.of(context).cancelButtonLabel,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 112,
                      child: _JourneyActionButton(
                        icon: Icons.check_rounded,
                        label: MaterialLocalizations.of(context).okButtonLabel,
                        variant: AppButtonVariant.primary,
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

class _CompactJourneyTimeDialog extends StatefulWidget {
  const _CompactJourneyTimeDialog({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_CompactJourneyTimeDialog> createState() =>
      _CompactJourneyTimeDialogState();
}

class _CompactJourneyTimeDialogState extends State<_CompactJourneyTimeDialog> {
  late int _hour;
  late int _minute;
  late bool _isPm;
  late final FixedExtentScrollController _hour24Controller;
  late final FixedExtentScrollController _hour12Controller;
  late final FixedExtentScrollController _minuteController;
  late final FixedExtentScrollController _periodController;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _isPm = _hour >= 12;
    final displayHour = _hour % 12 == 0 ? 12 : _hour % 12;
    _hour24Controller = FixedExtentScrollController(initialItem: _hour);
    _hour12Controller =
        FixedExtentScrollController(initialItem: displayHour - 1);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
    _periodController = FixedExtentScrollController(initialItem: _isPm ? 1 : 0);
  }

  @override
  void dispose() {
    _hour24Controller.dispose();
    _hour12Controller.dispose();
    _minuteController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required int selectedIndex,
    required String Function(int index) labelBuilder,
    required ValueChanged<int> onSelectedItemChanged,
    double width = 80,
  }) {
    return SizedBox(
      width: width,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: StyleConstants.softGreen.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          CupertinoPicker(
            scrollController: controller,
            itemExtent: 40,
            diameterRatio: 1.45,
            squeeze: 1.08,
            selectionOverlay: const SizedBox.shrink(),
            onSelectedItemChanged: onSelectedItemChanged,
            children: List.generate(
              itemCount,
              (index) => Center(
                child: Text(
                  labelBuilder(index),
                  style: TextStyle(
                    color: index == selectedIndex
                        ? StyleConstants.deepGreen
                        : StyleConstants.mutedInkColor.withValues(alpha: 0.58),
                    fontSize: 20,
                    fontWeight: index == selectedIndex
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final use24HourFormat = MediaQuery.alwaysUse24HourFormatOf(context);
    final selectedHourIndex =
        use24HourFormat ? _hour : ((_hour % 12 == 0 ? 12 : _hour % 12) - 1);

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: _JourneyPanelSurface(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 290,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        localizations.timePickerDialHelpText,
                        style: const TextStyle(
                          color: StyleConstants.deepGreen,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _wheel(
                              controller: use24HourFormat
                                  ? _hour24Controller
                                  : _hour12Controller,
                              itemCount: use24HourFormat ? 24 : 12,
                              selectedIndex: selectedHourIndex,
                              labelBuilder: (index) => use24HourFormat
                                  ? index.toString().padLeft(2, '0')
                                  : '${index + 1}',
                              onSelectedItemChanged: (index) {
                                AppHaptics.selection();
                                setState(() {
                                  if (use24HourFormat) {
                                    _hour = index;
                                  } else {
                                    final hour12 = index + 1;
                                    _hour = hour12 % 12 + (_isPm ? 12 : 0);
                                  }
                                });
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              child: Text(
                                ':',
                                style: TextStyle(
                                  color: StyleConstants.deepGreen,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _wheel(
                              controller: _minuteController,
                              itemCount: 60,
                              selectedIndex: _minute,
                              labelBuilder: (index) =>
                                  index.toString().padLeft(2, '0'),
                              onSelectedItemChanged: (index) {
                                AppHaptics.selection();
                                setState(() => _minute = index);
                              },
                            ),
                            if (!use24HourFormat) ...[
                              const SizedBox(width: 10),
                              _wheel(
                                controller: _periodController,
                                itemCount: 2,
                                selectedIndex: _isPm ? 1 : 0,
                                width: 64,
                                labelBuilder: (index) => index == 0
                                    ? localizations.anteMeridiemAbbreviation
                                    : localizations.postMeridiemAbbreviation,
                                onSelectedItemChanged: (index) {
                                  AppHaptics.selection();
                                  setState(() {
                                    _isPm = index == 1;
                                    _hour = _hour % 12 + (_isPm ? 12 : 0);
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 112,
                      child: _JourneyActionButton(
                        icon: Icons.close_rounded,
                        label: localizations.cancelButtonLabel,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 112,
                      child: _JourneyActionButton(
                        icon: Icons.check_rounded,
                        label: localizations.okButtonLabel,
                        variant: AppButtonVariant.primary,
                        onPressed: () => Navigator.of(context).pop(
                          TimeOfDay(hour: _hour, minute: _minute),
                        ),
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

enum _JourneyEditChoice { information, track }

class _JourneyEditChoiceDialog extends StatelessWidget {
  const _JourneyEditChoiceDialog({required this.onSelected});

  final ValueChanged<_JourneyEditChoice> onSelected;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 38),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: AppDialogCard(
          title: context.tr('common.edit'),
          surfaceStyle: AppDialogSurfaceStyle.glass,
          maxHeightFactor: 0.5,
          contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EditChoiceTile(
                icon: Icons.description_outlined,
                title: context.tr('journey.journey_info_edit_page_title'),
                onTap: () => onSelected(_JourneyEditChoice.information),
              ),
              const SizedBox(height: 8),
              _EditChoiceTile(
                icon: Icons.edit_road_rounded,
                title: context.tr('journey.editor.page_title'),
                onTap: () => onSelected(_JourneyEditChoice.track),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditChoiceTile extends StatelessWidget {
  const _EditChoiceTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.selected = false,
    this.selectionMode = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool selected;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    return AppOptionTile(
      icon: icon,
      title: title,
      selected: selected,
      trailing: selectionMode
          ? AppOptionTileTrailing.selection
          : AppOptionTileTrailing.chevron,
      backgroundAlpha: 0.5,
      onTap: onTap,
    );
  }
}
