import 'package:shared_preferences/shared_preferences.dart';

import 'local_notifications.dart';
import 'push_notifications.dart';

class TarteelPushNotificationService extends PushNotificationService {
  TarteelPushNotificationService({
    required SharedPreferences preferences,
    required LocalNotificationService localNotifications,
    required this.onLocalConsentGranted,
  }) : _localNotifications = localNotifications,
       super(
         preferences: preferences,
         localNotifications: localNotifications,
       );

  final LocalNotificationService _localNotifications;
  final Future<void> Function() onLocalConsentGranted;

  @override
  Future<bool> setEnabled(bool value) async {
    if (!value) {
      // Remote/admin push can be disabled without touching local prayer,
      // adhkar or personal reminders.
      return super.setEnabled(false);
    }

    var localAccepted = false;
    try {
      localAccepted = await _localNotifications.requestPermission();
      if (localAccepted) await onLocalConsentGranted();
    } catch (_) {
      localAccepted = false;
    }

    final remoteAccepted = await super.setEnabled(true);
    // The user's local alarm/reminder consent must remain useful even when
    // Firebase or the backend is temporarily unavailable.
    return localAccepted || remoteAccepted;
  }
}
