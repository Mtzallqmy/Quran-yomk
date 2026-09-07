import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/local_notifications.dart';
import 'package:tarteel/src/push_notifications.dart';

void main() {
  test('permission denied registers an inactive device without crashing', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final registration = _Registration();
    final service = PushNotificationService(
      preferences: await SharedPreferences.getInstance(),
      localNotifications: LocalNotificationService(gateway: _LocalGateway()),
      gateway: _PushGateway(permission: false),
      registration: registration,
      appVersion: () async => '1.0.0',
    );
    expect(await service.setEnabled(true), isFalse);
    expect(service.enabled, isFalse);
    expect(registration.registered, hasLength(1));
    expect(registration.registered.single['notifications_enabled'], isFalse);
    expect(service.lastErrorCode, 'PERMISSION_DENIED');
  });

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
        appVersion: () async => '2.0.0',
      );
      expect(await service.setEnabled(true), isTrue);
      gateway.tokens.add('refreshed-token-value-123456789');
      await Future<void>.delayed(Duration.zero);
      expect(registration.registered, hasLength(3));
      expect(
        registration.registered.first['installation_id'],
        registration.registered.last['installation_id'],
      );
      expect(await service.setEnabled(false), isTrue);
      expect(registration.revoked, hasLength(1));
    },
  );

  test('admin authentication links the current installation', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final registration = _Registration();
    final service = PushNotificationService(
      preferences: await SharedPreferences.getInstance(),
      localNotifications: LocalNotificationService(gateway: _LocalGateway()),
      gateway: _PushGateway(),
      registration: registration,
      appVersion: () async => '2.0.0',
    );
    await service.initialize();
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
        appVersion: () async => '1.0.0',
      );
      await service.initialize();
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
}

class _PushGateway implements PushGateway {
  _PushGateway({this.permission = true});
  final bool permission;
  final tokens = StreamController<String>.broadcast();
  final foreground = StreamController<PushMessage>.broadcast();
  final opened = StreamController<PushMessage>.broadcast();
  @override
  Future<void> initialize() async {}
  @override
  Future<PushMessage?> initialMessage() async => null;
  @override
  Future<bool> permissionGranted() async => permission;
  @override
  Future<bool> requestPermission() async => permission;
  @override
  Future<String?> token() async => 'initial-token-value-123456789';
  @override
  Stream<String> get tokenRefresh => tokens.stream;
  @override
  Stream<PushMessage> get foregroundMessages => foreground.stream;
  @override
  Stream<PushMessage> get openedMessages => opened.stream;
}

class _Registration implements DeviceRegistrationApi {
  final registered = <Map<String, dynamic>>[];
  final bearers = <String?>[];
  final revoked = <Map<String, dynamic>>[];
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
  Future<void> preferences(Map<String, dynamic> payload) async {}
}

class _LocalGateway implements LocalNotificationGateway {
  final shown = <LocalNotificationRequest>[];
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<bool> exactSchedulingAvailable() async => false;
  @override
  Future<String?> initialize(void Function(String payload) onTap) async => null;
  @override
  Future<bool> permissionGranted() async => true;
  @override
  Future<bool> requestPermission() async => true;
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
