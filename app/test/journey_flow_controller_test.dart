import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:memolanes/body/map/journey_flow_controller.dart';
import 'package:memolanes/common/component/base_map_webview.dart';
import 'package:memolanes/common/simple_date_utils.dart';
import 'package:memolanes/common/loading_manager.dart';
import 'package:memolanes/src/rust/api/api.dart' as api;
import 'package:memolanes/src/rust/frb_generated.dart';
import 'package:memolanes/src/rust/journey_header.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  final backend = _JourneyApi();
  final originalWakelockPlatform = wakelockPlusPlatformInstance;
  setUpAll(() {
    wakelockPlusPlatformInstance = _TestWakelockPlatform();
    RustLib.initMock(api: backend);
  });
  tearDownAll(() {
    RustLib.dispose();
    wakelockPlusPlatformInstance = originalWakelockPlatform;
  });

  late JourneyFlowController flow;
  final journey = JourneyHeader(
    id: 'journey',
    revision: 'initial',
    journeyDate: DateTime.utc(2024),
    createdAt: DateTime.utc(2024),
    journeyType: JourneyType.vector,
    journeyKind: JourneyKind.defaultKind,
    hasRawData: false,
  );
  const view = (lng: 113.0, lat: 22.0, zoom: 10.0);

  setUp(() {
    backend.requests.clear();
    backend.dateRequests.clear();
    backend.dates.clear();
    backend.journeyDates = [DateTime.utc(2024)];
    backend.header = journey;
    backend.headerReads = 0;
    backend.pendingRawDataDelete = null;
    backend.rawDataDeleteCalls = 0;
    flow = JourneyFlowController();
  });
  tearDown(() => flow.dispose());

  Future<void> startLoad() async {
    // Let the camera read finish so the backend request has started.
    await Future<void>.delayed(Duration.zero);
  }

  test('overview includes all completed journeys on today', () async {
    backend.journeyDates = [
      DateTime.utc(2026, 9, 28),
      DateTime.utc(2026, 10, 1),
      DateTime.utc(2026, 10, 2),
    ];
    final loading = flow.loadOverview(now: DateTime(2026, 10, 1, 12));
    expect(flow.isOverviewLoading, isTrue);
    await startLoad();
    expect(backend.dates, [DateTime.utc(2026, 10, 1)]);
    final map = _MapRenderer();
    const bounds = MapBounds(west: 110, south: 20, east: 115, north: 25);
    backend.dateRequests.single.complete((map, bounds));
    await loading;
    expect(flow.overviewMapData, (map, bounds));
    expect(flow.isOverviewLoading, isFalse);
  });

  test(
    'no completed journeys today selects the latest earlier date across years',
    () async {
      backend.journeyDates = [
        DateTime.utc(2025, 11, 30),
        DateTime.utc(2026, 1, 3),
        DateTime.utc(2025, 12, 27),
        DateTime.utc(2025, 12, 10),
      ];
      final loading = flow.loadOverview(now: DateTime(2026, 1, 1, 12));
      await startLoad();
      expect(backend.dates, [DateTime.utc(2025, 12, 27)]);
      final map = _MapRenderer();
      backend.dateRequests.single.complete((map, null));
      await loading;
      expect(flow.overviewMapData, (map, null));
      expect(backend.dates, hasLength(1));
    },
  );

  for (final futureOnly in [false, true]) {
    test(
      'overview stays empty with ${futureOnly ? 'only future' : 'no'} journeys',
      () async {
        backend.journeyDates = futureOnly ? [DateTime.utc(2026, 10, 2)] : [];
        await flow.loadOverview(now: DateTime(2026, 10, 1, 12));
        expect(backend.dateRequests, isEmpty);
        expect(flow.overviewMapData?.$1, isNotNull);
        expect(flow.overviewMapData?.$2, isNull);
        expect(flow.isOverviewLoading, isFalse);
      },
    );
  }

  test('leaving and reentering ignores an old daily map result', () async {
    final old = flow.loadOverview();
    await startLoad();
    flow.leave();
    final current = flow.loadOverview();
    await startLoad();
    backend.dateRequests.first.complete((_MapRenderer(), null));
    await old;
    expect(flow.isOverviewLoading, isTrue);
    final map = _MapRenderer();
    backend.dateRequests.last.complete((map, null));
    await current;
    expect(flow.overviewMapData?.$1, same(map));
    expect(flow.isOverviewLoading, isFalse);
  });

  test(
    'rapid date selections retain the old map until the latest map is ready',
    () async {
      final initial = flow.loadOverview(date: SimpleDate(2026, 9, 1));
      final initialMap = _MapRenderer();
      backend.dateRequests.last.complete((initialMap, null));
      await initial;
      final old = flow.loadOverview(date: SimpleDate(2026, 9, 2));
      final current = flow.loadOverview(date: SimpleDate(2026, 9, 3));
      expect(flow.overviewMapData?.$1, same(initialMap));
      final latestMap = _MapRenderer();
      const latestBounds = MapBounds(west: 10, south: 20, east: 30, north: 40);
      backend.dateRequests.last.complete((latestMap, latestBounds));
      await current;
      backend.dateRequests[1].complete((_MapRenderer(), null));
      await old;
      expect(flow.overviewDate, SimpleDate(2026, 9, 3));
      expect(flow.overviewMapData, (latestMap, latestBounds));
      expect(flow.isOverviewLoading, isFalse);
    },
  );

  test('explicit empty date does not fall back and detail back preserves the chosen date', () async {
    final selected = SimpleDate(2023, 11, 14);
    final initial = flow.loadOverview(date: selected);
    backend.dateRequests.last.complete((_MapRenderer(), null));
    await initial;
    expect(backend.dates, [DateTime.utc(2023, 11, 14)]);
    expect(flow.overviewDate, selected);
    final opening = flow.open(journey, readMapView: () async => view);
    await startLoad();
    backend.requests.last.complete((_MapRenderer(), null));
    await opening;
    flow.requestBack();
    expect(backend.dates.last, DateTime.utc(2023, 11, 14));
    backend.dateRequests.last.complete((_MapRenderer(), null));
    await startLoad();
    expect(flow.overviewDate, selected);
    expect(flow.isOverviewLoading, isFalse);
  });

  Future<_MapRenderer> openDetail() async {
    final opening = flow.open(journey, readMapView: () async => view);
    await startLoad();
    final map = _MapRenderer();
    backend.requests.last.complete((map, null));
    await opening;
    return map;
  }

  test('leaving during the camera read prevents a journey request', () async {
    final camera = Completer<MapView?>();
    final opening = flow.open(journey, readMapView: () => camera.future);
    expect(flow.phase, JourneyPhase.opening);
    expect(flow.appChromeVisible, isTrue);
    expect(flow.leave(), isTrue);
    camera.complete(view);
    await opening;
    expect(backend.requests, isEmpty);
    expect(flow.session, isNull);
    expect(flow.phase, JourneyPhase.picker);
  });

  for (final fail in [false, true]) {
    test(
      'a superseded load ${fail ? 'failure' : 'success'} cannot replace a newer detail',
      () async {
        final old = flow.open(journey, readMapView: () async => view);
        await startLoad();
        final oldRequest = backend.requests.single;
        flow.leave();
        final current = flow.open(journey, readMapView: () async => view);
        await startLoad();
        final currentMap = _MapRenderer();
        backend.requests.last.complete((currentMap, null));
        await current;
        final currentSession = flow.session;
        if (fail) {
          oldRequest.completeError(StateError('Old request failed'));
        } else {
          oldRequest.complete((_MapRenderer(), null));
        }
        await old;
        expect(flow.session, same(currentSession));
        expect(flow.session!.mapData.$1, same(currentMap));
        expect(flow.phase, JourneyPhase.viewing);
        expect(flow.appChromeVisible, isFalse);
      },
    );
  }

  test('an active load failure returns to a usable picker', () async {
    final opening = flow.open(journey, readMapView: () async => view);
    final failure = expectLater(opening, throwsStateError);
    await startLoad();
    backend.requests.single.completeError(StateError('Storage unavailable'));
    await failure;
    expect(flow.phase, JourneyPhase.picker);
    expect(flow.appChromeVisible, isTrue);
    expect(flow.requestBack(), JourneyBackResult.unhandled);
  });

  test(
    'back cancels a load without allowing its late completion to open details',
    () async {
      final opening = flow.open(journey, readMapView: () async => view);
      await startLoad();
      expect(flow.requestBack(), JourneyBackResult.handled);
      backend.requests.single.complete((_MapRenderer(), null));
      await opening;
      expect(flow.session, isNull);
      expect(flow.phase, JourneyPhase.picker);
      expect(flow.pickerRevision, 0);
    },
  );

  test('closing consumes one session and restores its original view', () async {
    await openDetail();
    flow.editInformation();
    expect(flow.requestBack(), JourneyBackResult.handled);
    expect(flow.phase, JourneyPhase.viewing);
    expect(flow.appChromeVisible, isFalse);
    expect(flow.pickerRevision, 0);
    expect(flow.requestBack(), JourneyBackResult.handled);
    expect(flow.returnToView, view);
    expect(flow.pickerRevision, 1);
    expect(flow.appChromeVisible, isTrue);
    expect(flow.requestBack(), JourneyBackResult.unhandled);
    expect(flow.pickerRevision, 1);
    flow.leave();
    expect(flow.returnToView, isNull);
  });

  test('disposing a flow invalidates outstanding loads', () async {
    final disposedFlow = JourneyFlowController();
    final opening = disposedFlow.open(journey, readMapView: () async => view);
    await startLoad();
    disposedFlow.dispose();
    backend.requests.single.complete((_MapRenderer(), null));
    await opening;
    expect(disposedFlow.session, isNull);
  });

  test('raw-data deletion blocks duplicate actions, permits retry and retains the track and camera', () async {
    JourneyHeader header(bool hasRawData) => JourneyHeader(
      id: journey.id,
      revision: hasRawData ? journey.revision : '${journey.revision}*',
      journeyDate: journey.journeyDate,
      createdAt: journey.createdAt,
      journeyType: journey.journeyType,
      journeyKind: journey.journeyKind,
      hasRawData: hasRawData,
    );
    final attached = header(true);
    backend.header = attached;
    // The list's stale header must be replaced by the detail snapshot.
    await openDetail();
    final session = flow.session!;
    expect(session.journey, same(attached));
    backend.header = header(false);
    final pending = Completer<void>();
    backend.pendingRawDataDelete = pending;

    final deletion = flow.deleteRawData();
    final failure = expectLater(deletion, throwsStateError);
    await startLoad();
    expect(flow.requestBack(), JourneyBackResult.blocked);
    expect(flow.leave(), isFalse);
    expect(GlobalLoadingManager.instance.isNavigationBlocked, isTrue);
    await flow.deleteRawData();
    expect(backend.rawDataDeleteCalls, 1);

    pending.completeError(StateError('Storage unavailable'));
    await failure;
    expect(flow.phase, JourneyPhase.viewing);
    expect(flow.session, same(session));
    expect(GlobalLoadingManager.instance.isNavigationBlocked, isFalse);

    backend.pendingRawDataDelete = null;
    await flow.deleteRawData();
    expect(backend.rawDataDeleteCalls, 2);
    expect(flow.phase, JourneyPhase.viewing);
    expect(flow.session!.journey, same(backend.header));
    expect(flow.session!.journey.hasRawData, isFalse);
    expect(flow.session!.mapData, same(session.mapData));
    expect(flow.session!.returnView, view);
    expect(flow.pickerRevision, 0);
    expect(backend.requests, hasLength(1));
    expect(backend.headerReads, 1);
    expect(GlobalLoadingManager.instance.isNavigationBlocked, isFalse);
  });

  test('track refresh publishes header and map together and retains the return camera', () async {
    final oldMap = await openDetail();
    final updated = JourneyHeader(
      id: journey.id,
      revision: 'updated',
      journeyDate: journey.journeyDate,
      createdAt: journey.createdAt,
      journeyType: journey.journeyType,
      journeyKind: journey.journeyKind,
      note: 'Updated track',
      hasRawData: journey.hasRawData,
    );
    backend.header = updated;
    final refreshing = flow.refreshTrack();
    await startLoad();
    flow.editInformation();
    await flow.deleteJourney();
    expect(flow.phase, JourneyPhase.refreshing);
    expect(flow.session!.journey, same(journey));
    expect(flow.session!.mapData.$1, same(oldMap));
    final updatedMap = _MapRenderer();
    // A later header must not replace the one belonging to this map request.
    backend.header = journey;
    backend.requests.last.complete((updatedMap, null));
    await refreshing;
    expect(flow.session!.journey, same(updated));
    expect(flow.session!.mapData.$1, same(updatedMap));
    expect(flow.phase, JourneyPhase.viewing);
    expect(backend.headerReads, 0);
    flow.requestBack();
    expect(flow.returnToView, view);
  });

  test('missing journeys return to the picker on open and refresh', () async {
    for (final refreshing in [false, true]) {
      if (refreshing) {
        backend.header = journey;
        await openDetail();
      }
      backend.header = null;
      final loading = refreshing
          ? flow.refreshTrack()
          : flow.open(journey, readMapView: () async => view);
      await startLoad();
      backend.requests.last.complete((_MapRenderer(), null));
      await loading;
      expect(flow.session, isNull);
      expect(flow.phase, JourneyPhase.picker);
      expect(flow.appChromeVisible, isTrue);
    }
  });

  for (final fail in [false, true]) {
    test(
      'a dismissed track refresh cannot finish a newer refresh (${fail ? 'error' : 'success'})',
      () async {
        await openDetail();
        backend.header = journey;
        final oldRefresh = flow.refreshTrack();
        await startLoad();
        final oldRequest = backend.requests.last;
        expect(flow.requestBack(), JourneyBackResult.handled);

        await openDetail();
        final newRefresh = flow.refreshTrack();
        await startLoad();
        if (fail) {
          oldRequest.completeError(StateError('Old track load failed'));
        } else {
          oldRequest.complete((_MapRenderer(), null));
        }
        await oldRefresh;
        expect(flow.phase, JourneyPhase.refreshing);
        final newMap = _MapRenderer();
        backend.requests.last.complete((newMap, null));
        await newRefresh;
        expect(flow.phase, JourneyPhase.viewing);
        expect(flow.session!.mapData.$1, same(newMap));
      },
    );
  }
}

