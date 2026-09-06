import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_notifications.dart';

const _backend =
    'https://qkroecnecdxghcqvvoxn.supabase.co/functions/v1/notifications';
const _publishableKey = 'sb_publishable_dLYCid35ZkeIE95xqiyHoQ_bEhWWISK';
const safePushRoutes = <String>{
  '/home',
  '/prayer-times',
  '/adhkar',
  '/radio',
  '/reciters',
  '/quran',
  '/library',
  '/custom-reminders',
};

@pragma('vm:entry-point')
Future<void> tarteelFirebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Android still displays the provider notification. Never crash a worker.
  }
}

class PushMessage {
  const PushMessage({required this.data, this.title, this.body});
  final Map<String, dynamic> data;
  final String? title;
  final String? body;
}

abstract class PushGateway {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<bool> permissionGranted();
  Future<String?> token();
  Stream<String> get tokenRefresh;
  Stream<PushMessage> get foregroundMessages;
  Stream<PushMessage> get openedMessages;
  Future<PushMessage?> initialMessage();
}

class FirebasePushGateway implements PushGateway {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  PushMessage _convert(RemoteMessage message) => PushMessage(
    data: Map<String, dynamic>.from(message.data),
    title: message.notification?.title,
    body: message.notification?.body,
  );

  @override
  Future<void> initialize() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(tarteelFirebaseBackgroundHandler);
  }

  @override
  Future<bool> requestPermission() async =>
      (await _messaging.requestPermission()).authorizationStatus ==
      AuthorizationStatus.authorized;

  @override
  Future<bool> permissionGranted() async {
    final status =
        (await _messaging.getNotificationSettings()).authorizationStatus;
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() => _messaging.getToken();

  @override
  Stream<String> get tokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<PushMessage> get foregroundMessages =>
      FirebaseMessaging.onMessage.map(_convert);

  @override
  Stream<PushMessage> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp.map(_convert);

  @override
  Future<PushMessage?> initialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _convert(message);
  }
}

abstract class DeviceRegistrationApi {
  Future<void> register(Map<String, dynamic> payload, {String? bearer});
  Future<void> revoke(Map<String, dynamic> payload);
  Future<void> unlink(Map<String, dynamic> payload);
  Future<void> preferences(Map<String, dynamic> payload);
}

class HttpDeviceRegistrationApi implements DeviceRegistrationApi {
  HttpDeviceRegistrationApi({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;

  Future<void> _send(
    String path,
    String method,
    Map<String, dynamic> payload, {
    String? bearer,
  }) async {
    final response = await _client
        .send(
          http.Request(method, Uri.parse('$_backend$path'))
            ..headers.addAll(<String, String>{
              'apikey': _publishableKey,
              'content-type': 'application/json',
              if (bearer != null) 'authorization': 'Bearer $bearer',
            })
            ..body = jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 12));
    await response.stream.drain<void>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const PushRegistrationException('DEVICE_REGISTRATION_FAILED');
    }
  }

  @override
  Future<void> register(Map<String, dynamic> payload, {String? bearer}) =>
      _send('/devices/register', 'POST', payload, bearer: bearer);

  @override
  Future<void> revoke(Map<String, dynamic> payload) =>
      _send('/devices/revoke', 'POST', payload);

  @override
  Future<void> unlink(Map<String, dynamic> payload) =>
      _send('/devices/unlink', 'POST', payload);

  @override
  Future<void> preferences(Map<String, dynamic> payload) =>
      _send('/devices/preferences', 'PUT', payload);
}

class PushRegistrationException implements Exception {
  const PushRegistrationException(this.code);
  final String code;
}

class PushNotificationService extends ChangeNotifier {
  PushNotificationService({
    required SharedPreferences preferences,
    required LocalNotificationService localNotifications,
    PushGateway? gateway,
    DeviceRegistrationApi? registration,
    Future<String> Function()? appVersion,
  }) : _preferences = preferences,
       _localNotifications = localNotifications,
       _gateway = gateway ?? FirebasePushGateway(),
       _registration = registration ?? HttpDeviceRegistrationApi(),
       _appVersion =
           appVersion ??
           (() async => (await PackageInfo.fromPlatform()).version);

