import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'prayer_settings.dart';

@immutable
class NativePrayerAlarmStatus {
  const NativePrayerAlarmStatus({
    required this.available,
    required this.configured,
    required this.exact,
    required this.scheduled,
  });

  final bool available;
  final bool configured;
  final bool exact;
  final int scheduled;
}

class NativePrayerAlarmBridge {
  const NativePrayerAlarmBridge();

  static const MethodChannel _channel = MethodChannel(
    'app.tarteel.tarteel/prayer-alarm',
  );

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> configure(PrayerSettings settings) async {
    if (!supported) return false;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'configure',
        <String, dynamic>{
          'locationName': settings.locationName,
          'latitude': settings.latitude,
          'longitude': settings.longitude,
          'timezone': settings.timezone,
          'method': settings.calculationMethod.name,
          'madhab': settings.asrMethod.name,
          'offsets': <String, int>{
            for (final prayer in PrayerKind.values)
              prayer.name: settings.offsetFor(prayer),
          },
          'manualTimes': <String, int>{
            for (final entry in settings.manualTimes.entries)
              entry.key.name: entry.value,
          },
          'modes': <String, String>{
            for (final prayer in PrayerKind.values.where(
              (value) => value.isRequiredPrayer,
            ))
              prayer.name: settings.reminderModeFor(prayer).name,
          },
        },
      );
      return result != null;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('NATIVE_PRAYER_ALARM_CONFIGURE_FAILED:${error.code}');
      return false;
    }
  }

  Future<void> disable() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<bool>('disable');
    } on MissingPluginException {
      return;
    } on PlatformException catch (error) {
      debugPrint('NATIVE_PRAYER_ALARM_DISABLE_FAILED:${error.code}');
    }
  }

  Future<NativePrayerAlarmStatus> status() async {
    if (!supported) {
      return const NativePrayerAlarmStatus(
        available: false,
        configured: false,
        exact: false,
        scheduled: 0,
      );
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('status');
      if (result == null) throw const MissingPluginException();
      return NativePrayerAlarmStatus(
        available: true,
        configured: result['configured'] == true,
        exact: result['exact'] == true,
        scheduled: (result['scheduled'] as num?)?.toInt() ?? 0,
      );
    } on MissingPluginException {
      return const NativePrayerAlarmStatus(
        available: false,
        configured: false,
        exact: false,
        scheduled: 0,
      );
    } on PlatformException {
      return const NativePrayerAlarmStatus(
        available: false,
        configured: false,
        exact: false,
        scheduled: 0,
      );
    }
  }

  Future<bool> scheduleTest({required bool playAdhan}) async {
    if (!supported) return false;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'test',
        <String, dynamic>{'playAdhan': playAdhan},
      );
      return result?['scheduled'] == true;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('NATIVE_PRAYER_ALARM_TEST_FAILED:${error.code}');
      return false;
    }
  }
}
