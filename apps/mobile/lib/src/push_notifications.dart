import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
    final bytes = await response.stream.toBytes();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var code = 'DEVICE_REGISTRATION_FAILED';
      if (bytes.length <= 65536) {
        try {
          final value = jsonDecode(utf8.decode(bytes));
          final error = value is Map ? value['error'] : null;
          if (error is Map && error['code'] is String) {
            code = error['code'] as String;
          }
        } catch (_) {
          // A malformed backend response remains a bounded registration error.
        }
      }
      throw PushRegistrationException(code);
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

abstract class InstallationSecretStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureInstallationSecretStore implements InstallationSecretStore {
  const SecureInstallationSecretStore();
  static const _storage = FlutterSecureStorage();
  static const _key = 'tarteel_push_installation_secret';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}

const pushErrorMessages = <String, String>{
  'FIREBASE_INITIALIZATION_FAILED': 'تعذر تهيئة Firebase للإشعارات',
  'FCM_TOKEN_FAILED': 'تعذر الحصول على رمز الإشعارات من Firebase',
  'DEVICE_REGISTRATION_FAILED': 'تعذر تسجيل الجهاز في الخادم',
  'PERMISSION_DENIED': 'إذن الإشعارات مرفوض من إعدادات النظام',
  'BACKEND_UNAVAILABLE': 'خادم الإشعارات غير متاح حاليًا',
};

class PushNotificationService extends ChangeNotifier {
  PushNotificationService({
    required SharedPreferences preferences,
    required LocalNotificationService localNotifications,
    PushGateway? gateway,
    DeviceRegistrationApi? registration,
    InstallationSecretStore? secretStore,
    Future<String> Function()? appVersion,
  }) : _preferences = preferences,
       _localNotifications = localNotifications,
       _gateway = gateway ?? FirebasePushGateway(),
       _registration = registration ?? HttpDeviceRegistrationApi(),
       _secretStore = secretStore ?? const SecureInstallationSecretStore(),
       _appVersion =
           appVersion ??
           (() async => (await PackageInfo.fromPlatform()).version) {
    _registered = _preferences.getBool(_registeredKey) ?? false;
  }

