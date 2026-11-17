import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/learning.dart';
import 'package:tarteel/src/prayer_settings.dart';
import 'package:tarteel/src/prayer_times.dart';
import 'package:tarteel/src/screens/worship.dart';
import 'package:tarteel/src/services.dart';

import 'ui_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Qibla uses a true-north bearing for locally configured locations', () {
    final defaults = PrayerSettings.taiz();
    final service = PrayerTimesService();
    expect(service.qiblaBearing(defaults), closeTo(333.58, .01));
    expect(
      service.qiblaBearing(
        defaults.copyWith(latitude: 51.5074, longitude: -.1278),
      ),
      closeTo(118.99, .01),
    );
    expect(
      service.qiblaBearing(
        defaults.copyWith(latitude: -6.2088, longitude: 106.8456),
      ),
      closeTo(295.15, .01),
    );
    expect(
      service.qiblaBearing(
        defaults.copyWith(latitude: 21.4225241, longitude: 39.8261818),
      ),
      isNull,
    );
  });

  testWidgets('tasbih persists without a network or account', (tester) async {
    SharedPreferences.setMockInitialValues({
      'tarteel_remote_config:v1': '{"prayer_features_enabled":false}',
    });
    final preferences = await SharedPreferences.getInstance();
    final services = _WorshipServices(preferences);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services)],
        child: const MaterialApp(home: WorshipPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('زيادة العدّاد'));
    await tester.pumpAndSettle();
    expect(LearningStore(preferences).tasbihCount, 1);
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.text('تصفير'));
    await tester.pumpAndSettle();
    expect(LearningStore(preferences).tasbihCount, 0);
  });
}

class _WorshipServices extends UiServices {
  _WorshipServices(SharedPreferences preferences)
    : _prayerSettings = PrayerSettingsStore(preferences)..load(),
      _learning = LearningStore(preferences)..load(),
      super(preferences);

  final PrayerSettingsStore _prayerSettings;
  final PrayerTimesService _prayerTimes = PrayerTimesService();
  final LearningStore _learning;

  @override
  PrayerSettingsStore get prayerSettings => _prayerSettings;
  @override
  PrayerTimesService get prayerTimes => _prayerTimes;
  @override
  LearningStore get learning => _learning;
}
