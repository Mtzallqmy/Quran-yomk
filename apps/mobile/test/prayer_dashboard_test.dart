import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/prayer_settings.dart';
import 'package:tarteel/src/prayer_times.dart';
import 'package:tarteel/src/screens/home.dart';
import 'package:tarteel/src/services.dart';
import 'package:tarteel/src/theme.dart';

import 'ui_fixture.dart';

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
  for (final dark in [false, true]) {
    testWidgets(
      'local prayer dashboard RTL ${dark ? 'dark' : 'light'} large text',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 740);
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        SharedPreferences.setMockInitialValues({});
        final services = _PrayerServices(await SharedPreferences.getInstance());
        final instant = DateTime.utc(2026, 10, 23, 8, 30);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [servicesProvider.overrideWithValue(services)],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dark ? TarteelTheme.dark() : TarteelTheme.light(),
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: RepaintBoundary(
                    key: const ValueKey('prayer-dashboard'),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [DashboardPrayerTimes(clock: () => instant)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('تعز'), findsOneWidget);
        expect(find.text('01:30:00'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('prayer-dashboard')),
          matchesGoldenFile(
            'goldens/prayer_dashboard_${dark ? 'dark' : 'light'}_large_font.png',
          ),
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

class _PrayerServices extends UiServices {
  _PrayerServices(SharedPreferences preferences) : super(preferences) {
    prayerSettings = PrayerSettingsStore(preferences)..load();
  }

  @override
  late final PrayerSettingsStore prayerSettings;
  @override
  final PrayerTimesService prayerTimes = _FixedPrayerTimes();
}

class _FixedPrayerTimes extends PrayerTimesService {
  @override
  Future<PrayerSnapshot> snapshot({
    DateTime? now,
    required PrayerSettings settings,
  }) async {
    final date = DateTime.utc(2026, 10, 23);
    final times = {
      PrayerKind.fajr: DateTime.utc(2026, 10, 23, 5),
      PrayerKind.sunrise: DateTime.utc(2026, 10, 23, 6, 15),
      PrayerKind.dhuhr: DateTime.utc(2026, 10, 23, 10),
      PrayerKind.asr: DateTime.utc(2026, 10, 23, 15),
      PrayerKind.maghrib: DateTime.utc(2026, 10, 23, 18),
      PrayerKind.isha: DateTime.utc(2026, 10, 23, 19, 15),
    };
    return PrayerSnapshot(
      today: PrayerDay(date: date, timezone: 'Asia/Aden', times: times),
      next: PrayerOccurrence(
        prayer: PrayerKind.dhuhr,
        time: times[PrayerKind.dhuhr]!,
      ),
    );
  }
}
