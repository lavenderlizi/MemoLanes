import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:memolanes/common/async_load_token.dart';
import 'package:memolanes/common/component/base_map_webview.dart';
import 'package:memolanes/common/loading_manager.dart';
import 'package:memolanes/common/log.dart';
import 'package:memolanes/common/simple_date_utils.dart';
import 'package:memolanes/src/rust/api/api.dart' as api;
import 'package:memolanes/src/rust/api/import.dart' show JourneyInfo;
import 'package:memolanes/src/rust/journey_header.dart';

enum JourneyPhase {
  picker,
  opening,
  viewing,
  editing,
  saving,
  deleting,
  refreshing,
}

enum JourneyBackResult { handled, blocked, unhandled }

/// One visit to a journey, including the camera to restore when it closes.
class JourneyDetailSession {
  const JourneyDetailSession({
    required this.journey,
    required this.mapData,
    required this.returnView,
  });

  final JourneyHeader journey;
  final (api.MapRendererProxy, MapBounds?) mapData;
  final MapView? returnView;
}

/// Owned by the home page so map content, app chrome and back navigation all
/// observe the same journey lifecycle. Form drafts remain owned by the card.
class JourneyFlowController extends ChangeNotifier {
  JourneyPhase _phase = JourneyPhase.picker;
  JourneyDetailSession? _session;
  MapView? _returnToView;
  int _pickerRevision = 0;
  final _loadToken = AsyncLoadToken();
  final _overviewLoadToken = AsyncLoadToken();
  (api.MapRendererProxy, MapBounds?)? _overviewMapData;
  SimpleDate? _overviewDate;
  bool _isOverviewLoading = false;
  bool _disposed = false;

  JourneyPhase get phase => _phase;
  JourneyDetailSession? get session => _session;
  MapView? get returnToView => _returnToView;
  int get pickerRevision => _pickerRevision;
  (api.MapRendererProxy, MapBounds?)? get overviewMapData => _overviewMapData;
  bool get isOverviewLoading => _isOverviewLoading;
  SimpleDate? get overviewDate => _overviewDate;
  bool get appChromeVisible => _session == null;
  bool get isEditing =>
      _phase == JourneyPhase.editing || _phase == JourneyPhase.saving;
  bool get _isMutating =>
      _phase == JourneyPhase.saving || _phase == JourneyPhase.deleting;

