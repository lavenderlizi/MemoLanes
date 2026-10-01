import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memolanes/body/time_machine/time_range_picker.dart';
import 'package:memolanes/common/app_haptics.dart';
import 'package:memolanes/common/app_translation_loader.dart';
import 'package:memolanes/common/simple_date_utils.dart';
import 'package:memolanes/src/rust/journey_header.dart';
import 'package:memolanes/theme/app_theme.dart';

const _loader = AppTranslationLoader();
const _enUs = Locale('en', 'US');

Widget _buildTestApp({
  required void Function(SimpleDate from, SimpleDate to) onRangeChanged,
}) {
  return EasyLocalization(
    supportedLocales: const [_enUs],
    path: 'assets/translations',
    assetLoader: _loader,
    fallbackLocale: _enUs,
    child: Builder(
      builder: (context) => MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 80),
              child: TimeRangePicker(
                earliestDate: SimpleDate(2020),
                selectedJourneyKinds: const {JourneyKind.defaultKind},
                onRangeChanged: onRangeChanged,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : null,
        );
    await EasyLocalization.ensureInitialized();
    await _loader.load('assets/translations', _enUs);
  });

  testWidgets('defaults to the cumulative as-of range', (tester) async {
    final ranges = <(SimpleDate, SimpleDate)>[];
    final currentYear = DateTime.now().year;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        _buildTestApp(onRangeChanged: (from, to) => ranges.add((from, to))),
      );
      await tester.pump(const Duration(seconds: 1));
    });
    await tester.pumpAndSettle();

    expect(ranges, isNotEmpty);
    expect(ranges.last.$1, SimpleDate(2020));
    expect(ranges.last.$2, SimpleDate(currentYear, 12, 31));
  });

  testWidgets(
    'scroll previews update the map range without moving the ruler selection',
    (tester) async {
      final ranges = <(SimpleDate, SimpleDate)>[];
      await tester.runAsync(() async {
        await tester.pumpWidget(
          _buildTestApp(onRangeChanged: (from, to) => ranges.add((from, to))),
        );
        await tester.pump(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();
      final ruler = tester.widget<TimeRuler>(find.byType(TimeRuler));
      ruler.onDisplayChanged!((2022, null, null));
      await tester.pump();
      expect(ranges.last, (SimpleDate(2020), SimpleDate(2022, 12, 31)));
      expect(
        tester.widget<TimeRuler>(find.byType(TimeRuler)).selectedYear,
        ruler.selectedYear,
      );
      ruler.onSelectionChanged((2022, null, null));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TimeRuler>(find.byType(TimeRuler)).selectedYear,
        2022,
      );
    },
  );

  testWidgets('dragging the timeline publishes ranges before release', (
    tester,
  ) async {
    AppHaptics.debugHapticsEnabledOverride = false;
    addTearDown(() => AppHaptics.debugHapticsEnabledOverride = null);
    final ranges = <(SimpleDate, SimpleDate)>[];
    await tester.runAsync(() async {
      await tester.pumpWidget(
        _buildTestApp(onRangeChanged: (from, to) => ranges.add((from, to))),
      );
      await tester.pump(const Duration(seconds: 1));
    });
    await tester.pumpAndSettle();
    final original = ranges.last;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TimeRuler)),
    );
    await gesture.moveBy(const Offset(36, 0));
    await tester.pump(const Duration(milliseconds: 120));
    await gesture.moveBy(const Offset(72, 0));
    await tester.pump(const Duration(milliseconds: 120));
    expect(ranges.last.$2.isBefore(original.$2), isTrue);
    expect(
      tester.widget<TimeRuler>(find.byType(TimeRuler)).selectedYear,
      DateTime.now().year,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
