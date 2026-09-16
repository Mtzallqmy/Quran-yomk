import 'package:flutter_test/flutter_test.dart';
import 'package:tarteel/src/prayer_settings.dart';
import 'package:tarteel/src/prayer_times.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Makkah preset uses Umm al-Qura and returns ordered prayer times', () async {
    final settings = PrayerSettings.makkah();
    expect(settings.locationName, 'مكة المكرمة');
    expect(settings.timezone, 'Asia/Riyadh');
    expect(
      settings.calculationMethod,
      PrayerCalculationMethod.ummAlQura,
    );

    final day = await PrayerTimesService().dayFor(
      date: DateTime(2026, 9, 16),
      settings: settings,
    );

    expect(
      day.timeFor(PrayerKind.fajr).isBefore(day.timeFor(PrayerKind.sunrise)),
      isTrue,
    );
    expect(
      day.timeFor(PrayerKind.sunrise).isBefore(day.timeFor(PrayerKind.dhuhr)),
      isTrue,
    );
    expect(
      day.timeFor(PrayerKind.dhuhr).isBefore(day.timeFor(PrayerKind.asr)),
      isTrue,
    );
    expect(
      day.timeFor(PrayerKind.asr).isBefore(day.timeFor(PrayerKind.maghrib)),
      isTrue,
    );
    expect(
      day.timeFor(PrayerKind.maghrib).isBefore(day.timeFor(PrayerKind.isha)),
      isTrue,
    );
  });

  test('per-prayer adjustment shifts only the selected prayer', () async {
    final service = PrayerTimesService();
    final base = PrayerSettings.makkah();
    final adjusted = base.copyWith(
      offsets: const <PrayerKind, int>{PrayerKind.fajr: 10},
    );
    final date = DateTime(2026, 9, 16);

    final baseDay = await service.dayFor(date: date, settings: base);
    final adjustedDay = await service.dayFor(date: date, settings: adjusted);

    expect(
      adjustedDay
          .timeFor(PrayerKind.fajr)
          .difference(baseDay.timeFor(PrayerKind.fajr))
          .inMinutes,
      10,
    );
    expect(
      adjustedDay
          .timeFor(PrayerKind.dhuhr)
          .difference(baseDay.timeFor(PrayerKind.dhuhr))
          .inMinutes,
      0,
    );
  });

  test('qibla direction for Makkah is a valid bearing', () async {
    final direction = await PrayerTimesService().qiblaDirection(
      PrayerSettings.makkah(),
    );
    expect(direction, inInclusiveRange(0.0, 360.0));
  });
}
