import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memolanes/common/app_translation_loader.dart';
import 'package:memolanes/common/component/bottom_nav_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const locale = Locale('en', 'US');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : null,
    );
    await EasyLocalization.ensureInitialized();
  });

  Widget buildApp(int selectedIndex) {
    return EasyLocalization(
      supportedLocales: const [locale],
      path: 'assets/translations',
      assetLoader: const AppTranslationLoader(),
      fallbackLocale: locale,
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: BottomNavBar.height,
                child: BottomNavBar(
                  selectedIndex: selectedIndex,
                  onIndexChanged: (_) {},
                  hasUpdateNotification: () => true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('selection animation is valid on first build and update',
      (tester) async {
    await tester.pumpWidget(buildApp(0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(buildApp(4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
