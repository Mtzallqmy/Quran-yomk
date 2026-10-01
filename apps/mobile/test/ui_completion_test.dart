import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarteel/src/app.dart';
import 'package:tarteel/src/models.dart';
import 'package:tarteel/src/quran_audio.dart';
import 'package:tarteel/src/services.dart';
import 'ui_fixture.dart';
import 'ui_navigation_test.dart' show uiServices;

const station = Station(
  id: 'test-station',
  slug: 'test-radio',
  nameAr: 'إذاعة الحرم للاختبار',
  source: 'EXTERNAL',
  streamType: 'LIVE',
  category: 'QURAN_GENERAL',
  healthStatus: 'HEALTHY',
  playbackUrl: 'https://example.invalid/test-only.mp3',
  isFeatured: true,
);
const edition = QuranAudioCatalogReciter(
  id: 'mp3quran:1:1',
  provider: QuranAudioProviderKind.mp3Quran,
  edition: '1',
  nameAr: 'قارئ الاختبار',
  nameEn: 'Test reciter',
  riwayah: 'رواية الاختبار',
  availableSurahs: {1, 2},
  bitrates: {128},
);

Future<void> shell(WidgetTester tester, UiServices services) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      child: const TarteelApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'radio metadata is real; station name taps never start playback',
    (tester) async {
      final services = await uiServices();
      services.repository.stationValues = [station];
      await shell(tester, services);
      await tester.tap(find.byKey(const ValueKey('destination-radio')));
      await tester.pumpAndSettle();
      expect(find.text('الآن على الهواء'), findsOneWidget);
      expect(find.text('تلاوة من بيانات الاختبار'), findsOneWidget);
      await tester.tap(find.text(station.nameAr).first);
      await tester.pumpAndSettle();
      expect(services.playback.playedStations, isEmpty);
      await tester.tap(find.text('تشغيل').first);
      await tester.pumpAndSettle();
      expect(services.playback.playedStations, [station]);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'active radio pause reuses the playback session and honors reduced motion',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final services = await uiServices();
      services.repository.stationValues = [station];
      services.playback.item = const MediaItem(
        id: 'station:test-station',
        title: 'إذاعة الحرم للاختبار',
        isLive: true,
        extras: {'kind': 'station', 'entity_id': 'test-station'},
      );
      services.playback.playing = true;
      await shell(tester, services);
      await tester.tap(find.byKey(const ValueKey('destination-radio')));
      await tester.pumpAndSettle();
      expect(find.text('جارٍ التشغيل'), findsOneWidget);
      await tester.tap(find.text('إيقاف مؤقت').first);
      await tester.pumpAndSettle();
      expect(services.playback.pauseCalls, 1);
      expect(services.playback.playedStations, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'edition browser opens canonical details and keeps favorites consistent',
    (tester) async {
      final services = await uiServices();
      (services.quranAudio as UiAudio).values = [edition];
      await services.favorites.toggleReciter(edition.id);
      await shell(tester, services);
      await tester.tap(find.byKey(const ValueKey('destination-listen')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('المصاحف'));
      await tester.pumpAndSettle();
      expect(find.text('1 مصحف صوتي متاح'), findsOneWidget);
      await tester.tap(find.text(edition.riwayah!).first);
      await tester.pumpAndSettle();
      expect(find.text('MP3Quran'), findsOneWidget);
      await tester.tap(find.byTooltip('المفضلة'));
      await tester.pumpAndSettle();
      expect(services.favorites.isReciter(edition.id), isFalse);
      expect(services.favorites.isReciter(edition.identityKey), isFalse);
      await tester.tap(find.byTooltip('المفضلة'));
      await tester.pumpAndSettle();
      expect(services.favorites.isReciter(edition.identityKey), isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('search scope restores after closing and reopening the screen', (
    tester,
  ) async {
    final services = await uiServices();
    await shell(tester, services);
    await tester.tap(find.byIcon(Icons.search).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'القرآن'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search).first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'القرآن'))
          .selected,
      isTrue,
    );
    expect(services.settings.searchScope, 'quran');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'settings groups and downloads action remain usable with large text',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final services = await uiServices();
      await shell(tester, services);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).labelBehavior,
        NavigationDestinationLabelBehavior.onlyShowSelected,
      );
      await tester.tap(find.byKey(const ValueKey('destination-library')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('الإعدادات'), 300);
      await tester.tap(find.text('الإعدادات'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('التنزيلات ومساحة التخزين'),
        300,
      );
      await tester.tap(find.text('التنزيلات ومساحة التخزين'));
      await tester.pumpAndSettle();
      expect(find.text('لا توجد تنزيلات'), findsOneWidget);
      expect(find.text('استعرض القراء'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
