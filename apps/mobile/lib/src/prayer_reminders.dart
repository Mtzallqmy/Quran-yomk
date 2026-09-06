import 'dart:async';

import 'package:flutter/foundation.dart';

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
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LocalNotificationService notifications;
  final PrayerTimesService prayerTimes;
  final PrayerSettingsStore settings;
  final DateTime Function() _clock;
  Timer? _dateTimer;
  Future<void>? _running;
  bool _rerun = false;
  bool _started = false;

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
    if (!current.remindersEnabled ||
        !await notifications.permissionGranted()) {
      await _cancelAll();
      return;
    }
    final now = _clock();
    final snapshot = await prayerTimes.snapshot(now: now, settings: current);
    final tomorrow = await prayerTimes.dayFor(
      date: snapshot.today.date.add(const Duration(days: 1)),
      settings: current,
    );
    for (final prayer in PrayerKind.values.where(
      (value) => value.isRequiredPrayer,
    )) {
      final todayTime = snapshot.today.timeFor(prayer);
      final scheduledAt = todayTime.isAfter(now)
          ? todayTime
          : tomorrow.timeFor(prayer);
      await notifications.reschedule(
        LocalNotificationRequest(
          id: PrayerReminderIds.forPrayer(prayer),
          title: 'ترتيل',
          body: 'حان موعد صلاة ${prayer.nameAr}',
          scheduledAt: scheduledAt,
          timezone: current.timezone,
          payload: '/prayer-times?prayer=${prayer.name}',
        ),
      );
    }
  }

  Future<void> _cancelAll() async {
    for (final id in PrayerReminderIds.all) {
      await notifications.cancel(id);
    }
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
  }
}
