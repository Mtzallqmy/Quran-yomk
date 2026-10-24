import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:timezone/timezone.dart' as tz;

import 'adhan_audio.dart';
import 'local_notifications.dart';
import 'prayer_settings.dart';
import 'prayer_times.dart';

abstract final class PrayerReminderIds {
  static const int fajr = 4101;
  static const int dhuhr = 4102;
  static const int asr = 4103;
  static const int maghrib = 4104;
  static const int isha = 4105;

  static const List<int> all = <int>[fajr, dhuhr, asr, maghrib, isha];

  /// Android notification IDs for a prayer on a particular local calendar
  /// day. They stay below the signed 32-bit limit and are deterministic, so
  /// changing location/method can replace the same pending alarm cleanly.
  static int forPrayerOnDate(PrayerKind prayer, DateTime date) {
    final prayerIndex = switch (prayer) {
      PrayerKind.fajr => 0,
      PrayerKind.dhuhr => 1,
      PrayerKind.asr => 2,
      PrayerKind.maghrib => 3,
      PrayerKind.isha => 4,
      PrayerKind.sunrise => throw ArgumentError.value(
        prayer,
        'prayer',
        'Sunrise is not a prayer reminder',
      ),
    };
    final dayOfYear = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(date.year)).inDays;
    return 4_200_000 +
        (prayerIndex * 40_000) +
        ((date.year % 100) * 366) +
        dayOfYear;
  }

  static int before(PrayerKind prayer, DateTime date) =>
      forPrayerOnDate(prayer, date) + 300_000;
  static int after(PrayerKind prayer, DateTime date) =>
      forPrayerOnDate(prayer, date) + 600_000;

  static int forPrayer(PrayerKind prayer) => switch (prayer) {
    PrayerKind.fajr => fajr,
    PrayerKind.dhuhr => dhuhr,
    PrayerKind.asr => asr,
    PrayerKind.maghrib => maghrib,
    PrayerKind.isha => isha,
    PrayerKind.sunrise => throw ArgumentError.value(
      prayer,
      'prayer',
      'Sunrise is not a prayer reminder',
    ),
  };
}

class PrayerReminderController {
  PrayerReminderController({
    required this.notifications,
    required this.prayerTimes,
    required this.settings,
    this.adhanAudio,
    DateTime Function()? clock,
    bool Function()? isForeground,
  }) : _clock = clock ?? DateTime.now,
       _isForeground =
           isForeground ??
           (() =>
               SchedulerBinding.instance.lifecycleState ==
               AppLifecycleState.resumed);

  final LocalNotificationService notifications;
  final PrayerTimesService prayerTimes;
  final PrayerSettingsStore settings;
  final AdhanAudioService? adhanAudio;
  final DateTime Function() _clock;
  final bool Function() _isForeground;
  Timer? _dateTimer;
  Timer? _adhanTimer;
  Future<void>? _running;
  bool _rerun = false;
  bool _started = false;

  /// Default window: 225 prayers. With all before/after reminders enabled,
  /// use a 28 day window to stay below Samsung's 500 pending-alarm limit.
  static const scheduleDays = 45;
  static const extendedScheduleDays = 28;

