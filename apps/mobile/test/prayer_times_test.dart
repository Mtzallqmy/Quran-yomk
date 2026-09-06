import 'package:flutter_test/flutter_test.dart';
import 'package:tarteel/src/prayer_settings.dart';
import 'package:tarteel/src/prayer_times.dart';

void main() {
  final service = PrayerTimesService();

  test('known Taiz day is ordered and timezone independent', () async {
    final settings = PrayerSettings.taiz();
    final day = await service.dayFor(
      date: DateTime.utc(2026, 1, 15),
      settings: settings,
    );

    expect(day.timezone, 'Asia/Aden');
    expect(day.timeFor(PrayerKind.fajr).timeZoneOffset, const Duration(hours: 3));
    expect(day.timeFor(PrayerKind.fajr).hour, inInclusiveRange(4, 6));
    expect(day.timeFor(PrayerKind.dhuhr).hour, inInclusiveRange(11, 13));
    expect(day.timeFor(PrayerKind.maghrib).hour, inInclusiveRange(17, 19));
    for (var index = 1; index < day.ordered.length; index++) {
      expect(day.ordered[index].time.isAfter(day.ordered[index - 1].time), isTrue);
    }

    final repeated = await service.dayFor(
      date: DateTime.utc(2026, 1, 15),
      settings: settings,
    );
    expect(
      PrayerKind.values.map(repeated.timeFor),
      PrayerKind.values.map(day.timeFor),
    );
  });

  test('offsets are applied after local calculation', () async {
    final baseline = PrayerSettings.taiz();
    final adjusted = baseline.copyWith(
      offsets: const <PrayerKind, int>{PrayerKind.maghrib: 7},
    );
    final date = DateTime.utc(2026, 6, 1);
    final first = await service.dayFor(date: date, settings: baseline);
    final second = await service.dayFor(date: date, settings: adjusted);

    expect(
      second.timeFor(PrayerKind.maghrib).difference(
        first.timeFor(PrayerKind.maghrib),
      ),
      const Duration(minutes: 7),
    );
  });

  test('next prayer rolls to tomorrow after Isha', () async {
    final snapshot = await service.snapshot(
      now: DateTime.utc(2026, 1, 15, 21),
      settings: PrayerSettings.taiz(),
    );

    expect(snapshot.next.prayer, PrayerKind.fajr);
    expect(snapshot.next.time.isAfter(DateTime.utc(2026, 1, 15, 21)), isTrue);
    expect(snapshot.next.time.day, 16);
  });
}
