import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'adhan_audio.dart';
import 'local_notifications.dart';
import 'native_prayer_alarm.dart';
import 'prayer_settings.dart';
import 'prayer_times.dart';

abstract final class PrayerReminderIds {
  static const int fajr = 4101;
  static const int dhuhr = 4102;
  static const int asr = 4103;
  static const int maghrib = 4104;
  static const int isha = 4105;

  static const List<int> all = <int>[fajr, dhuhr, asr, maghrib, isha];

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
    final dayOfYear = date.difference(DateTime(date.year)).inDays;
    return 4_200_000 +
        (prayerIndex * 40_000) +
        ((date.year % 100) * 366) +
        dayOfYear;
  }

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
    NativePrayerAlarmBridge? nativeAlarm,
    DateTime Function()? clock,
    bool Function()? isForeground,
  })  : nativeAlarm = nativeAlarm ?? const NativePrayerAlarmBridge(),
        _clock = clock ?? DateTime.now,
        _isForeground =
            isForeground ??
                (() =>
                    SchedulerBinding.instance.lifecycleState ==
                    AppLifecycleState.resumed);

  final LocalNotificationService notifications;
  final PrayerTimesService prayerTimes;
  final PrayerSettingsStore settings;
  final AdhanAudioService? adhanAudio;
  final NativePrayerAlarmBridge nativeAlarm;
  final DateTime Function() _clock;
  final bool Function() _isForeground;
  Timer? _dateTimer;
  Timer? _adhanTimer;
  Future<void>? _running;
  bool _rerun = false;
  bool _started = false;

  /// Non-Android fallback window. Android uses a native self-refreshing alarm
  /// engine that survives app process death and reboots.
  static const scheduleDays = 45;

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
      await settings.setReminderMode(prayer, mode);
      await reconcile();
      return true;
    } catch (_) {
      debugPrint('PRAYER_REMINDER_PERMISSION_FAILED');
      await settings.setReminderMode(prayer, PrayerReminderMode.disabled);
      return false;
    }
  }

  Future<NativePrayerAlarmStatus> nativeStatus() => nativeAlarm.status();

  Future<bool> scheduleAlarmTest({required bool playAdhan}) =>
      nativeAlarm.scheduleTest(playAdhan: playAdhan);

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
      await nativeAlarm.disable();
      await _cancelFlutterManaged();
      _adhanTimer?.cancel();
      return;
    }

    // Android uses AlarmManager + a native foreground media service for the
    // adhan. This path continues to work when Flutter is killed and is restored
    // after reboot/time changes. Tests and other platforms fall back below.
    if (await nativeAlarm.configure(current)) {
      await _cancelFlutterManaged();
      _adhanTimer?.cancel();
      return;
    }

    final now = _clock();
    final snapshot = await prayerTimes.snapshot(now: now, settings: current);
    await _cancelManagedWindow(now);
    final adhanSchedules = <({PrayerKind prayer, DateTime time})>[];
    for (var dayOffset = 0; dayOffset < scheduleDays; dayOffset++) {
      final day = dayOffset == 0
          ? snapshot.today
          : await prayerTimes.dayFor(
              date: snapshot.today.date.add(Duration(days: dayOffset)),
              settings: current,
            );
      for (final prayer in PrayerKind.values.where(
        (value) => value.isRequiredPrayer,
      )) {
        final mode = current.reminderModeFor(prayer);
        if (mode == PrayerReminderMode.disabled) continue;
        final scheduledAt = day.timeFor(prayer);
        if (!scheduledAt.isAfter(now)) continue;
        await notifications.reschedule(
          LocalNotificationRequest(
            id: PrayerReminderIds.forPrayerOnDate(prayer, scheduledAt),
            title: 'ترتيل',
            body: mode == PrayerReminderMode.adhan
                ? 'حان موعد أذان صلاة ${prayer.nameAr}'
                : 'حان موعد صلاة ${prayer.nameAr}',
            scheduledAt: scheduledAt,
            timezone: current.timezone,
            payload: '/prayer-times?prayer=${prayer.name}',
            channel: mode == PrayerReminderMode.adhan
                ? LocalNotificationChannel.adhan
                : LocalNotificationChannel.prayerReminder,
            playSound: mode != PrayerReminderMode.silent,
          ),
        );
        if (mode == PrayerReminderMode.adhan) {
          adhanSchedules.add((prayer: prayer, time: scheduledAt));
        }
      }
    }
    _scheduleForegroundAdhan(adhanSchedules, current);
  }

  void _scheduleForegroundAdhan(
    List<({PrayerKind prayer, DateTime time})> schedules,
    PrayerSettings current,
  ) {
    _adhanTimer?.cancel();
    if (adhanAudio == null || schedules.isEmpty) return;
    schedules.sort((left, right) => left.time.compareTo(right.time));
    final next = schedules.first;
    final delay = next.time.difference(_clock());
    if (delay <= Duration.zero) return;
    _adhanTimer = Timer(delay, () async {
      if (!_isForeground()) return;
      final id = PrayerReminderIds.forPrayer(next.prayer);
      try {
        await notifications.cancel(id);
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
        await adhanAudio!.play();
      } catch (_) {
        debugPrint('FOREGROUND_ADHAN_FAILED');
      } finally {
        _scheduleSafely();
      }
    });
  }

  Future<void> _cancelFlutterManaged() async {
    for (final id in PrayerReminderIds.all) {
      await notifications.cancel(id);
    }
    await _cancelManagedWindow(_clock());
  }

  Future<void> _cancelManagedWindow(DateTime now) async {
    for (var offset = -1; offset <= scheduleDays; offset++) {
      final date = now.add(Duration(days: offset));
      for (final prayer in PrayerKind.values.where(
        (value) => value.isRequiredPrayer,
      )) {
        await notifications.cancel(
          PrayerReminderIds.forPrayerOnDate(prayer, date),
        );
      }
    }
  }

  Future<void> suspend() async {
    _adhanTimer?.cancel();
    await nativeAlarm.disable();
    await _cancelFlutterManaged();
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
