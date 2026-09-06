import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

@immutable
class LocalNotificationRequest {
  const LocalNotificationRequest({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.timezone,
    required this.payload,
  });

  final int id;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String timezone;
  final String payload;
}

abstract class LocalNotificationGateway {
  Future<String?> initialize(void Function(String payload) onTap);
  Future<bool> permissionGranted();
  Future<bool> requestPermission();
  Future<void> show(LocalNotificationRequest request);
  Future<void> schedule(LocalNotificationRequest request);
  Future<void> cancel(int id);
}

class FlutterLocalNotificationGateway implements LocalNotificationGateway {
  FlutterLocalNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'tarteel_prayer_reminders',
      'تذكيرات الصلاة',
      channelDescription: 'تنبيهات مواقيت الصلاة في ترتيل',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: 'tarteel_prayer_reminders',
    ),
  );

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<String?> initialize(void Function(String payload) onTap) async {
    tz_data.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_tarteel'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onTap(payload);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      return launch?.notificationResponse?.payload;
    }
    return null;
  }

  @override
  Future<bool> permissionGranted() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        true;
  }

  @override
  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          true;
    }
    return true;
  }

  @override
  Future<void> show(LocalNotificationRequest request) => _plugin.show(
    id: request.id,
    title: request.title,
    body: request.body,
    notificationDetails: _details,
    payload: request.payload,
  );

  @override
  Future<void> schedule(LocalNotificationRequest request) =>
      _plugin.zonedSchedule(
        id: request.id,
        title: request.title,
        body: request.body,
        scheduledDate: tz.TZDateTime.from(
          request.scheduledAt,
          tz.getLocation(request.timezone),
        ),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: request.payload,
      );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}

class LocalNotificationService {
  LocalNotificationService({LocalNotificationGateway? gateway})
    : _gateway = gateway ?? FlutterLocalNotificationGateway();

  final LocalNotificationGateway _gateway;
  final StreamController<String> _payloads =
      StreamController<String>.broadcast();
  Future<void>? _initialization;

  Stream<String> get payloads => _payloads.stream;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    final initialPayload = await _gateway.initialize(_payloads.add);
    if (initialPayload != null && initialPayload.isNotEmpty) {
      _payloads.add(initialPayload);
    }
  }

  Future<bool> permissionGranted() async {
    await initialize();
    return _gateway.permissionGranted();
  }

  Future<bool> requestPermission() async {
    await initialize();
    return _gateway.requestPermission();
  }

  Future<void> show(LocalNotificationRequest request) async {
    await initialize();
    await _gateway.show(request);
  }

  Future<void> schedule(LocalNotificationRequest request) async {
    await initialize();
    await _gateway.cancel(request.id);
    await _gateway.schedule(request);
  }

  Future<void> reschedule(LocalNotificationRequest request) =>
      schedule(request);

  Future<void> cancel(int id) async {
    await initialize();
    await _gateway.cancel(id);
  }

  Future<void> dispose() => _payloads.close();
}
