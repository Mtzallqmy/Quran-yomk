import 'package:timezone/timezone.dart' as tz;

import 'learning.dart';
import 'local_notifications.dart';
import 'prayer_settings.dart';

class AdaptiveAdhkarReminderController extends AdhkarReminderController {
  AdaptiveAdhkarReminderController({
    required super.notifications,
    required super.store,
    required this.prayerSettings,
  });

  final PrayerSettingsStore prayerSettings;

  @override
  Future<bool> schedule(
    String category, {
    required int hour,
    required int minute,
    AdhkarReminderMode? mode,
    bool requestPermission = false,
    DateTime? now,
  }) async {
    final id = AdhkarReminderController.ids[category];
    if (id == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return false;
    }
    final permitted = requestPermission
        ? await notifications.requestPermission()
        : await notifications.permissionGranted();
    if (!permitted) return false;

    final timezone = prayerSettings.value.timezone;
    final location = tz.getLocation(timezone);
    final current = tz.TZDateTime.from(now ?? DateTime.now(), location);
    var target = tz.TZDateTime(
      location,
      current.year,
      current.month,
      current.day,
      hour,
      minute,
    );
    if (!target.isAfter(current)) target = target.add(const Duration(days: 1));

    await notifications.schedule(
      LocalNotificationRequest(
        id: id,
        title: 'أذكار ترتيل',
        body: category == 'morning'
            ? 'حان وقت أذكار الصباح'
            : category == 'evening'
                ? 'حان وقت أذكار المساء'
                : 'لا تنس أذكار النوم',
        scheduledAt: target,
        timezone: timezone,
        payload: '/adhkar',
        channel: LocalNotificationChannel.prayerReminder,
        playSound:
            (mode ?? store.reminderMode(category)) == AdhkarReminderMode.tone,
        preferExact: false,
        repeatDaily: true,
      ),
    );
    await store.setReminderMinutes(category, hour * 60 + minute);
    return true;
  }
}
