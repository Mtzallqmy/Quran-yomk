import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/local_notifications.dart';
import 'package:tarteel/src/push_notifications.dart';

void main() {
  test('permission denied does not initialize Firebase or register', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final registration = _Registration();
    final service = PushNotificationService(
      preferences: await SharedPreferences.getInstance(),
      localNotifications: LocalNotificationService(
        gateway: _LocalGateway(permission: false),
      ),
      gateway: _PushGateway(permission: false),
      registration: registration,
      secretStore: _SecretStore(),
      appVersion: () async => '1.0.0',
    );
    expect(await service.setEnabled(true), isFalse);
    expect(service.enabled, isFalse);
    expect(registration.registered, isEmpty);
    expect(service.lastErrorCode, 'PERMISSION_DENIED');
  });

  test(
    'disabled Android notifications override Firebase authorization',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final registration = _Registration();
      final service = PushNotificationService(
        preferences: await SharedPreferences.getInstance(),
        localNotifications: LocalNotificationService(
          gateway: _LocalGateway(permission: false),
        ),
        gateway: _PushGateway(permission: true),
        registration: registration,
        secretStore: _SecretStore(),
        appVersion: () async => '1.0.0',
      );
      expect(await service.setEnabled(true), isFalse);
      expect(service.lastErrorCode, 'PERMISSION_DENIED');
      expect(service.enabled, isFalse);
      expect(registration.registered, isEmpty);
    },
  );

  test(
    'registration, token refresh and revoke preserve one installation',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final registration = _Registration();
      final gateway = _PushGateway();
      final service = PushNotificationService(
        preferences: await SharedPreferences.getInstance(),
        localNotifications: LocalNotificationService(gateway: _LocalGateway()),
        gateway: gateway,
        registration: registration,
        secretStore: _SecretStore(),
        appVersion: () async => '2.0.0',
      );
      expect(await service.setEnabled(true), isTrue);
      gateway.tokens.add('refreshed-token-value-123456789');
      await Future<void>.delayed(Duration.zero);
      expect(registration.registered, hasLength(2));
      expect(
        registration.registered.first['installation_id'],
        registration.registered.last['installation_id'],
      );
      expect(await service.setEnabled(false), isTrue);
      expect(registration.revoked, hasLength(1));
    },
  );

  test('not now persists consent without initializing Firebase', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final gateway = _PushGateway();
    final preferences = await SharedPreferences.getInstance();
    final service = PushNotificationService(
      preferences: preferences,
      localNotifications: LocalNotificationService(gateway: _LocalGateway()),
      gateway: gateway,
      registration: _Registration(),
      secretStore: _SecretStore(),
      appVersion: () async => '1.0.0',
    );
    expect(service.needsConsent, isTrue);
    await service.deferConsent();
    expect(service.needsConsent, isFalse);
    expect(gateway.initializeCount, 0);
  });

  test(
    'accepted consent initializes Firebase and requests permission once',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final gateway = _PushGateway();
      final registration = _Registration();
      final service = PushNotificationService(
        preferences: await SharedPreferences.getInstance(),
        localNotifications: LocalNotificationService(gateway: _LocalGateway()),
        gateway: gateway,
        registration: registration,
        secretStore: _SecretStore(),
        appVersion: () async => '1.0.0',
      );
      expect(await service.setEnabled(true), isTrue);
      expect(gateway.initializeCount, 1);
      expect(gateway.permissionRequestCount, 1);
      expect(service.enabled, isTrue);
      expect(registration.registered, hasLength(1));
    },
  );

  test(
    'Firebase permission remains usable when Android plugin request fails',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final registration = _Registration();
      final service = PushNotificationService(
        preferences: await SharedPreferences.getInstance(),
        localNotifications: LocalNotificationService(
          gateway: _LocalGateway(failPermissionRequest: true),
        ),
        gateway: _PushGateway(permission: true),
        registration: registration,
        secretStore: _SecretStore(),
        appVersion: () async => '1.0.0',
      );

      expect(await service.setEnabled(true), isTrue);
      expect(service.systemPermissionChecked, isTrue);
      expect(service.systemPermissionGranted, isTrue);
      expect(service.hasToken, isTrue);
      expect(service.registered, isTrue);
      expect(registration.registered, hasLength(1));
    },
  );

  test(
    'permission refresh falls back when Android plugin query fails',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'push:consent': 'allowed',
        'push:enabled': true,
      });
      final registration = _Registration();
      final service = PushNotificationService(
        preferences: await SharedPreferences.getInstance(),
        localNotifications: LocalNotificationService(
          gateway: _LocalGateway(failPermissionQuery: true),
        ),
        gateway: _PushGateway(permission: true),
        registration: registration,
        secretStore: _SecretStore(),
        appVersion: () async => '1.0.0',
      );

      await service.refreshPermissionState();

      expect(service.systemPermissionChecked, isTrue);
      expect(service.enabled, isTrue);
      expect(registration.registered, hasLength(1));
    },
  );

  test('persisted registration is verified again after app restart', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'push:registered': true,
      'push:last_sync': '2026-09-07T03:29:06.000Z',
    });
    final service = PushNotificationService(
      preferences: await SharedPreferences.getInstance(),
      localNotifications: LocalNotificationService(gateway: _LocalGateway()),
      gateway: _PushGateway(),
      registration: _Registration(),
      secretStore: _SecretStore(),
      appVersion: () async => '1.0.0',
    );

    expect(service.registered, isFalse);
    expect(service.lastSyncedAt, isNotNull);
  });

  test(
    'Firebase initialization failure is not reported as device failure',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final service = PushNotificationService(
        preferences: await SharedPreferences.getInstance(),
        localNotifications: LocalNotificationService(gateway: _LocalGateway()),
        gateway: _FailingPushGateway(),
        registration: _Registration(),
        secretStore: _SecretStore(),
        appVersion: () async => '1.0.0',
      );
      expect(await service.setEnabled(true), isFalse);
      expect(service.lastErrorCode, 'FIREBASE_INITIALIZATION_FAILED');
    },
  );

  test('permission change on resume updates the active registration', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final registration = _Registration();
    final gateway = _PushGateway();
    final local = _LocalGateway();
    final service = PushNotificationService(
      preferences: await SharedPreferences.getInstance(),
      localNotifications: LocalNotificationService(gateway: local),
      gateway: gateway,
      registration: registration,
      secretStore: _SecretStore(),
      appVersion: () async => '1.0.0',
    );
    expect(await service.setEnabled(true), isTrue);
    local.permission = false;
    gateway.permission = false;
    await service.refreshPermissionState();
    expect(service.enabled, isFalse);
    expect(registration.registered.last['notifications_enabled'], isFalse);
  });

  test('admin authentication links the current installation', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final registration = _Registration();
    final service = PushNotificationService(
      preferences: await SharedPreferences.getInstance(),
      localNotifications: LocalNotificationService(gateway: _LocalGateway()),
      gateway: _PushGateway(),
      registration: registration,
      secretStore: _SecretStore(),
      appVersion: () async => '2.0.0',
    );
    expect(await service.setEnabled(true), isTrue);
    await service.attachAuthenticatedUser('admin-access-token');
    expect(registration.registered, hasLength(2));
    expect(registration.bearers.last, 'admin-access-token');
    expect(
      registration.registered.first['installation_id'],
      registration.registered.last['installation_id'],
    );
  });

  test(
    'foreground and opened payloads accept only known internal routes',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final gateway = _PushGateway();
      final local = _LocalGateway();
      final service = PushNotificationService(
        preferences: await SharedPreferences.getInstance(),
        localNotifications: LocalNotificationService(gateway: local),
        gateway: gateway,
        registration: _Registration(),
        secretStore: _SecretStore(),
        appVersion: () async => '1.0.0',
      );
      expect(await service.setEnabled(true), isTrue);
      final routes = <String>[];
      service.routes.listen(routes.add);
      gateway.opened.add(
        const PushMessage(
          data: <String, dynamic>{'route': 'https://evil.test'},
        ),
      );
      gateway.foreground.add(
        const PushMessage(
          data: <String, dynamic>{'route': '/prayer-times'},
          title: 'ترتيل',
          body: 'اختبار',
        ),
      );
      gateway.opened.add(
        const PushMessage(data: <String, dynamic>{'route': '/prayer-times'}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(routes, <String>['/prayer-times']);
      expect(local.shown, hasLength(1));
      expect(local.shown.single.payload, '/prayer-times');
    },
  );

  test('notification categories are persisted independently', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final registration = _Registration();
    final service = PushNotificationService(
      preferences: await SharedPreferences.getInstance(),
      localNotifications: LocalNotificationService(gateway: _LocalGateway()),
      gateway: _PushGateway(),
      registration: registration,
      secretStore: _SecretStore(),
      appVersion: () async => '1.0.0',
    );
    expect(await service.setEnabled(true), isTrue);
    await service.updatePreferences(<String, bool>{
      'memorization_review': false,
      'personal_reminders': true,
    });
    expect(service.preference('memorization_review'), isFalse);
    expect(service.preference('personal_reminders'), isTrue);
    expect(registration.savedPreferences.single['memorization_review'], false);
    expect(registration.savedPreferences.single['personal_reminders'], true);
  });
}

