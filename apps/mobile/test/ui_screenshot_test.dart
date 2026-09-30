import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/app.dart';
import 'package:tarteel/src/l10n.dart';
import 'package:tarteel/src/navigation.dart';
import 'package:tarteel/src/screens/settings.dart';
import 'package:tarteel/src/screens/player.dart';
import 'package:tarteel/src/services.dart';
import 'package:tarteel/src/theme.dart';
import 'ui_fixture.dart';

/// Goldens deliberately cover deterministic offline/idle states. Quran page
/// assets and live audio are never replaced with demo content in production.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, asset) in [
      ('TarteelUI', 'assets/fonts/NotoSansArabic.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(family)..addFont(rootBundle.load(asset));
      await loader.load();
    }
  });
  const profiles = <String, (Size, double)>{
    'small': (Size(360, 740), 1),
    'medium': (Size(412, 915), 1),
    'large_font': (Size(360, 740), 1.6),
  };
  const scenes = [
    'home_light',
    'home_dark',
    'quran',
    'reader_offline',
    'listen',
    'radio',
    'library',
    'player_idle',
    'settings',
  ];
  for (final profile in profiles.entries) {
    for (final scene in scenes) {
      testWidgets('$scene ${profile.key}', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = profile.value.$1;
        tester.platformDispatcher.textScaleFactorTestValue = profile.value.$2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        SharedPreferences.setMockInitialValues({
          'tarteel_remote_config:v1': '{"prayer_features_enabled":false}',
        });
        final services = UiServices(await SharedPreferences.getInstance());
        final dark = scene == 'home_dark';
        await services.settings.setThemeMode(
          dark ? ThemeMode.dark : ThemeMode.light,
        );
        Widget child;
        if ([
          'home_light',
          'home_dark',
          'quran',
          'listen',
          'radio',
          'library',
        ].contains(scene)) {
          services.settings.mobileDestination = switch (scene) {
            'home_light' || 'home_dark' => 'home',
            _ => scene,
          };
          child = const TarteelApp();
        } else {
          child = MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: TarteelTheme.light(),
            onGenerateRoute: MobileRoutes.generate,
            initialRoute: scene == 'reader_offline'
                ? MobileRoutes.reader
                : null,
            home: scene == 'settings'
                ? const SettingsPage()
                : const FullPlayerPage(),
          );
        }
        await tester.pumpWidget(
          ProviderScope(
            overrides: [servicesProvider.overrideWithValue(services)],
            child: RepaintBoundary(key: const ValueKey('screen'), child: child),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('screen')),
          matchesGoldenFile('goldens/${scene}_${profile.key}.png'),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  }
}