class _JourneyApi extends Fake implements RustLibApi {
  final requests = <Completer<(api.MapRendererProxy, MapBounds?)>>[];
  final dateRequests = <Completer<(api.MapRendererProxy, MapBounds?)>>[];
  final dates = <DateTime>[];
  List<DateTime> journeyDates = [];
  JourneyHeader? header;
  int headerReads = 0;
  Completer<void>? pendingRawDataDelete;
  int rawDataDeleteCalls = 0;

  @override
  Future<bool> crateApiApiDeleteJourneyRawData({
    required String journeyId,
  }) async {
    rawDataDeleteCalls++;
    await pendingRawDataDelete?.future;
    return true;
  }

  @override
  api.MapRendererProxy crateApiApiGetEmptyMapRendererProxy() => _MapRenderer();

  @override
  Future<List<DateTime>> crateApiApiJourneyDates({
    Set<JourneyKind>? journeyKinds,
  }) async {
    expect(journeyKinds, isNull);
    return journeyDates;
  }

  @override
  Future<(api.MapRendererProxy, MapBounds?)>
  crateApiApiGetMapRendererProxyForJourneyDate({required DateTime date}) {
    dates.add(date);
    final request = Completer<(api.MapRendererProxy, MapBounds?)>();
    dateRequests.add(request);
    return request.future;
  }

  @override
  Future<JourneyHeader?> crateApiApiGetJourneyHeader({
    required String journeyId,
  }) async {
    headerReads++;
    return header;
  }

  @override
  Future<(JourneyHeader, api.MapRendererProxy, MapBounds?)?>
  crateApiApiGetJourneyDetail({required String journeyId}) async {
    final snapshotHeader = header;
    final request = Completer<(api.MapRendererProxy, MapBounds?)>();
    requests.add(request);
    final map = await request.future;
    return snapshotHeader == null ? null : (snapshotHeader, map.$1, map.$2);
  }
}

class _MapRenderer extends Fake implements api.MapRendererProxy {}

class _TestWakelockPlatform extends WakelockPlusMacOSPlugin {
  @override
  Future<void> toggle({required bool enable}) async {}

  @override
  Future<bool> get enabled async => false;
}