class _PushGateway implements PushGateway {
  _PushGateway({this.permission = true});
  bool permission;
  int initializeCount = 0;
  int permissionRequestCount = 0;
  final tokens = StreamController<String>.broadcast();
  final foreground = StreamController<PushMessage>.broadcast();
  final opened = StreamController<PushMessage>.broadcast();
  @override
  Future<void> initialize() async => initializeCount++;
  @override
  Future<PushMessage?> initialMessage() async => null;
  @override
  Future<bool> permissionGranted() async => permission;
  @override
  Future<bool> requestPermission() async {
    permissionRequestCount++;
    return permission;
  }

  @override
  Future<String?> token() async => 'initial-token-value-123456789';
  @override
  Stream<String> get tokenRefresh => tokens.stream;
  @override
  Stream<PushMessage> get foregroundMessages => foreground.stream;
  @override
  Stream<PushMessage> get openedMessages => opened.stream;
}

class _FailingPushGateway extends _PushGateway {
  @override
  Future<void> initialize() => throw StateError('firebase unavailable');
}

class _Registration implements DeviceRegistrationApi {
  final registered = <Map<String, dynamic>>[];
  final bearers = <String?>[];
  final revoked = <Map<String, dynamic>>[];
  final savedPreferences = <Map<String, dynamic>>[];
  @override
  Future<void> register(Map<String, dynamic> payload, {String? bearer}) async {
    registered.add(payload);
    bearers.add(bearer);
  }

