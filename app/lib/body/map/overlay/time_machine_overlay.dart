import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:memolanes/body/time_machine/time_range_picker.dart';
import 'package:memolanes/common/async_load_token.dart';
import 'package:memolanes/common/component/base_map_webview.dart';
import 'package:memolanes/common/log.dart';
import 'package:memolanes/common/simple_date_utils.dart';
import 'package:memolanes/constants/style_constants.dart';
import 'package:memolanes/src/rust/api/api.dart' as api;
import 'package:memolanes/src/rust/journey_header.dart';

/// Initial layer selection for time machine: ensure at least default kind (from main map filter).
Set<JourneyKind> _initialJourneyKindsFromMainMap() {
  final f = api.getCurrentMainMapLayerFilter();
  final defaultOn = f.defaultKind;
  final flightOn = f.flightKind;
  if (!defaultOn && !flightOn) return {JourneyKind.defaultKind};
  if (defaultOn && flightOn) {
    return {JourneyKind.defaultKind, JourneyKind.flight};
  }
  if (defaultOn) return {JourneyKind.defaultKind};
  return {JourneyKind.flight};
}

class TimeMachineOverlay extends StatefulWidget {
  const TimeMachineOverlay({super.key, required this.onJourneyRangeLoaded});

  final void Function((api.MapRendererProxy, MapBounds?) mapData)
  onJourneyRangeLoaded;

  @override
  State<TimeMachineOverlay> createState() => _TimeMachineOverlayState();
}

class _TimeMachineOverlayState extends State<TimeMachineOverlay> {
  static const _rangeLoadInterval = Duration(milliseconds: 100);
  static const _loadErrorMessage =
      '[TimeMachineOverlay] failed to load journey range';

  SimpleDate? _earliestJourneyDate;
  bool _loading = false;
  SimpleDate? _requestedFrom;
  SimpleDate? _requestedTo;
  final _loadGuard = AsyncLoadToken();
  Timer? _rangeLoadTimer;
  (SimpleDate, SimpleDate, int)? _activeRange;
  (SimpleDate, SimpleDate, int)? _loadedRange;

  late Set<JourneyKind> _selectedJourneyKinds;

  (SimpleDate, SimpleDate, int) _rangeKey(SimpleDate from, SimpleDate to) => (
    from,
    to,
    (_selectedJourneyKinds.contains(JourneyKind.defaultKind) ? 1 : 0) |
        (_selectedJourneyKinds.contains(JourneyKind.flight) ? 2 : 0),
  );

  @override
  void initState() {
    super.initState();
    _selectedJourneyKinds = _initialJourneyKindsFromMainMap();
    unawaited(_loadEarliestJourneyDate());
  }

  Future<void> _loadEarliestJourneyDate() async {
    try {
      final value = await api.earliestJourneyDate();
      if (!mounted) return;
      setState(() {
        _earliestJourneyDate =
            value?.toSimpleDate() ?? SimpleDate(DateTime.now().year);
      });
    } catch (error, stackTrace) {
      log.error(
        '[TimeMachineOverlay] failed to load earliest journey date: $error',
        stackTrace,
      );
    }
  }

  Future<void> _loadJourneyForRange(SimpleDate from, SimpleDate to) async {
    _rangeLoadTimer?.cancel();
    _rangeLoadTimer = null;
    if (!mounted) return;
    if (_earliestJourneyDate == null) return;
    if (from.isAfter(to)) return;
    _requestedFrom = from;
    _requestedTo = to;
    final range = _rangeKey(from, to);
    if (_activeRange == range) return;
    if (_loadedRange == range) {
      _loadGuard.invalidate();
      _activeRange = null;
      setState(() => _loading = false);
      return;
    }
    final loadToken = _loadGuard.begin();
    _activeRange = range;
    final journeyKinds = Set<JourneyKind>.from(_selectedJourneyKinds);
    setState(() => _loading = true);
    try {
      final mapData = await api.getMapRendererProxyForJourneyDateRange(
        fromDateInclusive: from.toFrbNaiveDate(),
        toDateInclusive: to.toFrbNaiveDate(),
        journeyKinds: journeyKinds,
      );
      if (mounted && _loadGuard.isActive(loadToken)) {
        _loadedRange = range;
        widget.onJourneyRangeLoaded(mapData);
      }
    } catch (error, stackTrace) {
      if (mounted && _loadGuard.isActive(loadToken)) {
        log.error('$_loadErrorMessage: $error', stackTrace);
      }
    } finally {
      if (mounted && _loadGuard.isActive(loadToken)) {
        setState(() => _loading = false);
        _activeRange = null;
        _loadGuard.clear();
      }
    }
  }

  void _scheduleJourneyRangeLoad(SimpleDate from, SimpleDate to) {
    if (!mounted || from.isAfter(to)) return;
    if (_requestedFrom == from && _requestedTo == to) return;
    _requestedFrom = from;
    _requestedTo = to;
    // Invalidate immediately: an older load may finish before the next timer.
    // Coalesce scroll events without postponing updates until scrolling stops.
    _loadGuard.invalidate();
    _activeRange = null;
    setState(() => _loading = true);
    _rangeLoadTimer ??= Timer(_rangeLoadInterval, () {
      _rangeLoadTimer = null;
      unawaited(_loadJourneyForRange(_requestedFrom!, _requestedTo!));
    });
  }

  void _onJourneyKindsChanged(Set<JourneyKind> newKinds) {
    final kinds = Set<JourneyKind>.from(newKinds);
    setState(() => _selectedJourneyKinds = kinds);
    final from = _requestedFrom;
    final to = _requestedTo;
    if (from != null && to != null) {
      unawaited(_loadJourneyForRange(from, to));
    }
  }

  @override
  void dispose() {
    _rangeLoadTimer?.cancel();
    _loadGuard.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final earliest = _earliestJourneyDate;
    if (earliest == null) {
      return const SizedBox.shrink();
    }

    final padding = MediaQuery.viewPaddingOf(context);
    final horizontalSafeArea = math.max(padding.left, padding.right);

    return Stack(
      children: [
        Positioned(
          left: horizontalSafeArea + 24,
          right: horizontalSafeArea + 24,
          bottom: StyleConstants.mapPrimaryControlBottomInsetForContext(
            context,
          ),
          child: TimeRangePicker(
            earliestDate: earliest,
            loading: _loading,
            onRangeChanged: _scheduleJourneyRangeLoad,
            onRangeCommitted: _loadJourneyForRange,
            selectedJourneyKinds: _selectedJourneyKinds,
            onJourneyKindsChanged: _onJourneyKindsChanged,
          ),
        ),
      ],
    );
  }
}
