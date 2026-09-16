import 'package:flutter_test/flutter_test.dart';
import 'package:tarteel/src/prayer_settings.dart';
import 'package:tarteel/src/prayer_times.dart';

void main() {
  final service = PrayerTimesService();

  test('manual times persist and use Aden wall time without offsets', () async {
    final settings = PrayerSettings.fromJson(PrayerSettings.taiz().copyWith(
      manualTimes: {PrayerKind.fajr: 315},
      offsets: {PrayerKind.fajr: 20},
    ).toJson());
    final day = await service.dayFor(date: DateTime(2026, 9, 16), settings: settings);
    final fajr = day.timeFor(PrayerKind.fajr);
    expect(fajr.hour, 5);
    expect(fajr.minute, 15);
    expect(fajr.timeZoneOffset, const Duration(hours: 3));
    expect(settings.manualTimes[PrayerKind.fajr], 315);
  });

  test('invalid manual values fall back to calculated times', () {
    final json = PrayerSettings.taiz().toJson();
    json['manual_times'] = {'fajr': -1, 'dhuhr': 1440, 'asr': '15:00'};
    expect(PrayerSettings.fromJson(json).manualTimes, isEmpty);
  });

  test('next prayer follows actual manual time order', () async {
    final day = await service.dayFor(date: DateTime(2026, 9, 16),
      settings: PrayerSettings.taiz().copyWith(manualTimes: {
        PrayerKind.fajr: 720, PrayerKind.dhuhr: 600,
        PrayerKind.asr: 900, PrayerKind.maghrib: 1080, PrayerKind.isha: 1200,
      }));
    expect(day.nextOnDay(DateTime.utc(2026, 9, 16, 6))!.prayer, PrayerKind.dhuhr);
  });

  test('known Taiz day is ordered and timezone independent', () async {
    final settings = PrayerSettings.taiz();
    final day = await service.dayFor(
      date: DateTime.utc(2026, 1, 15),
      settings: settings,
    );

    expect(day.timezone, 'Asia/Aden');
    expect(
      day.timeFor(PrayerKind.fajr).timeZoneOffset,
      const Duration(hours: 3),
    );
    expect(day.timeFor(PrayerKind.fajr).hour, inInclusiveRange(4, 6));
    expect(day.timeFor(PrayerKind.dhuhr).hour, inInclusiveRange(11, 13));
    expect(day.timeFor(PrayerKind.maghrib).hour, inInclusiveRange(17, 19));
    for (var index = 1; index < day.ordered.length; index++) {
      expect(
        day.ordered[index].time.isAfter(day.ordered[index - 1].time),
        isTrue,
      );
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
      second
          .timeFor(PrayerKind.maghrib)
          .difference(first.timeFor(PrayerKind.maghrib)),
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
