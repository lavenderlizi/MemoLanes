import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memolanes/body/time_machine/time_range_picker.dart';
import 'package:memolanes/common/app_translation_loader.dart';
import 'package:memolanes/src/rust/journey_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const loader = AppTranslationLoader();
  const enUs = Locale('en', 'US');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : null,
    );
    await EasyLocalization.ensureInitialized();
  });

  testWidgets(
      'mode menu keeps its content size and leaves the timeline interactive',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final app = EasyLocalization(
      supportedLocales: const [enUs],
      path: 'assets/translations',
      assetLoader: loader,
      fallbackLocale: enUs,
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 80),
                child: TimeRangePicker(
                  earliestDate: DateTime(2020),
                  selectedJourneyKinds: const {JourneyKind.defaultKind},
                  onRangeChanged: (_, __) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(app);
      await tester.pump(const Duration(seconds: 1));
    });
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TimeRangeControllerBall));
    await tester.pumpAndSettle();

    final asOfText = find.text('As of');
    expect(asOfText, findsOneWidget);
    final menuGlass = find.ancestor(
      of: asOfText,
      matching: find.byType(BackdropFilter),
    );
    expect(menuGlass, findsOneWidget);
    final menuSize = tester.getSize(menuGlass);
    expect(menuSize.width, lessThan(tester.view.physicalSize.width / 3));
    expect(menuSize.height, lessThan(tester.view.physicalSize.height / 3));

    await tester.drag(find.byType(TimeRuler), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(asOfText, findsOneWidget);

    await tester.tapAt(const Offset(350, 20));
    await tester.pumpAndSettle();
    expect(asOfText, findsNothing);
  });
}
