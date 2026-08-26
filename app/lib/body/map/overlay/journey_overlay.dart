import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:memolanes/body/journey/journey_body.dart';
import 'package:memolanes/body/journey/journey_export.dart';
import 'package:memolanes/body/journey/compact_journey_info_card.dart';
import 'package:memolanes/body/journey/journey_track_edit_page.dart';
import 'package:memolanes/common/app_haptics.dart';
import 'package:memolanes/common/component/app_button.dart';
import 'package:memolanes/common/component/app_date_picker_dialog.dart';
import 'package:memolanes/common/component/app_dialog.dart';
import 'package:memolanes/common/component/app_option_tile.dart';
import 'package:memolanes/common/component/base_map_webview.dart';
import 'package:memolanes/common/component/map_glass_back_button.dart';
import 'package:memolanes/common/journey_kind_visuals.dart';
import 'package:memolanes/common/utils.dart';
import 'package:memolanes/constants/app_typography.dart';
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
/// remains visible and unobstructed below it. Selecting a journey pushes a
/// dedicated map-detail route where the app navigation bar is intentionally
/// absent.
class JourneyOverlay extends StatefulWidget {
  const JourneyOverlay({super.key});

  @override
  State<JourneyOverlay> createState() => _JourneyOverlayState();
}

class _JourneyOverlayState extends State<JourneyOverlay> {
  bool _isLoadingJourney = false;
  int _pickerRevision = 0;

