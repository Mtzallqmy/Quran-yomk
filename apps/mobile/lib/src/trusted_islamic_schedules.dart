import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_notifications.dart';
import 'prayer_settings.dart';
import 'prayer_times.dart';
import 'trusted_islamic_library.dart';

class TrustedIslamicScheduleController extends ChangeNotifier {
  TrustedIslamicScheduleController({
    required this.preferences,
    required this.library,
    required this.notifications,
    required this.prayerTimes,
    required this.prayerSettings,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const int scheduleDays = 21;
  static const String _enabledPrefix = 'trusted:islamic:schedule:enabled:';

  final SharedPreferences preferences;
  final TrustedIslamicLibraryRepository library;
  final LocalNotificationService notifications;
  final PrayerTimesService prayerTimes;
  final PrayerSettingsStore prayerSettings;
  final DateTime Function() _clock;

  bool _started = false;
  bool _reconciling = false;
  bool _rerun = false;
  int _scheduledCount = 0;
  String? _lastError;

  bool get reconciling => _reconciling;
  int get scheduledCount => _scheduledCount;
  String? get lastError => _lastError;

  bool enabledFor(TrustedIslamicScheduleTemplate template) =>
      preferences.getBool('$_enabledPrefix${template.slug}') ??
      template.defaultEnabled;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    prayerSettings.addListener(_settingsChanged);
    await notifications.initialize();
    await prayerTimes.initialize();
    await reconcile();
  }

  Future<bool> setEnabled(
    TrustedIslamicScheduleTemplate template,
    bool enabled,
  ) async {
    if (enabled && !await notifications.requestPermission()) return false;
    await preferences.setBool('$_enabledPrefix${template.slug}', enabled);
    await reconcile();
    notifyListeners();
    return true;
  }

  Future<void> reconcile() async {
    _rerun = true;
    if (_reconciling) return;
    _reconciling = true;
    notifyListeners();
    try {
      while (_rerun) {
        _rerun = false;
        await _reconcileOnce();
      }
    } finally {
      _reconciling = false;
      notifyListeners();
    }
  }

  Future<void> _reconcileOnce() async {
    final templates = await library.schedules();
    await _cancelWindow(templates);
    _scheduledCount = 0;
    _lastError = null;
    if (!await notifications.permissionGranted()) return;

    final now = _clock();
    final settings = prayerSettings.value;
    for (final template in templates) {
      if (!enabledFor(template)) continue;
      for (var offset = 0; offset < scheduleDays; offset++) {
        final date = DateTime(now.year, now.month, now.day).add(
          Duration(days: offset),
        );
        try {
          final trigger = await _triggerFor(template, date, settings);
          if (trigger == null || !trigger.isAfter(now.add(const Duration(seconds: 5)))) {
            continue;
          }
          await notifications.reschedule(
            LocalNotificationRequest(
              id: _notificationId(template.slug, trigger),
              title: 'ترتيل',
              body: template.titleAr,
              scheduledAt: trigger,
              timezone: settings.timezone,
              payload: '/library',
              channel: LocalNotificationChannel.prayerReminder,
              playSound: true,
              preferExact: true,
            ),
          );
          _scheduledCount++;
        } catch (error) {
          _lastError = 'SCHEDULE_${template.slug}_${error.runtimeType}';
          debugPrint('TRUSTED_ISLAMIC_SCHEDULE_FAILED:${template.slug}:${error.runtimeType}');
        }
      }
    }
  }

  Future<DateTime?> _triggerFor(
    TrustedIslamicScheduleTemplate template,
    DateTime date,
    PrayerSettings settings,
  ) async {
    switch (template.triggerKind) {
      case 'fixed_local_time':
        final raw = template.fixedLocalTime;
        if (raw == null) return null;
        final match = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?').firstMatch(raw);
        if (match == null) return null;
        final hour = int.tryParse(match.group(1) ?? '');
        final minute = int.tryParse(match.group(2) ?? '');
        final second = int.tryParse(match.group(3) ?? '0') ?? 0;
        if (hour == null || minute == null || hour > 23 || minute > 59 || second > 59) {
          return null;
        }
        final day = await prayerTimes.dayFor(date: date, settings: settings);
        final localDate = day.date;
        return DateTime(
          localDate.year,
          localDate.month,
          localDate.day,
          hour,
          minute,
          second,
        ).add(Duration(minutes: template.offsetMinutes));
      case 'sunrise_relative':
        final day = await prayerTimes.dayFor(date: date, settings: settings);
        return day
            .timeFor(PrayerKind.sunrise)
            .add(Duration(minutes: template.offsetMinutes));
      case 'sunset_relative':
        final day = await prayerTimes.dayFor(date: date, settings: settings);
        return day
            .timeFor(PrayerKind.maghrib)
            .add(Duration(minutes: template.offsetMinutes));
      case 'prayer_relative':
        final prayer = _prayerFromName(template.prayer);
        if (prayer == null) return null;
        final day = await prayerTimes.dayFor(date: date, settings: settings);
        return day.timeFor(prayer).add(Duration(minutes: template.offsetMinutes));
      default:
        return null;
    }
  }

  PrayerKind? _prayerFromName(String? value) {
    for (final prayer in PrayerKind.values) {
      if (prayer.name == value) return prayer;
    }
    return null;
  }

  Future<void> _cancelWindow(List<TrustedIslamicScheduleTemplate> templates) async {
    final now = _clock();
    for (final template in templates) {
      for (var offset = -1; offset <= scheduleDays + 1; offset++) {
        final date = DateTime(now.year, now.month, now.day).add(
          Duration(days: offset),
        );
        await notifications.cancel(_notificationId(template.slug, date));
      }
    }
  }

  int _notificationId(String slug, DateTime date) {
    var hash = 0x811c9dc5;
    final value = '$slug:${date.year}-${date.month}-${date.day}';
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return 5_000_000 + (hash % 1_000_000_000);
  }

  void _settingsChanged() => unawaited(reconcile());

  Future<void> suspend() async {
    final templates = await library.schedules();
    await _cancelWindow(templates);
    _scheduledCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_started) prayerSettings.removeListener(_settingsChanged);
    super.dispose();
  }
}
