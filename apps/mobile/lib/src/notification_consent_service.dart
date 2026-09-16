import 'package:shared_preferences/shared_preferences.dart';

import 'local_notifications.dart';
import 'push_notifications.dart';

class TarteelPushNotificationService extends PushNotificationService {
  TarteelPushNotificationService({
    required SharedPreferences preferences,
    required LocalNotificationService localNotifications,
    required this.onLocalConsentGranted,
  }) : super(
          preferences: preferences,
          localNotifications: localNotifications,
        );

  final Future<void> Function() onLocalConsentGranted;

  @override
  Future<bool> setEnabled(bool value) async {
    final accepted = await super.setEnabled(value);
    if (accepted && value) {
      await onLocalConsentGranted();
    }
    return accepted;
  }
}
