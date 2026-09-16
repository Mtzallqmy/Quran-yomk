import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../firebase_options.dart';

/// Top-level background message handler required by Firebase Messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint("Handling background FCM message: ${message.messageId}");
}

/// Strict Route Allow-List to prevent arbitrary deep-link injection
const Set<String> _kAllowedRoutes = {
  '/',
  '/home',
  '/radio',
  '/quran',
  '/reciters',
  '/library',
  '/prayer-times',
  '/adhkar',
  '/custom-reminders',
};

String sanitizeNotificationRoute(String? route) {
  if (route == null || route.isEmpty) return '/home';
  if (_kAllowedRoutes.contains(route)) return route;
  // Specific surah pattern allowed: /quran/surah/[1-114]
  final surahRegex = RegExp(r'^\/quran\/surah\/([1-9]|[1-9][0-9]|10[0-9]|11[0-4])$');
  if (surahRegex.hasMatch(route)) return route;
  return '/home';
}

class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._internal();
  PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _currentInstallationId;

  /// Initialize Firebase & Local Notifications plugin
  Future<void> initialize({
    required Function(String route) onNavigateToRoute,
  }) async {
    // 1. Initialize Firebase Core
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 2. Set Background Handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 3. Setup Flutter Local Notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          final targetRoute = sanitizeNotificationRoute(response.payload);
          onNavigateToRoute(targetRoute);
        }
      },
    );

    // Create Android Notification Channel
    const androidChannel = AndroidNotificationChannel(
      'quran_yutla_fcm_channel',
      'إشعارات قرآن يتلى',
      description: 'إشعارات البث المباشر والتذكيرات اليومية',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // 4. Foreground Message Handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showForegroundNotification(message);
    });

    // 5. App Opened from Background Notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final route = message.data['targetRoute'] ?? message.data['route'];
      final targetRoute = sanitizeNotificationRoute(route);
      onNavigateToRoute(targetRoute);
    });

    // 6. App Launched from Terminated Notification
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final route = initialMessage.data['targetRoute'] ?? initialMessage.data['route'];
      final targetRoute = sanitizeNotificationRoute(route);
      onNavigateToRoute(targetRoute);
    }

    // 7. Token Refresh Handler (Idempotence: Updates existing installation)
    _listenToTokenRefresh();
  }

  /// In-App Consent Flow: Show custom dialog BEFORE requesting OS permissions
  Future<bool> requestConsentAndRegisterDevice(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final bool alreadyConsented = prefs.getBool('fcm_user_consent') ?? false;

    bool userApproved = alreadyConsented;

    if (!alreadyConsented) {
      userApproved = await _showInAppConsentDialog(context);
      if (userApproved) {
        await prefs.setBool('fcm_user_consent', true);
      } else {
        return false;
      }
    }

    // Request OS Permission after user consent
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await _registerOrUpdateSupabaseInstallation(fcmToken);
        return true;
      }
    }
    return false;
  }

  /// Show In-App Consent Dialog
  Future<bool> _showInAppConsentDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('تفعيل إشعارات قرآن يتلى'),
        content: const Text(
          'هل ترغب في استقبال إشعارات البث المباشر، التلاوات اليومية والتنبيهات الخاصة للتطبيق؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ليس الآن'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('موافق وتفعيل'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Show local notification when FCM push arrives in foreground
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'قرآن يتلى';
    final body = notification?.body ?? message.data['body'] ?? '';
    final route = message.data['targetRoute'] ?? message.data['route'] ?? '/home';
    final deliveryId = message.data['delivery_id'] ?? DateTime.now().millisecondsSinceEpoch.toString();

    const androidDetails = AndroidNotificationDetails(
      'quran_yutla_fcm_channel',
      'إشعارات قرآن يتلى',
      channelDescription: 'إشعارات البث المباشر والتذكيرات اليومية',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      deliveryId.hashCode,
      title,
      body,
      details,
      payload: route,
    );
  }

  /// Token Refresh Listener
  void _listenToTokenRefresh() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await _registerOrUpdateSupabaseInstallation(newToken);
    });
  }

  /// Register or update installation in Supabase (idempotent, single device record)
  Future<void> _registerOrUpdateSupabaseInstallation(String fcmToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentInstallationId ??= prefs.getString('supabase_installation_id');

      if (_currentInstallationId == null) {
        _currentInstallationId = 'inst_${DateTime.now().millisecondsSinceEpoch}_${fcmToken.substring(0, 8)}';
        await prefs.setString('supabase_installation_id', _currentInstallationId!);
      }

      final supabase = Supabase.instance.client;
      await supabase.schema('app').from('installations').upsert({
        'id': _currentInstallationId,
        'firebase_token_encrypted': fcmToken,
        'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web'),
        'app_version': '1.0.0',
        'locale': 'ar-SA',
        'timezone': DateTime.now().timeZoneName,
        'notifications_enabled': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      debugPrint('Supabase installation synced successfully: $_currentInstallationId');
    } catch (e) {
      debugPrint('Supabase installation sync notice: $e');
    }
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
  }
}