  static const _enabledKey = 'push:enabled';
  static const _installationKey = 'push:installation_id';
  static const _secretKey = 'push:installation_secret';
  final SharedPreferences _preferences;
  final LocalNotificationService _localNotifications;
  final PushGateway _gateway;
  final DeviceRegistrationApi _registration;
  final Future<String> Function() _appVersion;
  final StreamController<String> _routes = StreamController<String>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];
  bool _ready = false;
  bool _busy = false;
  String? _userBearer;

  bool get enabled => _preferences.getBool(_enabledKey) ?? false;
  bool get ready => _ready;
  bool get busy => _busy;
  Stream<String> get routes => _routes.stream;

  String _randomUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  String get _installationId {
    final current = _preferences.getString(_installationKey);
    if (current != null) return current;
    final value = _randomUuid();
    _preferences.setString(_installationKey, value);
    return value;
  }

  String get _installationSecret {
    final current = _preferences.getString(_secretKey);
    if (current != null) return current;
    final value = List<int>.generate(
      32,
      (_) => Random.secure().nextInt(256),
    ).map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    _preferences.setString(_secretKey, value);
    return value;
  }

  Future<void> initialize() async {
    if (_ready) return;
    try {
      await _gateway.initialize();
      _subscriptions.add(
        _gateway.tokenRefresh.listen((token) => _register(token)),
      );
      _subscriptions.add(_gateway.foregroundMessages.listen(_foreground));
      _subscriptions.add(_gateway.openedMessages.listen(_open));
      final initial = await _gateway.initialMessage();
      if (initial != null) _open(initial);
      _ready = true;
      if (enabled && await _gateway.permissionGranted()) {
        final token = await _gateway.token();
        if (token != null) await _register(token);
      }
    } catch (_) {
      _ready = false;
    }
    notifyListeners();
  }

  Future<bool> setEnabled(bool value) async {
    _busy = true;
    notifyListeners();
    try {
      if (value) {
        await initialize();
        if (!_ready || !await _gateway.requestPermission()) return false;
        final token = await _gateway.token();
        if (token == null || token.isEmpty) return false;
        await _preferences.setBool(_enabledKey, true);
        try {
          await _register(token);
        } catch (_) {
          await _preferences.setBool(_enabledKey, false);
          rethrow;
        }
      } else {
        await _registration
            .revoke(<String, dynamic>{
              'installation_id': _installationId,
              'installation_secret': _installationSecret,
            })
            .catchError((_) {});
        await _preferences.setBool(_enabledKey, false);
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> updatePreferences(Map<String, bool> values) =>
      _savePreferences(values);

  Future<void> _savePreferences(Map<String, bool> values) async {
    await _registration.preferences(<String, dynamic>{
      'installation_id': _installationId,
      'installation_secret': _installationSecret,
      ...values,
    });
    for (final entry in values.entries) {
      await _preferences.setBool('push:preference:${entry.key}', entry.value);
    }
    notifyListeners();
  }

  bool preference(String key) =>
      _preferences.getBool('push:preference:$key') ?? true;

  Future<void> _register(String token) async {
    if (!enabled) return;
    await _registration.register(<String, dynamic>{
      'installation_id': _installationId,
      'installation_secret': _installationSecret,
      'fcm_token': token,
      'platform': defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android',
      'app_version': await _appVersion(),
      'locale': 'ar',
      'timezone': 'Asia/Aden',
      'notifications_enabled': true,
    }, bearer: _userBearer);
  }

  Future<void> attachAuthenticatedUser(String? bearer) async {
    final wasAuthenticated = _userBearer != null;
    _userBearer = bearer;
    if (bearer == null && wasAuthenticated) {
      await _registration
          .unlink(<String, dynamic>{
            'installation_id': _installationId,
            'installation_secret': _installationSecret,
          })
          .catchError((_) {});
    }
    if (bearer != null && enabled && _ready) {
      final token = await _gateway.token();
      if (token != null && token.isNotEmpty) await _register(token);
    }
  }

  void _open(PushMessage message) {
    final route = message.data['route'];
    if (route is String && safePushRoutes.contains(route)) _routes.add(route);
  }

  void _foreground(PushMessage message) {
    final title = message.title;
    final body = message.body;
    if (title == null || body == null) return;
    final route = safePushRoutes.contains(message.data['route'])
        ? message.data['route'] as String
        : '/home';
    unawaited(
      _localNotifications.show(
        LocalNotificationRequest(
          id:
              900000 +
              (message.data['notification_id']?.hashCode ?? body.hashCode)
                      .abs() %
                  99999,
          title: title,
          body: body,
          scheduledAt: DateTime.now(),
          timezone: 'Asia/Aden',
          payload: route,
          channel: LocalNotificationChannel.remotePush,
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_routes.close());
    super.dispose();
  }
}
