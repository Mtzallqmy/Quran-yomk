import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/adhan_audio.dart';
import 'package:tarteel/src/adhan_library.dart';
import 'package:tarteel/src/prayer_settings.dart';
import 'package:tarteel/src/prayer_times.dart';
import 'package:tarteel/src/screens/prayer_times.dart';
import 'package:tarteel/src/services.dart';
import 'package:tarteel/src/theme.dart';
import 'ui_fixture.dart';

class _Services extends UiServices {
  _Services(SharedPreferences preferences) : super(preferences) {
    _prayerSettings = PrayerSettingsStore(preferences)..load();
    _adhanLibrary = AdhanLibraryStore(preferences)..load();
    _adhanAudio = AdhanAudioService(playback: playback, player: _Player());
  }
  late final PrayerSettingsStore _prayerSettings;
  late final AdhanLibraryStore _adhanLibrary;
  late final AdhanAudioService _adhanAudio;
  final PrayerTimesService _prayerTimes = PrayerTimesService();
  @override
  PrayerSettingsStore get prayerSettings => _prayerSettings;
  @override
  AdhanLibraryStore get adhanLibrary => _adhanLibrary;
  @override
  AdhanAudioService get adhanAudio => _adhanAudio;
  @override
  PrayerTimesService get prayerTimes => _prayerTimes;
}

class _Player implements AdhanPlayerGateway {
  @override
  Future<void> playAsset(String path) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  Future<_Services> services() async {
    SharedPreferences.setMockInitialValues({});
    return _Services(await SharedPreferences.getInstance());
  }

  Future<void> show(
    WidgetTester tester,
    _Services services,
    Widget page,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services)],
        child: MaterialApp(
          theme: TarteelTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: page,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'prayer settings remain usable in narrow RTL with large Arabic text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = await services();
      await service.prayerSettings.setReminderMode(
        PrayerKind.fajr,
        PrayerReminderMode.adhan,
      );
      await show(tester, service, const PrayerSettingsPage());
      await tester.scrollUntilVisible(find.text('صلاة الفجر'), 250);
      await tester.tap(find.text('صلاة الفجر'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('صوت خاص لهذه الصلاة'), 180);
      expect(find.text('صوت خاص لهذه الصلاة'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await service.adhanAudio.close();
    },
  );
  testWidgets('weekly and monthly calendar exposes all dates without network', (
    tester,
  ) async {
    final service = await services();
    await show(tester, service, const PrayerCalendarPage());
    expect(
      find.byType(DataRow),
      findsNothing,
    ); // Rows render through DataTable.
    final weekly = tester.widget<DataTable>(find.byType(DataTable));
    expect(weekly.rows, hasLength(7));
    await tester.tap(find.text('شهري — ٣٠ يومًا'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<DataTable>(find.byType(DataTable)).rows,
      hasLength(30),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await service.adhanAudio.close();
  });
}
