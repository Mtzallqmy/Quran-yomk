import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/screens/player.dart';
import 'package:tarteel/src/services.dart';
import 'package:tarteel/src/storage.dart';
import 'package:tarteel/src/theme.dart';
import 'package:tarteel/src/l10n.dart';
import 'ui_fixture.dart';

void main() {
  test(
    'last selected destination restores from existing settings store',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settings = SettingsStore(preferences)..load();
      await settings.setMobileDestination('library');
      expect((SettingsStore(preferences)..load()).mobileDestination, 'library');
    },
  );
  for (final live in [false, true]) {
    testWidgets('full player live=$live uses actual position and duration', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final services = UiServices(await SharedPreferences.getInstance());
      services.playback.item = MediaItem(
        id: 'test-only',
        title: 'محتوى للاختبار',
        isLive: live,
        duration: const Duration(minutes: 20),
        extras: {
          'kind': live ? 'test_live' : 'quran_audio',
          'entity_id': 'test-only',
        },
      );
      services.playback.position = const Duration(seconds: 73);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [servicesProvider.overrideWithValue(services)],
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: TarteelTheme.dark(),
            home: const FullPlayerPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Slider), live ? findsOneWidget : findsNWidgets(2));
      if (!live) {
        expect(find.text('01:13'), findsOneWidget);
        expect(find.text('20:00'), findsOneWidget);
        await tester.ensureVisible(find.byTooltip('المفضلة'));
        await tester.tap(find.byTooltip('المفضلة'));
        await tester.pumpAndSettle();
        expect(services.favorites.isTrack('test-only'), isTrue);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final hasSession in [false, true]) {
    testWidgets('mini player session=$hasSession at large font scale', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final services = UiServices(await SharedPreferences.getInstance());
      if (hasSession)
        services.playback.item = const MediaItem(
          id: 'test-only',
          title: 'تلاوة للاختبار',
          artist: 'قارىء للاختبار',
        );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [servicesProvider.overrideWithValue(services)],
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: TarteelTheme.dark(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const Scaffold(bottomNavigationBar: MiniPlayerBar()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('تلاوة للاختبار'),
        hasSession ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
