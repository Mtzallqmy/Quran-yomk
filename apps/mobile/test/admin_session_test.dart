import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tarteel/src/admin_api.dart';

void main() {
  test(
    'login verifies the current Supabase access token at the admin edge route',
    () async {
      final requests = <http.Request>[];
      final store = _SessionStore();
      final linked = <String?>[];
      final auth = _AuthGateway();
      final session = MobileAdminSession(
        client: _client(requests: requests),
        authGateway: auth,
        sessionStore: store,
        onAuthenticationChanged: (token) async => linked.add(token),
      );

      await session.login('admin@example.test', 'password');
      await Future<void>.delayed(Duration.zero);

      expect(auth.signedInEmail, 'admin@example.test');
      expect(session.signedIn, isTrue);
      expect(session.roles, contains('SUPER_ADMIN'));
      expect(store.value, 'refresh-current');
      expect(linked, <String?>['access-current']);
      expect(requests, hasLength(1));
      expect(
        requests.single.url.path,
        '/functions/v1/notifications/admin/session',
      );
      expect(requests.single.url.path, isNot(contains('tarteel-api')));
      expect(requests.single.headers['authorization'], 'Bearer access-current');
      expect(requests.single.headers['content-type'], 'application/json');
    },
  );

  test('dashboard.read authorizes a non-super-admin session', () async {
    final session = MobileAdminSession(
      client: _client(
        sessionData: <String, dynamic>{
          'roles': <String>['EDITOR'],
          'permissions': <String>['dashboard.read'],
        },
      ),
      authGateway: _AuthGateway(),
      sessionStore: _SessionStore(),
    );

    await session.login('admin@example.test', 'password');

    expect(session.signedIn, isTrue);
    expect(session.has('dashboard.read'), isTrue);
  });

  test('an overview failure does not revoke an authorized login', () async {
    final session = MobileAdminSession(
      client: _client(overviewStatus: 503),
      authGateway: _AuthGateway(),
      sessionStore: _SessionStore(),
    );

    await session.login('admin@example.test', 'password');
    expect(session.signedIn, isTrue);

    await expectLater(
      session.getOverview(),
      throwsA(
        isA<AdminApiException>().having(
          (error) => error.code,
          'code',
          'BACKEND_UNAVAILABLE',
        ),
      ),
    );
    expect(session.signedIn, isTrue);
  });

  test('user is not signed in while authorization is pending', () async {
    final response = Completer<http.Response>();
    final session = MobileAdminSession(
      client: MockClient((_) => response.future),
      authGateway: _AuthGateway(),
      sessionStore: _SessionStore(),
    );

    final login = session.login('admin@example.test', 'password');
    await Future<void>.delayed(Duration.zero);

    expect(session.state, AdminSessionState.authorizing);
    expect(session.checking, isTrue);
    expect(session.signedIn, isFalse);

    response.complete(_sessionResponse());
    await login;
    expect(session.signedIn, isTrue);
  });

  test('missing role and dashboard permission is rejected securely', () async {
    final auth = _AuthGateway();
    final store = _SessionStore();
    final session = MobileAdminSession(
      client: _client(
        sessionData: <String, dynamic>{
          'roles': <String>['EDITOR'],
          'permissions': <String>['notifications.send'],
        },
      ),
      authGateway: auth,
      sessionStore: store,
    );

    await expectLater(
      session.login('admin@example.test', 'password'),
      throwsA(
        isA<AdminApiException>().having(
          (error) => error.code,
          'code',
          'FORBIDDEN',
        ),
      ),
    );

    expect(session.signedIn, isFalse);
    expect(auth.signOutCalls, 1);
    expect(store.value, isNull);
  });

  test('nested edge error is parsed without discarding its code', () async {
    final session = MobileAdminSession(
      client: _client(sessionStatus: 401, sessionError: 'AUTH_REQUIRED'),
      authGateway: _AuthGateway(),
      sessionStore: _SessionStore(),
    );

    await expectLater(
      session.login('admin@example.test', 'password'),
      throwsA(
        isA<AdminApiException>().having(
          (error) => error.code,
          'code',
          'AUTH_REQUIRED',
        ),
      ),
    );
  });

  test(
    'saved refresh token restores and verifies the current session',
    () async {
      final store = _SessionStore()..value = 'refresh-old';
      final auth = _AuthGateway();
      final session = MobileAdminSession(
        client: _client(),
        authGateway: auth,
        sessionStore: store,
      );

      await session.restore();

      expect(auth.restoredRefreshToken, 'refresh-old');
      expect(session.signedIn, isTrue);
      expect(store.value, 'refresh-current');
    },
  );

  test(
    'notification device linking cannot reject an authorized admin',
    () async {
      final session = MobileAdminSession(
        client: _client(),
        authGateway: _AuthGateway(),
        sessionStore: _SessionStore(),
        onAuthenticationChanged: (_) async => throw StateError('offline'),
      );

      await session.login('admin@example.test', 'password');
      await Future<void>.delayed(Duration.zero);

      expect(session.signedIn, isTrue);
    },
  );
}

MockClient _client({
  List<http.Request>? requests,
  Map<String, dynamic>? sessionData,
  int sessionStatus = 200,
  String sessionError = 'ADMIN_REQUEST_FAILED',
  int overviewStatus = 200,
}) => MockClient((request) async {
  requests?.add(request);
  if (request.url.path.endsWith('/admin/session')) {
    if (sessionStatus != 200) {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'error': <String, dynamic>{'code': sessionError},
        }),
        sessionStatus,
      );
    }
    return _sessionResponse(sessionData);
  }
  if (request.url.path.endsWith('/admin/overview')) {
    if (overviewStatus != 200) {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'error': <String, dynamic>{'code': 'BACKEND_UNAVAILABLE'},
        }),
        overviewStatus,
      );
    }
    return http.Response(
      jsonEncode(<String, dynamic>{
        'data': <String, dynamic>{'devices_total': 1, 'devices_active': 1},
      }),
      200,
    );
  }
  return http.Response('{}', 404);
});

http.Response _sessionResponse([Map<String, dynamic>? data]) => http.Response(
  jsonEncode(<String, dynamic>{
    'data':
        data ??
        <String, dynamic>{
          'roles': <String>['SUPER_ADMIN'],
          'permissions': <String>['notifications.send'],
        },
  }),
  200,
);

class _AuthGateway implements AdminAuthGateway {
  AdminAuthSession? _session;
  String? signedInEmail;
  String? restoredRefreshToken;
  int signOutCalls = 0;

  @override
  AdminAuthSession? get currentSession => _session;

  @override
  Future<void> signInWithPassword(String email, String password) async {
    signedInEmail = email;
    _session = const AdminAuthSession(
      accessToken: 'access-current',
      refreshToken: 'refresh-current',
    );
  }

  @override
  Future<void> restoreSession(String refreshToken) async {
    restoredRefreshToken = refreshToken;
    _session = const AdminAuthSession(
      accessToken: 'access-current',
      refreshToken: 'refresh-current',
    );
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _session = null;
  }
}

class _SessionStore implements AdminSessionStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> readRefreshToken() async => value;

  @override
  Future<void> writeRefreshToken(String value) async => this.value = value;
}