  Future<void> _openJourneyDetails(JourneyHeader journey) async {
    if (_isLoadingJourney) return;
    setState(() => _isLoadingJourney = true);

    try {
      final rendererAndBounds = await api.getMapRendererProxyForJourney(
        journeyId: journey.id,
      );
      if (!mounted) return;
      await navigatorPush<void>(
        context,
        page: _JourneyMapDetailPage(
          journey: journey,
          mapRendererProxy: rendererAndBounds.$1,
          initialMapBounds: rendererAndBounds.$2,
        ),
      );
      if (!mounted) return;
      setState(() => _pickerRevision++);
    } finally {
      if (mounted) setState(() => _isLoadingJourney = false);
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

    return Stack(
      children: [
        Positioned(
          left: viewPadding.left + 16,
          right: viewPadding.right + 16,
          bottom: bottom,
          child: Align(
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
                  refreshRevision: _pickerRevision,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _JourneyMapDetailPage extends StatefulWidget {
  const _JourneyMapDetailPage({
    required this.journey,
    required this.mapRendererProxy,
    required this.initialMapBounds,
  });

  final JourneyHeader journey;
  final api.MapRendererProxy mapRendererProxy;
  final MapBounds? initialMapBounds;

  @override
  State<_JourneyMapDetailPage> createState() =>
      _JourneyMapDetailPageState();
}

class _JourneyMapDetailPageState extends State<_JourneyMapDetailPage> {
  late JourneyHeader _journey;
  late api.MapRendererProxy _mapRendererProxy;
  MapBounds? _mapBounds;
  bool _isEditingInformation = false;
  int _mapRevision = 0;

  @override
  void initState() {
    super.initState();
    _journey = widget.journey;
    _mapRendererProxy = widget.mapRendererProxy;
    _mapBounds = widget.initialMapBounds;
  }

  Future<void> _refreshJourney() async {
    final journeyId = _journey.id;
    final allJourneys = await api.listAllJourneys();
    JourneyHeader? latest;
    for (final journey in allJourneys) {
      if (journey.id == journeyId) {
        latest = journey;
        break;
      }
    }
    if (!mounted) return;
    if (latest == null) {
      Navigator.of(context).pop();
      return;
    }

    final rendererAndBounds = await api.getMapRendererProxyForJourney(
      journeyId: journeyId,
    );
    if (!mounted) return;
    setState(() {
      _journey = latest!;
      _mapRendererProxy = rendererAndBounds.$1;
      _mapBounds = rendererAndBounds.$2;
      _mapRevision++;
    });
  }

  Future<void> _saveJourneyInformation(JourneyInfo journeyInfo) async {
    await api.updateJourneyMetadata(
      id: _journey.id,
      journeyInfo: journeyInfo,
    );
  }

  Future<void> _deleteJourney() async {
    final shouldDelete = await showCommonDialog(
      context,
      context.tr('journey.delete_journey_message'),
      hasCancel: true,
      title: context.tr('journey.delete_journey_title'),
      confirmButtonText: context.tr('common.delete'),
      confirmVariant: AppButtonVariant.danger,
    );
    if (!shouldDelete) return;
    await api.deleteJourney(journeyId: _journey.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _exportJourney() async {
    await showJourneyExportPicker(context, _journey);
  }

  Future<void> _openTrackEditor() async {
    final session = await EditSession.newInstance(journeyId: _journey.id);
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
    await _refreshJourney();
  }

  Future<void> _showEditChoice() async {
    final choice = await showDialog<_JourneyEditChoice>(
      context: context,
      barrierColor: StyleConstants.shadowColor.withValues(
        alpha: StyleConstants.isDarkMode ? 0.58 : 0.2,
      ),
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
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final detailCardPadding = isLandscape ? 190.0 : 330.0;

    return Scaffold(
      backgroundColor: StyleConstants.canvasColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          BaseMapWebview(
            key: ValueKey('journey-detail-${_journey.id}-$_mapRevision'),
            mapRendererProxy: _mapRendererProxy,
            initialMapBounds: _mapBounds,
            initialMapBoundsPadding: EdgeInsets.fromLTRB(
              28,
              viewPadding.top + 82,
              28,
              detailCardPadding + viewPadding.bottom,
            ),
          ),
          Positioned(
            left: viewPadding.left + 16,
            right: viewPadding.right + 16,
            bottom: viewPadding.bottom + 16,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: math.min(
                  mediaQuery.size.width -
                      viewPadding.left -
                      viewPadding.right -
                      32,
                  430.0,
                ),
                child: PointerInterceptor(
                  child: _CollapsibleJourneyDetail(
                    child: _JourneyDetailCard(
                      journey: _journey,
                      isEditing: _isEditingInformation,
                      onExport: _exportJourney,
                      onEdit: _showEditChoice,
                      onDelete: _deleteJourney,
                      onSave: _saveJourneyInformation,
                      onSaved: () async {
                        await _refreshJourney();
                        if (!mounted) return;
                        setState(() => _isEditingInformation = false);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: viewPadding.left + 16,
            top: viewPadding.top + 14,
            child: PointerInterceptor(
              child: MapGlassBackButton(
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsibleJourneyDetail extends StatefulWidget {
  const _CollapsibleJourneyDetail({required this.child});

  final Widget child;

  @override
  State<_CollapsibleJourneyDetail> createState() =>
      _CollapsibleJourneyDetailState();
}

class _CollapsibleJourneyDetailState
    extends State<_CollapsibleJourneyDetail> {
  static const double _dismissDistance = 56;
  static const double _dismissVelocity = 650;

  bool _isHidden = false;
  bool _isDragging = false;
  double _dragOffset = 0;

  void _onDragStart(DragStartDetails _) {
    setState(() => _isDragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    setState(() {
      _dragOffset = (_dragOffset + delta).clamp(0.0, 180.0).toDouble();
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldHide =
        _dragOffset >= _dismissDistance || velocity >= _dismissVelocity;
    if (shouldHide) AppHaptics.light();
    setState(() {
      _isDragging = false;
      _isHidden = shouldHide;
      _dragOffset = 0;
    });
  }

  void _onDragCancel() {
    setState(() {
      _isDragging = false;
      _dragOffset = 0;
    });
  }

  void _restore() {
    AppHaptics.light();
    setState(() => _isHidden = false);
  }

  @override
  Widget build(BuildContext context) {
    final title = context.tr('journey.journey_info_page_title');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.bottomCenter,
        children: [...previousChildren, if (currentChild != null) currentChild],
      ),
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: _isHidden
          ? Align(
              key: const ValueKey('journey-detail-restore'),
              alignment: Alignment.bottomCenter,
              heightFactor: 1,
              child: SizedBox(
                width: 68,
                height: 32,
                child: JourneyInfoPanelSurface(
                  backgroundAlpha: 0.76,
                  child: Tooltip(
                    message: title,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _restore,
                        borderRadius: BorderRadius.circular(24),
                        child: Center(
                          child: Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 23,
                            color: StyleConstants.deepGreen,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : AnimatedContainer(
              key: const ValueKey('journey-detail-card'),
              duration: _isDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _dragOffset, 0),
              child: Stack(
                children: [
                  widget.child,
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 19,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: _onDragStart,
                      onVerticalDragUpdate: _onDragUpdate,
                      onVerticalDragEnd: _onDragEnd,
                      onVerticalDragCancel: _onDragCancel,
                      child: Center(
                        child: Container(
                          width: 34,
                          height: 4,
                          decoration: BoxDecoration(
                            color: StyleConstants.mutedInkColor
                                .withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _JourneyPickerCard extends StatelessWidget {
  const _JourneyPickerCard({
    super.key,
    required this.onJourneySelected,
    required this.isLoading,
    required this.refreshRevision,
  });

  final Future<void> Function(JourneyHeader journey) onJourneySelected;
  final bool isLoading;
  final int refreshRevision;

  @override
  Widget build(BuildContext context) {
    return JourneyInfoPanelSurface(
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
                      decoration: BoxDecoration(
                        color: StyleConstants.softGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.route_rounded,
                        size: 17,
                        color: StyleConstants.deepGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('journey.picker_title'),
                        style: AppTypography.surfaceTitle.copyWith(
                          color: StyleConstants.deepGreen,
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
                  refreshRevision: refreshRevision,
                ),
              ),
            ],
          ),
          if (isLoading)
            Positioned.fill(
              child: ColoredBox(
                color: StyleConstants.surfaceColor.withValues(alpha: 0.42),
                child: Center(
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
    final date = await showAppDatePickerDialog(
      context,
      initialDate: _validInitialDate(seed),
      firstDate: _firstDate,
      lastDate: DateTime.now(),
      highlightInitialDate: true,
    );
    if (date == null || !mounted) return null;
    final time = await showDialog<TimeOfDay>(
      context: context,
      barrierColor: StyleConstants.shadowColor.withValues(
        alpha: StyleConstants.isDarkMode ? 0.58 : 0.2,
      ),
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
    final selected = await showAppDatePickerDialog(
      context,
      initialDate: _validInitialDate(_journeyDate),
      firstDate: _firstDate,
      lastDate: DateTime.now(),
      highlightInitialDate: true,
    );
    if (selected == null || !mounted) return;
    setState(() => _journeyDate = selected);
  }

  Future<void> _selectJourneyKind() async {
    final selected = await showDialog<JourneyKind>(
      context: context,
      barrierColor: StyleConstants.shadowColor.withValues(
        alpha: StyleConstants.isDarkMode ? 0.58 : 0.2,
      ),
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
                    iconWidget: JourneyKindIcon(
                      kind: JourneyKind.defaultKind,
                      color: StyleConstants.deepGreen,
                      size: 20,
                    ),
                    title: context.tr('journey_kind.default'),
                    selected: _journeyKind == JourneyKind.defaultKind,
                    selectionMode: true,
                    onTap: () => Navigator.of(dialogContext)
                        .pop(JourneyKind.defaultKind),
                  ),
                  const SizedBox(height: 8),
                  _EditChoiceTile(
                    iconWidget: JourneyKindIcon(
                      kind: JourneyKind.flight,
                      color: StyleConstants.deepGreen,
                      size: 20,
                    ),
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

    return JourneyInfoPanelSurface(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 13),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const JourneyInfoCardHeader(),
            const SizedBox(height: 5),
            CompactJourneyInfoField(
              icon: Icons.calendar_today_rounded,
              label: context.tr('journey.journey_date'),
              value: isEditing
                  ? dateFormat.format(_journeyDate)
                  : naiveDateToString(date: journey.journeyDate),
              onTap: isEditing ? _selectJourneyDate : null,
            ),
            CompactJourneyInfoField(
              icon: Icons.sell_outlined,
              label: context.tr('journey.journey_kind'),
              value: kind,
              onTap: isEditing ? _selectJourneyKind : null,
            ),
            CompactJourneyInfoField(
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
            CompactJourneyInfoField(
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
              CompactJourneyInfoField(
                icon: Icons.notes_rounded,
                label: context.tr('journey.note'),
                trailing: TextField(
                  controller: _noteController,
                  minLines: 1,
                  maxLines: 2,
                  textAlign: TextAlign.right,
                  style: AppTypography.supporting.copyWith(
                    color: StyleConstants.deepGreen,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: context.tr('common.please_enter'),
                    hintStyle: AppTypography.supporting.copyWith(
                      color: StyleConstants.mutedInkColor,
                    ),
                  ),
                ),
              )
            else if (note != null && note.isNotEmpty)
              CompactJourneyInfoField(
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
                            variant: AppButtonVariant.primary,
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
                  style: AppTypography.pickerValue.copyWith(
                    color: index == selectedIndex
                        ? StyleConstants.deepGreen
                        : StyleConstants.mutedInkColor.withValues(alpha: 0.58),
                    fontWeight: index == selectedIndex
                        ? FontWeight.w700
                        : FontWeight.w600,
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
        child: JourneyInfoPanelSurface(
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
                        style: AppTypography.surfaceTitle.copyWith(
                          color: StyleConstants.deepGreen,
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
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              child: Text(
                                ':',
                                style: AppTypography.metricTitle.copyWith(
                                  color: StyleConstants.deepGreen,
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
    this.icon,
    this.iconWidget,
    required this.title,
    required this.onTap,
    this.selected = false,
    this.selectionMode = false,
  }) : assert((icon == null) != (iconWidget == null));

  final IconData? icon;
  final Widget? iconWidget;
  final String title;
  final VoidCallback onTap;
  final bool selected;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    return AppOptionTile(
      icon: icon,
      iconWidget: iconWidget,
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
