import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  static const MethodChannel _adhanChannel = MethodChannel(
    'app.tarteel.tarteel/adhan',
  );

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

    final native = await _nativeTimes(localDate, settings);
    if (native != null) {
      DateTime nativeTime(PrayerKind prayer) {
        final manual = settings.manualTimes[prayer];
        if (manual != null && manual >= 0 && manual < 1440) {
          return tz.TZDateTime(
            location,
            localDate.year,
            localDate.month,
            localDate.day,
            manual ~/ 60,
            manual % 60,
          );
        }
        return tz.TZDateTime.from(native[prayer]!, location);
      }

      return PrayerDay(
        date: localDate,
        timezone: location.name,
        times: Map<PrayerKind, DateTime>.unmodifiable({
          for (final prayer in PrayerKind.values) prayer: nativeTime(prayer),
        }),
      );
    }

    // Cross-platform and test fallback. Android production uses the MIT
    // Adhan Kotlin engine through the platform channel above.
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

  Future<double> qiblaDirection(PrayerSettings settings) async {
    try {
      final value = await _adhanChannel.invokeMethod<num>('qiblaDirection', {
        'latitude': settings.latitude,
        'longitude': settings.longitude,
      });
      if (value != null) return value.toDouble();
    } on MissingPluginException {
      // Unit tests / non-Android targets use the Dart MIT fallback below.
    } on PlatformException {
      // Preserve functionality if the native engine cannot initialize.
    }
    return adhan.Qibla.qibla(
      adhan.Coordinates(settings.latitude, settings.longitude),
    );
  }

  Future<Map<PrayerKind, DateTime>?> _nativeTimes(
    DateTime date,
    PrayerSettings settings,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final raw = await _adhanChannel.invokeMapMethod<String, dynamic>(
        'calculatePrayerTimes',
        <String, dynamic>{
          'latitude': settings.latitude,
          'longitude': settings.longitude,
          'year': date.year,
          'month': date.month,
          'day': date.day,
          'method': settings.calculationMethod.name,
          'madhab': settings.asrMethod.name,
          'adjustments': <String, int>{
            for (final prayer in PrayerKind.values)
              prayer.name: settings.offsetFor(prayer),
          },
        },
      );
      if (raw == null) return null;
      final result = <PrayerKind, DateTime>{};
      for (final prayer in PrayerKind.values) {
        final millis = raw[prayer.name];
        if (millis is! num) return null;
        result[prayer] = DateTime.fromMillisecondsSinceEpoch(
          millis.toInt(),
          isUtc: true,
        );
      }
      return result;
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('ADHAN_KOTLIN_FALLBACK:${error.code}');
      return null;
    }
  }

  adhan.CalculationParameters _parameters(PrayerSettings settings) =>
      switch (settings.calculationMethod) {
        PrayerCalculationMethod.muslimWorldLeague =>
          adhan.CalculationMethodParameters.muslimWorldLeague(),
        PrayerCalculationMethod.egyptian =>
          adhan.CalculationMethodParameters.egyptian(),
        PrayerCalculationMethod.karachi =>
          adhan.CalculationMethodParameters.karachi(),
        PrayerCalculationMethod.ummAlQura =>
          adhan.CalculationMethodParameters.ummAlQura(),
        PrayerCalculationMethod.dubai =>
          adhan.CalculationMethodParameters.dubai(),
        PrayerCalculationMethod.qatar =>
          adhan.CalculationMethodParameters.qatar(),
        PrayerCalculationMethod.kuwait =>
          adhan.CalculationMethodParameters.kuwait(),
        PrayerCalculationMethod.moonSightingCommittee =>
          adhan.CalculationMethodParameters.moonsightingCommittee(),
        PrayerCalculationMethod.singapore =>
          adhan.CalculationMethodParameters.singapore(),
        PrayerCalculationMethod.northAmerica =>
          adhan.CalculationMethodParameters.northAmerica(),
        PrayerCalculationMethod.turkey =>
          adhan.CalculationMethodParameters.turkiye(),
      };
}