  /// Each tab visit shows the latest date with completed journeys, up to today.
  /// Future-dated imports and the ongoing recording are excluded.
  Future<void> loadOverview({DateTime? now, SimpleDate? date}) async {
    if (_disposed || _phase != JourneyPhase.picker) return;
    final token = _overviewLoadToken.begin();
    _overviewMapData ??= (api.getEmptyMapRendererProxy(), null);
    _isOverviewLoading = true;
    notifyListeners();
    try {
      if (date == null) {
        final localNow = (now ?? DateTime.now()).toLocal();
        final today = SimpleDate(localNow.year, localNow.month, localNow.day);
        final dates = await api.journeyDates();
        if (!_overviewLoadToken.isActive(token)) return;
        for (final value in dates) {
          // FRB calendar dates are UTC midnights, not local timestamps.
          final candidate = SimpleDate(value.year, value.month, value.day);
          if (!candidate.isAfter(today) &&
              (date == null || candidate.isAfter(date))) {
            date = candidate;
          }
        }
      }
      if (date == null) {
        _overviewMapData = (api.getEmptyMapRendererProxy(), null);
        _overviewDate = null;
        return;
      }
      final mapData = await api.getMapRendererProxyForJourneyDate(
        date: date.toFrbNaiveDate(),
      );
      if (!_overviewLoadToken.isActive(token)) return;
      _overviewMapData = mapData;
      _overviewDate = date;
    } catch (error, stackTrace) {
      if (!_overviewLoadToken.isActive(token)) return;
      log.error('Loading daily journey map failed: $error', stackTrace);
    } finally {
      if (_overviewLoadToken.isActive(token)) {
        _overviewLoadToken.clear();
        _isOverviewLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> open(
    JourneyHeader journey, {
    required Future<MapView?> Function() readMapView,
  }) async {
    if (_disposed || _isOverviewLoading || _phase != JourneyPhase.picker) {
      return;
    }
    final token = _loadToken.begin();
    _phase = JourneyPhase.opening;
    notifyListeners();
    try {
      final returnView = await readMapView();
      if (!_loadToken.isActive(token)) return;
      final mapData = await api.getMapRendererProxyForJourney(
        journeyId: journey.id,
      );
      if (!_loadToken.isActive(token)) return;
      _session = JourneyDetailSession(
        journey: journey,
        mapData: mapData,
        returnView: returnView,
      );
      _returnToView = null;
      _phase = JourneyPhase.viewing;
    } catch (_) {
      // Leaving the picker invalidates both late successes and late errors.
      if (!_loadToken.isActive(token)) return;
      _phase = JourneyPhase.picker;
      rethrow;
    } finally {
      if (_loadToken.isActive(token)) {
        _loadToken.clear();
        notifyListeners();
      }
    }
  }

  void editInformation() {
    if (_disposed || _phase != JourneyPhase.viewing) return;
    _phase = JourneyPhase.editing;
    notifyListeners();
  }

  /// Shared by system back, the detail back button and edit cancellation.
  JourneyBackResult requestBack() {
    if (_disposed) return JourneyBackResult.unhandled;
    switch (_phase) {
      case JourneyPhase.picker:
        return JourneyBackResult.unhandled;
      case JourneyPhase.opening:
        _loadToken.invalidate();
        _phase = JourneyPhase.picker;
        notifyListeners();
      case JourneyPhase.editing:
        _phase = JourneyPhase.viewing;
        notifyListeners();
      case JourneyPhase.viewing:
      case JourneyPhase.refreshing:
        _closeDetail();
      case JourneyPhase.saving:
      case JourneyPhase.deleting:
        return JourneyBackResult.blocked;
    }
    return JourneyBackResult.handled;
  }

  /// Called before switching away from the Journeys tab, never during build.
  bool leave() {
    if (_disposed || _isMutating) return false;
    _loadToken.invalidate();
    _overviewLoadToken.invalidate();
    _overviewMapData = null;
    _overviewDate = null;
    _isOverviewLoading = false;
    if (_session != null) _pickerRevision++;
    _session = null;
    _returnToView = null;
    _phase = JourneyPhase.picker;
    notifyListeners();
    return true;
  }

  Future<void> saveInformation(
    JourneyInfo info, {
    required Future<bool> Function() confirm,
  }) async {
    if (_disposed || _phase != JourneyPhase.editing) return;
    // Lock before the first await, including confirmation and wakelock setup.
    // Confirmation itself remains a normal dialog route that can be cancelled.
    _phase = JourneyPhase.saving;
    notifyListeners();
    try {
      if (!await confirm() || _disposed) return;
      await GlobalLoadingManager.instance.runWithLoading(() async {
        await api.updateJourneyMetadata(
          id: _session!.journey.id,
          journeyInfo: info,
        );
        await _refreshJourney(refreshMap: false);
      }, blockNavigation: true);
      if (!_disposed && _session != null) _phase = JourneyPhase.viewing;
    } finally {
      if (!_disposed) {
        // Cancellation and failure keep the existing form and its draft alive.
        if (_phase == JourneyPhase.saving) _phase = JourneyPhase.editing;
        notifyListeners();
      }
    }
  }

  /// The caller presents deletion confirmation before invoking this mutation.
  Future<void> deleteJourney() async {
    if (_disposed || _phase != JourneyPhase.viewing) return;
    final id = _session!.journey.id;
    _phase = JourneyPhase.deleting;
    notifyListeners();
    try {
      await GlobalLoadingManager.instance.runWithLoading(
        () => api.deleteJourney(journeyId: id),
        blockNavigation: true,
      );
      if (!_disposed) _closeDetail();
    } finally {
      if (!_disposed && _phase == JourneyPhase.deleting) {
        _phase = JourneyPhase.viewing;
        notifyListeners();
      }
    }
  }

  Future<void> refreshTrack() async {
    if (_disposed || _phase != JourneyPhase.viewing) return;
    final token = _loadToken.begin();
    // Until the editor's result has loaded, do not start another edit or
    // mutation against the old header/map. This read can still be dismissed.
    _phase = JourneyPhase.refreshing;
    notifyListeners();
    try {
      await _refreshJourney(refreshMap: true);
    } catch (_) {
      if (_loadToken.isActive(token)) rethrow;
    } finally {
      if (_loadToken.isActive(token)) {
        _loadToken.clear();
        _phase = JourneyPhase.viewing;
        notifyListeners();
      }
    }
  }

  Future<void> _refreshJourney({required bool refreshMap}) async {
    final session = _session;
    if (_disposed || session == null) return;
    final latest = await api.getJourneyHeader(journeyId: session.journey.id);
    if (_disposed || !identical(_session, session)) return;
    if (latest == null) {
      _closeDetail();
      return;
    }
    final mapData = refreshMap
        ? await api.getMapRendererProxyForJourney(journeyId: latest.id)
        : session.mapData;
    if (_disposed || !identical(_session, session)) return;
    _session = JourneyDetailSession(
      journey: latest,
      mapData: mapData,
      returnView: session.returnView,
    );
    notifyListeners();
  }

  void _closeDetail() {
    _loadToken.invalidate();
    _returnToView = _session!.returnView;
    _session = null;
    _phase = JourneyPhase.picker;
    _pickerRevision++;
    notifyListeners();
    // Editing dates/kinds, deleting, or changing a track can alter the daily map.
    if (_overviewMapData != null) {
      unawaited(loadOverview(date: _overviewDate));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _loadToken.invalidate();
    _overviewLoadToken.invalidate();
    super.dispose();
  }
}