  static const _enabledKey = 'push:enabled';
  static const _consentKey = 'push:consent';
  static const _registeredKey = 'push:registered';
  static const _lastSyncKey = 'push:last_sync';
  static const _installationKey = 'push:installation_id';
  final SharedPreferences _preferences;
  final LocalNotificationService _localNotifications;
  final PushGateway _gateway;
  final DeviceRegistrationApi _registration;
  final InstallationSecretStore _secretStore;
  final Future<String> Function() _appVersion;
  final StreamController<String> _routes = StreamController<String>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];
  bool _ready = false;
  bool _busy = false;
  bool _registered = false;
  bool _hasToken = false;
  bool _permissionGranted = false;
  String? _lastErrorCode;
  String? _userBearer;

  bool get requested => _preferences.getBool(_enabledKey) ?? false;
  bool get enabled =>
      requested && _permissionGranted && _registered && _hasToken;
  bool get consentDecided => _preferences.containsKey(_consentKey);
  bool get consentGranted => _preferences.getString(_consentKey) == 'allowed';
  bool get needsConsent => !consentDecided;
  bool get ready => _ready;
  bool get busy => _busy;
  bool get registered => _registered;
  bool get systemPermissionGranted => _permissionGranted;
  bool get hasToken => _hasToken;
  DateTime? get lastSyncedAt =>
      DateTime.tryParse(_preferences.getString(_lastSyncKey) ?? '');
  String? get lastErrorCode => _lastErrorCode;
  Stream<String> get routes => _routes.stream;

  String get errorMessage =>
      pushErrorMessages[_lastErrorCode] ?? _lastErrorCode ?? '';

  void _failure(String code) {
    _lastErrorCode = code;
    if (kDebugMode) debugPrint('PUSH_SETUP_FAILED:$code');
  }

  String _errorCode(Object error) {
    if (error is PushRegistrationException) return error.code;
    if (error is TimeoutException || error is http.ClientException) {
      return 'BACKEND_UNAVAILABLE';
    }
    return 'DEVICE_REGISTRATION_FAILED';
  }

  Future<String> _requiredToken() async {
    try {
      final value = await _gateway.token();
      if (value == null || value.isEmpty) {
        throw const PushRegistrationException('FCM_TOKEN_FAILED');
      }
      return value;
    } catch (error) {
      if (error is PushRegistrationException) rethrow;
      throw const PushRegistrationException('FCM_TOKEN_FAILED');
    }
  }

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

  Future<String> get _installationSecret async {
    final current = await _secretStore.read();
    if (current != null && current.length == 64) return current;
    final value = List<int>.generate(
      32,
      (_) => Random.secure().nextInt(256),
    ).map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    await _secretStore.write(value);
    return value;
  }

  Future<void> initialize() async {
    if (_ready || !consentGranted || !_permissionGranted) return;
    try {
      await _gateway.initialize();
      _ready = true;
      _subscriptions.add(_gateway.tokenRefresh.listen(_tokenRefreshed));
      _subscriptions.add(_gateway.foregroundMessages.listen(_foreground));
      _subscriptions.add(_gateway.openedMessages.listen(_open));
      final initial = await _gateway.initialMessage();
      if (initial != null) _open(initial);
      _permissionGranted = await _gateway.permissionGranted();
      final token = await _requiredToken();
      _hasToken = true;
      await _register(
        token,
        notificationsEnabled: requested && _permissionGranted,
      );
    } catch (error) {
      final code = _ready
          ? _errorCode(error)
          : 'FIREBASE_INITIALIZATION_FAILED';
      _failure(code);
    }
    notifyListeners();
  }

  Future<void> deferConsent() async {
    await _preferences.setString(_consentKey, 'later');
    notifyListeners();
  }

  Future<void> _tokenRefreshed(String token) async {
    try {
      await _register(
        token,
        notificationsEnabled: requested && _permissionGranted,
      );
    } catch (error) {
      _failure(_errorCode(error));
      notifyListeners();
    }
  }

  Future<bool> registerCurrentDevice({bool requestPermission = false}) async {
    _busy = true;
    notifyListeners();
    try {
      if (requestPermission) {
        await _preferences.setString(_consentKey, 'allowed');
        await _preferences.setBool(_enabledKey, true);
        _permissionGranted = await _localNotifications.requestPermission();
        if (!_permissionGranted) {
          _failure('PERMISSION_DENIED');
          return false;
        }
      }
      if (!_ready) await initialize();
      if (!_ready) return false;
      if (!requestPermission) {
        _permissionGranted = await _gateway.permissionGranted();
      }
      if (requestPermission && !_permissionGranted) {
        _failure('PERMISSION_DENIED');
        return false;
      }
      final token = await _requiredToken();
      _hasToken = true;
      await _register(
        token,
        notificationsEnabled: requested && _permissionGranted,
      );
      return true;
    } catch (error) {
      _failure(_errorCode(error));
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> setEnabled(bool value) async {
    _busy = true;
    notifyListeners();
    try {
      if (value) {
        await _preferences.setString(_consentKey, 'allowed');
        await _preferences.setBool(_enabledKey, true);
        _permissionGranted = await _localNotifications.requestPermission();
        if (!_permissionGranted) {
          _failure('PERMISSION_DENIED');
          return false;
        }
        await initialize();
        if (!_ready) return false;
        if (!_permissionGranted) {
          _failure('PERMISSION_DENIED');
          return false;
        }
        if (_registered && _hasToken) return true;
        final token = await _requiredToken();
        _hasToken = true;
        try {
          await _register(token, notificationsEnabled: true);
        } catch (_) {
          rethrow;
        }
      } else {
        await _registration.revoke(<String, dynamic>{
          'installation_id': _installationId,
          'installation_secret': await _installationSecret,
        });
        await _preferences.setBool(_enabledKey, false);
        _registered = false;
        await _preferences.setBool(_registeredKey, false);
      }
      return true;
    } catch (error) {
      _failure(_errorCode(error));
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
      'installation_secret': await _installationSecret,
      ...values,
    });
    for (final entry in values.entries) {
      await _preferences.setBool('push:preference:${entry.key}', entry.value);
    }
    notifyListeners();
  }

  bool preference(String key) =>
      _preferences.getBool('push:preference:$key') ?? true;

  Future<void> _register(
    String token, {
    required bool notificationsEnabled,
  }) async {
    await _registration.register(<String, dynamic>{
      'installation_id': _installationId,
      'installation_secret': await _installationSecret,
      'fcm_token': token,
      'platform': defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android',
      'app_version': await _appVersion(),
      'locale': 'ar',
      'timezone': 'Asia/Aden',
      'notifications_enabled': notificationsEnabled,
    }, bearer: _userBearer);
    _registered = true;
    await _preferences.setBool(_registeredKey, true);
    await _preferences.setString(
      _lastSyncKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    _lastErrorCode = null;
  }

  Future<void> refreshPermissionState() async {
    if (!consentGranted) return;
    _permissionGranted = await _localNotifications.permissionGranted();
    if (!_permissionGranted && !_ready) {
      _failure('PERMISSION_DENIED');
      notifyListeners();
      return;
    }
    if (!_ready) {
      await initialize();
      return;
    }
    try {
      final token = await _requiredToken();
      _hasToken = true;
      await _register(
        token,
        notificationsEnabled: requested && _permissionGranted,
      );
    } catch (error) {
      _failure(_errorCode(error));
    }
    notifyListeners();
  }

  Future<void> attachAuthenticatedUser(String? bearer) async {
    final wasAuthenticated = _userBearer != null;
    _userBearer = bearer;
    if (bearer == null && wasAuthenticated) {
      try {
        await _registration.unlink(<String, dynamic>{
          'installation_id': _installationId,
          'installation_secret': await _installationSecret,
        });
      } catch (error) {
        _failure(_errorCode(error));
      }
    }
    if (bearer != null && !_ready && consentGranted) await initialize();
    if (bearer != null && _ready) {
      final token = await _requiredToken();
      await _register(
        token,
        notificationsEnabled: requested && _permissionGranted,
      );
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
