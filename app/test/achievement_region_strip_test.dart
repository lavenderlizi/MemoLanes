import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memolanes/body/achievement/achievement_region_strip.dart';
import 'package:memolanes/common/app_translation_loader.dart';
import 'package:memolanes/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const locale = Locale('zh', 'CN');
  const loader = AppTranslationLoader();
  const country = (id: 1, name: '国家概览', visitedKm2: 6.0, totalKm2: 100.0);
  const regions = [
    (id: 11, name: '区域一', visitedKm2: 3.0, totalKm2: 30.0),
    (id: 12, name: '区域二', visitedKm2: 2.0, totalKm2: 30.0),
    (id: 13, name: '区域三', visitedKm2: 1.0, totalKm2: 40.0),
  ];

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : null,
        );
    await EasyLocalization.ensureInitialized();
    await loader.load('assets/translations', locale);
  });

  Future<void> pumpStrip(
    WidgetTester tester,
    ValueNotifier<int?> selected,
    List<int?> changes, {
    VoidCallback? onRanking,
  }) async {
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
                body: Center(
                  child: SizedBox(
                    width: 360,
                    height: 144,
                    child: ValueListenableBuilder<int?>(
                      valueListenable: selected,
                      builder: (_, id, _) => AchievementRegionStrip(
                        country: country,
                        regions: regions,
                        selectedId: id,
                        onRanking: onRanking ?? () {},
                        onSelected: (id) {
                          changes.add(id);
                          selected.value = id;
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'swiping selects a region and swiping back restores country overview',
    (tester) async {
      final selected = ValueNotifier<int?>(null);
      addTearDown(selected.dispose);
      final changes = <int?>[];
      var rankingOpened = false;
      await pumpStrip(
        tester,
        selected,
        changes,
        onRanking: () => rankingOpened = true,
      );
      expect(changes, isEmpty);
      await tester.tap(find.text('区域排行'));
      expect(rankingOpened, isTrue);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(changes, [11]);
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(changes, [11, null]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'map selection skips intermediate callbacks and allows subsequent swipes',
    (tester) async {
      final selected = ValueNotifier<int?>(null);
      addTearDown(selected.dispose);
      final changes = <int?>[];
      await pumpStrip(tester, selected, changes);
      selected.value = 13;
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PageView>(find.byType(PageView))
            .controller!
            .page!
            .round(),
        3,
      );
      expect(changes, isEmpty);
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(changes, [12]);
      expect(tester.takeException(), isNull);
    },
  );
}