  Future<void> start() async {
    if (_started) return;
    await Future.wait<void>(<Future<void>>[
      notifications.initialize(),
      prayerTimes.initialize(),
    ]);
    _started = true;
    settings.addListener(_settingsChanged);
    _dateTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _scheduleSafely(),
    );
    await reconcile();
  }

  Future<bool> setEnabled(bool enabled) async {
    try {
      await notifications.initialize();
      if (enabled && !await notifications.requestPermission()) {
        await settings.setRemindersEnabled(false);
        await reconcile();
        return false;
      }
      await settings.setRemindersEnabled(enabled);
      await reconcile();
      return true;
    } catch (_) {
      debugPrint('PRAYER_REMINDER_PERMISSION_FAILED');
      await settings.setRemindersEnabled(false);
      return false;
    }
  }

  Future<bool> setPrayerMode(PrayerKind prayer, PrayerReminderMode mode) async {
    if (!prayer.isRequiredPrayer) return false;
    try {
      await notifications.initialize();
      if (mode != PrayerReminderMode.disabled &&
          !await notifications.requestPermission()) {
        await settings.setReminderMode(prayer, PrayerReminderMode.disabled);
        await reconcile();
        return false;
      }
      if (mode == PrayerReminderMode.adhan &&
          notifications.nativeAudioAlarms &&
          !await notifications.exactSchedulingAvailable() &&
          !await notifications.requestExactSchedulingPermission()) {
        return false;
      }
      await settings.setReminderMode(prayer, mode);
      await reconcile();
      return true;
    } catch (_) {
      debugPrint('PRAYER_REMINDER_PERMISSION_FAILED');
      await settings.setReminderMode(prayer, PrayerReminderMode.disabled);
      return false;
    }
  }

  Future<void> reconcile() {
    _rerun = true;
    return _running ??= _drainReconciliations();
  }

  Future<void> _drainReconciliations() async {
    try {
      while (_rerun) {
        _rerun = false;
        await _reconcileOnce();
      }
    } finally {
      _running = null;
    }
  }

  Future<void> _reconcileOnce() async {
    final current = settings.value;
    if (!current.remindersEnabled || !await notifications.permissionGranted()) {
      await _cancelAll();
      _adhanTimer?.cancel();
      return;
    }
    final now = _clock();
    final snapshot = await prayerTimes.snapshot(now: now, settings: current);
    await _cancelManagedWindow(now);
    final adhanSchedules = <({PrayerKind prayer, DateTime time, int id})>[];
    final extraCount = PrayerKind.values
        .where((p) => p.isRequiredPrayer)
        .fold<int>(
          0,
          (count, p) =>
              count +
              (current.beforeMinutesFor(p) > 0 ? 1 : 0) +
              (current.afterMinutesFor(p) > 0 ? 1 : 0),
        );
    final days = extraCount == 0 ? scheduleDays : extendedScheduleDays;
    final scheduledCounts = <PrayerKind, int>{};
    for (var dayOffset = 0; dayOffset <= days; dayOffset++) {
      final day = dayOffset == 0
          ? snapshot.today
          : await prayerTimes.dayOffset(
              from: snapshot.today.date,
              days: dayOffset,
              settings: current,
            );
      for (final prayer in PrayerKind.values.where(
        (value) => value.isRequiredPrayer,
      )) {
        final mode = current.reminderModeFor(prayer);
        if (mode == PrayerReminderMode.disabled ||
            (scheduledCounts[prayer] ?? 0) >= days)
          continue;
        final scheduledAt = day.timeFor(prayer);
        final audioMode =
            mode == PrayerReminderMode.adhan ||
            mode == PrayerReminderMode.shortAlert;
        for (final before in [true, false]) {
          final minutes = before
              ? current.beforeMinutesFor(prayer)
              : current.afterMinutesFor(prayer);
          if (minutes == 0) continue;
          final reminderTime = scheduledAt.add(
            Duration(minutes: before ? -minutes : minutes),
          );
          if (!reminderTime.isAfter(now)) continue;
          await notifications.reschedule(
            LocalNotificationRequest(
              id: before
                  ? PrayerReminderIds.before(prayer, day.date)
                  : PrayerReminderIds.after(prayer, day.date),
              title: 'ترتيل',
              body: before
                  ? 'بقي $minutes دقيقة على صلاة ${prayer.nameAr}'
                  : 'أذكار ما بعد صلاة ${prayer.nameAr}: سبحان الله، والحمد لله، والله أكبر',
              scheduledAt: reminderTime,
              timezone: current.timezone,
              payload: '/prayer-times?prayer=${prayer.name}',
              playSound: mode != PrayerReminderMode.silent,
            ),
          );
        }
        if (!scheduledAt.isAfter(now)) continue;
        scheduledCounts[prayer] = (scheduledCounts[prayer] ?? 0) + 1;
        await notifications.reschedule(
          LocalNotificationRequest(
            id: PrayerReminderIds.forPrayerOnDate(prayer, day.date),
            title: 'ترتيل',
            body: mode == PrayerReminderMode.adhan
                ? 'حان موعد أذان صلاة ${prayer.nameAr}'
                : 'حان موعد صلاة ${prayer.nameAr}',
            scheduledAt: scheduledAt,
            timezone: current.timezone,
            payload: '/prayer-times?prayer=${prayer.name}',
            channel: audioMode
                ? LocalNotificationChannel.adhan
                : LocalNotificationChannel.prayerReminder,
            playSound: mode != PrayerReminderMode.silent,
            audioPath: audioMode
                ? current.audioPathFor(
                    prayer,
                    fallback: mode == PrayerReminderMode.shortAlert
                        ? 'assets/audio/reminder.wav'
                        : adhanAudio?.assetPath,
                  )
                : null,
            volume: current.volumeFor(prayer),
          ),
        );
        if (audioMode) {
          adhanSchedules.add((
            prayer: prayer,
            time: scheduledAt,
            id: PrayerReminderIds.forPrayerOnDate(prayer, day.date),
          ));
        }
      }
    }
    _scheduleForegroundAdhan(adhanSchedules, current);
  }

  void _scheduleForegroundAdhan(
    List<({PrayerKind prayer, DateTime time, int id})> schedules,
    PrayerSettings current,
  ) {
    _adhanTimer?.cancel();
    if (notifications.nativeAudioAlarms ||
        adhanAudio == null ||
        schedules.isEmpty)
      return;
    schedules.sort((left, right) => left.time.compareTo(right.time));
    final next = schedules.first;
    final delay = next.time.difference(_clock());
    if (delay <= Duration.zero) return;
    _adhanTimer = Timer(delay, () async {
      if (!_isForeground()) return;
      final id = PrayerReminderIds.forPrayer(next.prayer);
      try {
        await notifications.cancel(next.id);
        await notifications.show(
          LocalNotificationRequest(
            id: id,
            title: 'ترتيل',
            body: 'حان موعد أذان صلاة ${next.prayer.nameAr}',
            scheduledAt: next.time,
            timezone: current.timezone,
            payload: '/prayer-times?prayer=${next.prayer.name}',
            playSound: false,
            preferExact: false,
          ),
        );
        final mode = current.reminderModeFor(next.prayer);
        await adhanAudio!.play(
          path: current.audioPathFor(
            next.prayer,
            fallback: mode == PrayerReminderMode.shortAlert
                ? 'assets/audio/reminder.wav'
                : adhanAudio!.assetPath,
          ),
        );
      } catch (_) {
        debugPrint('FOREGROUND_ADHAN_FAILED');
      } finally {
        _scheduleSafely();
      }
    });
  }

  Future<void> _cancelAll() async {
    for (final id in PrayerReminderIds.all) {
      await notifications.cancel(id);
    }
    await _cancelManagedWindow(_clock());
  }

  Future<void> _cancelManagedWindow(DateTime now) async {
    // Include yesterday to clear stale alarms after timezone/location edits.
    for (var offset = -1; offset <= scheduleDays; offset++) {
      final location = tz.getLocation(settings.value.timezone);
      final localNow = tz.TZDateTime.from(now, location);
      final date = tz.TZDateTime(
        location,
        localNow.year,
        localNow.month,
        localNow.day + offset,
      );
      for (final prayer in PrayerKind.values.where(
        (value) => value.isRequiredPrayer,
      )) {
        await notifications.cancel(
          PrayerReminderIds.forPrayerOnDate(prayer, date),
        );
        await notifications.cancel(PrayerReminderIds.before(prayer, date));
        await notifications.cancel(PrayerReminderIds.after(prayer, date));
      }
    }
  }

  Future<void> suspend() async {
    _adhanTimer?.cancel();
    await _cancelAll();
  }

  void _settingsChanged() => _scheduleSafely();

  void _scheduleSafely() {
    unawaited(
      reconcile().catchError((Object error) {
        debugPrint('PRAYER_REMINDER_SCHEDULE_FAILED');
      }),
    );
  }

  void dispose() {
    if (_started) settings.removeListener(_settingsChanged);
    _dateTimer?.cancel();
    _adhanTimer?.cancel();
  }
}
