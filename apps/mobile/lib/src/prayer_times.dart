import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tz_data;
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

  List<PrayerOccurrence> get ordered => PrayerKind.values
      .map((prayer) => PrayerOccurrence(prayer: prayer, time: timeFor(prayer)))
      .toList(growable: false);

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
    final localDate = tz.TZDateTime(
      location,
      date.year,
      date.month,
      date.day,
    );
    final parameters = _parameters(settings)
      ..madhab = settings.asrMethod == PrayerAsrMethod.hanafi
          ? adhan.Madhab.hanafi
          : adhan.Madhab.shafi;
    final calculated = adhan.PrayerTimes(
      coordinates: adhan.Coordinates(settings.latitude, settings.longitude),
      date: localDate,
      calculationParameters: parameters,
    );
    DateTime local(DateTime value, PrayerKind prayer) => tz.TZDateTime.from(
      value,
      location,
    ).add(Duration(minutes: settings.offsetFor(prayer)));
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
    final tomorrowDate = localNow.add(const Duration(days: 1));
    final tomorrow = await dayFor(date: tomorrowDate, settings: settings);
    return PrayerSnapshot(today: today, next: tomorrow.requiredPrayers.first);
  }

  adhan.CalculationParameters _parameters(PrayerSettings settings) =>
      switch (settings.calculationMethod) {
        PrayerCalculationMethod.muslimWorldLeague =>
          adhan.CalculationMethodParameters.muslimWorldLeague(),
        PrayerCalculationMethod.egyptian =>
          adhan.CalculationMethodParameters.egyptian(),
        PrayerCalculationMethod.ummAlQura =>
          adhan.CalculationMethodParameters.ummAlQura(),
      };
}
