import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'adaptive_adhkar_reminders.dart';
import 'learning.dart';
import 'local_notifications.dart';
import 'personal_reminders.dart';
import 'prayer_reminders.dart';
import 'prayer_settings.dart';
import 'prayer_times.dart';

const _reminderWorkUniqueName = 'tarteel-local-reminder-refill-v1';
const _reminderTaskName = 'tarteel.local.reminders.refill';

@pragma('vm:entry-point')
void tarteelReminderCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _reminderTaskName) return true;
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final preferences = await SharedPreferences.getInstance();
      final notifications = LocalNotificationService();
      final prayerSettings = PrayerSettingsStore(preferences)..load();
      final prayerTimes = PrayerTimesService();
      final prayerReminders = PrayerReminderController(
        notifications: notifications,
        prayerTimes: prayerTimes,
        settings: prayerSettings,
      );
      final learning = LearningStore(preferences)..load();
      final adhkar = AdaptiveAdhkarReminderController(
        notifications: notifications,
        store: learning,
        prayerSettings: prayerSettings,
      );
      final personalStore = PersonalReminderStore(preferences)..load();
      final personal = PersonalReminderController(
        notifications: notifications,
        store: personalStore,
        prayerSettings: prayerSettings,
      );

      await prayerReminders.reconcile();
      await adhkar.start();
      await personal.reconcile();
      return true;
    } catch (error) {
      debugPrint('BACKGROUND_REMINDER_REFILL_FAILED:$error');
      return false;
    }
  });
}

Future<void> initializeReminderBackgroundWork() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await Workmanager().initialize(tarteelReminderCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _reminderWorkUniqueName,
    _reminderTaskName,
    frequency: const Duration(hours: 12),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
}
