import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'prayer_settings.dart';

@immutable
class PrayerOccurrence {
  const PrayerOccurrence({required this.prayer, required this.time});

  final PrayerKind prayer;
  final DateTime time;
}

@immutable
class PrayerDay {
  const PrayerDay({
    required this.date,
    required this.timezone,
    required this.times,
  });

  final DateTime date;
  final String timezone;
  final Map<PrayerKind, DateTime> times;

  DateTime timeFor(PrayerKind prayer) => times[prayer]!;

  List<PrayerOccurrence> get ordered =>
      PrayerKind.values
          .map(
            (prayer) => PrayerOccurrence(prayer: prayer, time: timeFor(prayer)),
          )
          .toList(growable: false)
        ..sort((left, right) => left.time.compareTo(right.time));

  List<PrayerOccurrence> get requiredPrayers => ordered
      .where((occurrence) => occurrence.prayer.isRequiredPrayer)
      .toList(growable: false);

  PrayerOccurrence? nextOnDay(DateTime now) {
    for (final occurrence in requiredPrayers) {
      if (occurrence.time.isAfter(now)) return occurrence;
    }
    return null;
  }
}

@immutable
class PrayerSnapshot {
  const PrayerSnapshot({required this.today, required this.next});

  final PrayerDay today;
  final PrayerOccurrence next;
}

class PrayerTimesService {
  Future<void>? _initialization;

  Future<void> initialize() => _initialization ??= Future<void>(() {
    tz_data.initializeTimeZones();
  });

  Future<PrayerDay> dayFor({
    required DateTime date,
    required PrayerSettings settings,
  }) async {
    await initialize();
    final location = tz.getLocation(settings.timezone);
    final localDate = tz.TZDateTime(location, date.year, date.month, date.day);
    final parameters = _parameters(settings)
      ..madhab = settings.asrMethod == PrayerAsrMethod.hanafi
          ? adhan.Madhab.hanafi
          : adhan.Madhab.shafi;
    final calculated = adhan.PrayerTimes(
      coordinates: adhan.Coordinates(settings.latitude, settings.longitude),
      date: localDate,
      calculationParameters: parameters,
    );
    DateTime local(DateTime value, PrayerKind prayer) {
      final manual = settings.manualTimes[prayer];
      // Manual time is the final user-selected time: do not add the
      // astronomical correction offset a second time.
      if (manual != null && manual >= 0 && manual < 1440) {
        return tz.TZDateTime(
          location,
          date.year,
          date.month,
          date.day,
          manual ~/ 60,
          manual % 60,
        );
      }
      return tz.TZDateTime.from(
        value,
        location,
      ).add(Duration(minutes: settings.offsetFor(prayer)));
    }

    return PrayerDay(
      date: localDate,
      timezone: location.name,
      times: Map<PrayerKind, DateTime>.unmodifiable(<PrayerKind, DateTime>{
        PrayerKind.fajr: local(calculated.fajr, PrayerKind.fajr),
        PrayerKind.sunrise: local(calculated.sunrise, PrayerKind.sunrise),
        PrayerKind.dhuhr: local(calculated.dhuhr, PrayerKind.dhuhr),
        PrayerKind.asr: local(calculated.asr, PrayerKind.asr),
        PrayerKind.maghrib: local(calculated.maghrib, PrayerKind.maghrib),
        PrayerKind.isha: local(calculated.isha, PrayerKind.isha),
      }),
    );
  }

  Future<PrayerSnapshot> snapshot({
    DateTime? now,
    required PrayerSettings settings,
  }) async {
    await initialize();
    final location = tz.getLocation(settings.timezone);
    final localNow = tz.TZDateTime.from(now ?? DateTime.now(), location);
    final today = await dayFor(date: localNow, settings: settings);
    final nextToday = today.nextOnDay(localNow);
    if (nextToday != null) {
      return PrayerSnapshot(today: today, next: nextToday);
    }
    final tomorrowDate = tz.TZDateTime(
      location,
      localNow.year,
      localNow.month,
      localNow.day + 1,
    );
    final tomorrow = await dayFor(date: tomorrowDate, settings: settings);
    return PrayerSnapshot(today: today, next: tomorrow.requiredPrayers.first);
  }

  /// Calendar arithmetic is performed in the configured zone, never by
  /// adding 24 hours (a DST calendar day may contain 23 or 25 hours).
  Future<PrayerDay> dayOffset({
    required DateTime from,
    required int days,
    required PrayerSettings settings,
  }) async {
    await initialize();
    final location = tz.getLocation(settings.timezone);
    return dayFor(
      date: tz.TZDateTime(location, from.year, from.month, from.day + days),
      settings: settings,
    );
  }

  Future<List<PrayerDay>> calendar({
    required DateTime from,
    required int days,
    required PrayerSettings settings,
  }) async {
    if (days < 1 || days > 366) throw ArgumentError.value(days, 'days');
    final result = <PrayerDay>[];
    for (var offset = 0; offset < days; offset++) {
      result.add(await dayOffset(from: from, days: offset, settings: settings));
    }
    return List.unmodifiable(result);
  }

  adhan.CalculationParameters _parameters(PrayerSettings settings) =>
      switch (settings.calculationMethod) {
        PrayerCalculationMethod.muslimWorldLeague =>
          adhan.CalculationMethodParameters.muslimWorldLeague(),
        PrayerCalculationMethod.egyptian =>
          adhan.CalculationMethodParameters.egyptian(),
        PrayerCalculationMethod.ummAlQura =>
          adhan.CalculationMethodParameters.ummAlQura(),
        PrayerCalculationMethod.karachi =>
          adhan.CalculationMethodParameters.karachi(),
        PrayerCalculationMethod.northAmerica =>
          adhan.CalculationMethodParameters.northAmerica(),
      };
}

/// Civil/tabular Islamic date using a 30-year cycle and the Friday epoch
/// (Julian day 1948439.5 = proleptic Gregorian 622-07-19). This is a local
/// calendar display, not an observational moon-sighting or Umm al-Qura date.
/// Algorithm reference: https://www.fourmilab.ch/documents/calendar/#islamic
({int year, int month, int day}) civilHijriForDate(DateTime date) {
  final a = (14 - date.month) ~/ 12;
  final y = date.year + 4800 - a;
  final m = date.month + 12 * a - 3;
  final julian =
      date.day +
      (153 * m + 2) ~/ 5 +
      365 * y +
      y ~/ 4 -
      y ~/ 100 +
      y ~/ 400 -
      32045;
  final days = julian - 1948440;
  if (days < 0)
    throw ArgumentError.value(
      date,
      'date',
      'Date precedes the Islamic civil epoch',
    );
  final year = ((30 * days + 10646) / 10631).floor();
  int firstDay(int month) =>
      (29.5 * (month - 1)).ceil() +
      354 * (year - 1) +
      ((3 + 11 * year) / 30).floor();
  var month = 1;
  while (month < 12 && firstDay(month + 1) <= days) {
    month++;
  }
  return (year: year, month: month, day: days - firstDay(month) + 1);
}
