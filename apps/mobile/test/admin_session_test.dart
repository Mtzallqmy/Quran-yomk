import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tarteel/src/admin_api.dart';

void main() {
  test(
    'admin login stores only the refresh session and links the device',
    () async {
      final store = _SessionStore();
      final linked = <String?>[];
      final session = MobileAdminSession(
        client: _client(),
        sessionStore: store,
        onAuthenticationChanged: (token) async => linked.add(token),
      );

      await session.login('admin@example.test', 'password');

      expect(session.signedIn, isTrue);
      expect(store.value, 'refresh-2');
      expect(linked, <String?>['access-2']);
    },
  );

  test('saved refresh session restores without another password', () async {
    final store = _SessionStore()..value = 'refresh-1';
    final session = MobileAdminSession(client: _client(), sessionStore: store);

    await session.restore();

    expect(session.signedIn, isTrue);
    expect(session.permissions, contains('notifications.send'));
    expect(store.value, 'refresh-2');
  });
}

MockClient _client() => MockClient((request) async {
  if (request.url.path == '/auth/v1/token') {
    return http.Response(
      jsonEncode(<String, dynamic>{
        'access_token': 'access-2',
        'refresh_token': 'refresh-2',
      }),
      200,
    );
  }
  if (request.url.path.endsWith('/admin/session')) {
    return http.Response(
      jsonEncode(<String, dynamic>{
        'data': <String, dynamic>{
          'roles': <String>['SUPER_ADMIN'],
          'permissions': <String>['notifications.send'],
        },
      }),
      200,
    );
  }
  if (request.url.path.endsWith('/admin/overview')) {
    return http.Response(
      jsonEncode(<String, dynamic>{
        'data': <String, dynamic>{'devices_total': 1, 'devices_active': 1},
      }),
      200,
    );
  }
  return http.Response('{}', 404);
});

class _SessionStore implements AdminSessionStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> readRefreshToken() async => value;

  @override
  Future<void> writeRefreshToken(String value) async => this.value = value;
}