  @override
  Future<void> revoke(Map<String, dynamic> payload) async =>
      revoked.add(payload);
  @override
  Future<void> unlink(Map<String, dynamic> payload) async {}
  @override
  Future<void> preferences(Map<String, dynamic> payload) async =>
      savedPreferences.add(payload);
}

class _LocalGateway implements LocalNotificationGateway {
  _LocalGateway({
    this.permission = true,
    this.failPermissionQuery = false,
    this.failPermissionRequest = false,
  });
  bool permission;
  final bool failPermissionQuery;
  final bool failPermissionRequest;
  final shown = <LocalNotificationRequest>[];
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<bool> exactSchedulingAvailable() async => false;
  @override
  Future<String?> initialize(void Function(String payload) onTap) async => null;
  @override
  Future<bool> permissionGranted() async {
    if (failPermissionQuery) throw StateError('query unavailable');
    return permission;
  }

  @override
  Future<bool> requestPermission() async {
    if (failPermissionRequest) throw StateError('request unavailable');
    return permission;
  }

  @override
  Future<bool> openSystemSettings() async => true;
  @override
  Future<void> schedule(
    LocalNotificationRequest request, {
    required bool exact,
  }) async {}
  @override
  Future<void> show(LocalNotificationRequest request) async =>
      shown.add(request);
}

class _SecretStore implements InstallationSecretStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
