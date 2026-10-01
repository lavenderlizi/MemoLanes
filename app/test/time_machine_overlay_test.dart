import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memolanes/body/map/overlay/time_machine_overlay.dart';
import 'package:memolanes/body/time_machine/time_range_picker.dart';
import 'package:memolanes/common/app_translation_loader.dart';
import 'package:memolanes/common/component/base_map_webview.dart';
import 'package:memolanes/common/simple_date_utils.dart';
import 'package:memolanes/src/rust/api/api.dart' as api;
import 'package:memolanes/src/rust/frb_generated.dart';
import 'package:memolanes/src/rust/journey_header.dart';
import 'package:memolanes/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = _RangeApi();
  const locale = Locale('en', 'US');
  const loader = AppTranslationLoader();
  final published = <(api.MapRendererProxy, MapBounds?)>[];

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : null,
        );
    await EasyLocalization.ensureInitialized();
    await loader.load('assets/translations', locale);
    RustLib.initMock(api: backend);
  });
  tearDownAll(RustLib.dispose);
  setUp(() {
    backend.requests.clear();
    published.clear();
  });

  Future<void> pumpOverlay(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [locale],
          path: 'assets/translations',
          assetLoader: loader,
          fallbackLocale: locale,
          child: Builder(
            builder: (context) => MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: Scaffold(
                body: TimeMachineOverlay(onJourneyRangeLoaded: published.add),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
    });
    await tester.pump();
    expect(backend.requests, hasLength(1));
  }

  TimeRangePicker picker(WidgetTester tester) =>
      tester.widget(find.byType(TimeRangePicker));

  testWidgets(
    'scrolling coalesces requests and invalidates old results before the next load',
    (tester) async {
      await pumpOverlay(tester);
      final initial = backend.requests.single;
      picker(tester).onRangeChanged(SimpleDate(2020), SimpleDate(2022, 12, 31));
      await tester.pump(const Duration(milliseconds: 50));
      picker(tester).onRangeChanged(SimpleDate(2020), SimpleDate(2023, 12, 31));
      initial.result.complete((_MapRenderer(), null));
      await tester.pump();
      expect(published, isEmpty);
      await tester.pump(const Duration(milliseconds: 50));
      expect(backend.requests, hasLength(2));
      final current = backend.requests.last;
      expect(current.to, DateTime.utc(2023, 12, 31));
      expect(current.kinds, {JourneyKind.defaultKind, JourneyKind.flight});
      final map = _MapRenderer();
      const bounds = MapBounds(west: -120, south: -30, east: 130, north: 50);
      current.result.complete((map, bounds));
      await tester.pump();
      expect(published, [(map, bounds)]);
      // Releasing on the same tick must not reload data or restart the flight.
      picker(tester)
          .onRangeCommitted!(SimpleDate(2020), SimpleDate(2023, 12, 31));
      await tester.pump();
      expect(backend.requests, hasLength(2));
    },
  );

  testWidgets(
    'layer changes publish matching bounds and ignore superseded range results',
    (tester) async {
      await pumpOverlay(tester);
      final first = backend.requests.single;
      picker(tester).onJourneyKindsChanged!({JourneyKind.flight});
      await tester.pump();
      final flight = backend.requests.last;
      expect(flight.kinds, {JourneyKind.flight});
      final map = _MapRenderer();
      const bounds = MapBounds(west: 110, south: 20, east: 150, north: 40);
      flight.result.complete((map, bounds));
      await tester.pump();
      first.result.complete((_MapRenderer(), null));
      await tester.pump();
      expect(published, [(map, bounds)]);
    },
  );

  testWidgets(
    'empty ranges clear tracks and pending loads cannot publish after leaving',
    (tester) async {
      await pumpOverlay(tester);
      final empty = _MapRenderer();
      backend.requests.single.result.complete((empty, null));
      await tester.pump();
      expect(published, [(empty, null)]);
      picker(tester)
          .onRangeCommitted!(SimpleDate(2021), SimpleDate(2021, 12, 31));
      final pending = backend.requests.last;
      await tester.pumpWidget(const SizedBox());
      pending.result.complete((_MapRenderer(), null));
      await tester.pump();
      expect(published, [(empty, null)]);
    },
  );
}

class _RangeRequest {
  _RangeRequest(this.to, this.kinds);
  final DateTime to;
  final Set<JourneyKind> kinds;
  final result = Completer<(api.MapRendererProxy, MapBounds?)>();
}

class _RangeApi extends Fake implements RustLibApi {
  final requests = <_RangeRequest>[];

  @override
  api.LayerFilter crateApiApiGetCurrentMainMapLayerFilter() => api.LayerFilter(
    currentJourney: true,
    defaultKind: true,
    flightKind: true,
  );

  @override
  Future<DateTime?> crateApiApiEarliestJourneyDate() async =>
      DateTime.utc(2020);

  @override
  Future<(api.MapRendererProxy, MapBounds?)>
  crateApiApiGetMapRendererProxyForJourneyDateRange({
    required DateTime fromDateInclusive,
    required DateTime toDateInclusive,
    required Set<JourneyKind> journeyKinds,
  }) {
    final request = _RangeRequest(toDateInclusive, journeyKinds);
    requests.add(request);
    return request.result.future;
  }
}

class _MapRenderer extends Fake implements api.MapRendererProxy {}
