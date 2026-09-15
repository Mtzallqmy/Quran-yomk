import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = 'https://qkroecnecdxghcqvvoxn.supabase.co';
const _supabaseKey = 'sb_publishable_dLYCid35ZkeIE95xqiyHoQ_bEhWWISK';
const _adminEdgeRoot = '/functions/v1/notifications/admin';

class AdminApiException implements Exception {
  const AdminApiException(this.code);
  final String code;
}

@immutable
class AdminAuthSession {
  const AdminAuthSession({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

abstract class AdminAuthGateway {
  AdminAuthSession? get currentSession;
  Future<void> signInWithPassword(String email, String password);
  Future<void> restoreSession(String refreshToken);
  Future<void> signOut();
}

class SupabaseAdminAuthGateway implements AdminAuthGateway {
  SupabaseAdminAuthGateway({SupabaseClient? client})
    : _client = client ?? SupabaseClient(_supabaseUrl, _supabaseKey);

  final SupabaseClient _client;

  AdminAuthSession? _map(Session? session) {
    final refreshToken = session?.refreshToken;
    if (session == null || refreshToken == null || refreshToken.isEmpty) {
      return null;
    }
    return AdminAuthSession(
      accessToken: session.accessToken,
      refreshToken: refreshToken,
    );
  }

  @override
  AdminAuthSession? get currentSession => _map(_client.auth.currentSession);

  @override
  Future<void> signInWithPassword(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> restoreSession(String refreshToken) async {
    await _client.auth.setSession(refreshToken);
  }

  @override
  Future<void> signOut() => _client.auth.signOut(scope: SignOutScope.local);
}

enum AdminSessionState { signedOut, authenticating, authorizing, signedIn }

abstract class AdminSessionStore {
  Future<String?> readRefreshToken();
  Future<void> writeRefreshToken(String value);
  Future<void> clear();
}

class SecureAdminSessionStore implements AdminSessionStore {
  const SecureAdminSessionStore();
  static const _storage = FlutterSecureStorage();
  static const _key = 'tarteel_admin_refresh_token';

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _key);

  @override
  Future<void> writeRefreshToken(String value) =>
      _storage.write(key: _key, value: value);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class MobileAdminSession extends ChangeNotifier {
  MobileAdminSession({
    http.Client? client,
    AdminAuthGateway? authGateway,
    AdminSessionStore? sessionStore,
    this.onAuthenticationChanged,
  }) : _httpClient = client ?? http.Client(),
       _authGateway = authGateway ?? SupabaseAdminAuthGateway(),
       _sessionStore = sessionStore ?? const SecureAdminSessionStore();
  final http.Client _httpClient;
  final AdminAuthGateway _authGateway;
  final AdminSessionStore _sessionStore;
  final Future<void> Function(String? token)? onAuthenticationChanged;
  String? _accessToken;
  AdminSessionState _state = AdminSessionState.signedOut;
  Set<String> _roles = <String>{};
  Set<String> _permissions = <String>{};
  Map<String, dynamic>? _overview;

  bool get signedIn =>
      _state == AdminSessionState.signedIn && _accessToken != null;
  bool get checking =>
      _state == AdminSessionState.authenticating ||
      _state == AdminSessionState.authorizing;
  AdminSessionState get state => _state;
  Set<String> get roles => Set<String>.unmodifiable(_roles);
  Set<String> get permissions => Set<String>.unmodifiable(_permissions);
  Map<String, dynamic>? get overview => _overview;
  bool has(String permission) => _permissions.contains(permission);

  void _debug(String stage, {String? code, int? status}) {
    if (!kDebugMode) return;
    final details = <String>[
      'stage=$stage',
      if (code != null) 'code=$code',
      if (status != null) 'status=$status',
    ];
    debugPrint('[TARTEEL_ADMIN] ${details.join(' ')}');
  }

  String _authErrorCode(Object error) {
    if (error is AuthException) {
      final code = error.code?.trim();
      if (code != null && code.isNotEmpty) {
        return switch (code.toLowerCase()) {
          'invalid_credentials' ||
          'invalid_grant' => 'INVALID_LOGIN_CREDENTIALS',
          'over_request_rate_limit' ||
          'over_email_send_rate_limit' => 'RATE_LIMITED',
          _ => code.toUpperCase(),
        };
      }
      if (error.statusCode == '400') return 'INVALID_LOGIN_CREDENTIALS';
      if (error.statusCode == '429') return 'RATE_LIMITED';
      return 'AUTHENTICATION_FAILED';
    }
    if (error is TimeoutException || error is http.ClientException) {
      return 'BACKEND_UNAVAILABLE';
    }
    return 'AUTHENTICATION_FAILED';
  }

  String _responseErrorCode(Map<String, dynamic> decoded, int status) {
    final error = decoded['error'];
    if (error is Map && error['code'] is String) {
      return error['code'] as String;
    }
    if (decoded['code'] is String) return decoded['code'] as String;
    return switch (status) {
      401 => 'AUTH_REQUIRED',
      403 => 'FORBIDDEN',
      404 => 'ADMIN_ENDPOINT_NOT_FOUND',
      408 || 502 || 503 || 504 => 'BACKEND_UNAVAILABLE',
      _ => 'ADMIN_REQUEST_FAILED',
    };
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? idempotencyKey,
    bool auth = true,
  }) async {
    final request = http.Request(method, Uri.parse('$_supabaseUrl$path'))
      ..headers.addAll(<String, String>{
        'apikey': _supabaseKey,
        'content-type': 'application/json',
        if (auth && _accessToken != null)
          'authorization': 'Bearer $_accessToken',
        if (idempotencyKey != null) 'idempotency-key': idempotencyKey,
      });
    if (body != null) request.body = jsonEncode(body);
    http.StreamedResponse response;
    try {
      response = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      _debug('edge_timeout');
      throw const AdminApiException('BACKEND_UNAVAILABLE');
    } on http.ClientException {
      _debug('edge_network_failure');
      throw const AdminApiException('BACKEND_UNAVAILABLE');
    }
    final bytes = await response.stream.toBytes();
    Map<String, dynamic> decoded = <String, dynamic>{};
    try {
      final value = jsonDecode(utf8.decode(bytes));
      if (value is Map) decoded = Map<String, dynamic>.from(value);
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = _responseErrorCode(decoded, response.statusCode);
      _debug('edge_rejected', code: code, status: response.statusCode);
      throw AdminApiException(code);
    }
    _debug('edge_accepted', status: response.statusCode);
    return decoded;
  }

  Future<void> login(String email, String password) async {
    _state = AdminSessionState.authenticating;
    notifyListeners();
    _debug('password_sign_in_started');
    try {
      await _authGateway.signInWithPassword(email.trim(), password);
      final session = _authGateway.currentSession;
      if (session == null || session.accessToken.isEmpty) {
        throw const AdminApiException('INVALID_AUTH_RESPONSE');
      }
      _debug('password_sign_in_succeeded');
      await _activate(session);
    } catch (error) {
      final failure = error is AdminApiException
          ? error
          : AdminApiException(_authErrorCode(error));
      _debug('password_sign_in_failed', code: failure.code);
      await _rejectSession();
      throw failure;
    }
  }

  Future<void> restore() async {
    final saved = await _sessionStore.readRefreshToken();
    if (saved == null || saved.isEmpty || signedIn) return;
    _state = AdminSessionState.authenticating;
    notifyListeners();
    _debug('session_restore_started');
    try {
      await _authGateway.restoreSession(saved);
      final session = _authGateway.currentSession;
      if (session == null || session.accessToken.isEmpty) {
        throw const AdminApiException('INVALID_AUTH_RESPONSE');
      }
      await _activate(session);
      _debug('session_restore_succeeded');
    } catch (error) {
      _debug(
        'session_restore_failed',
        code: error is AdminApiException ? error.code : _authErrorCode(error),
      );
      await _rejectSession();
    }
  }

  Future<void> _activate(AdminAuthSession session) async {
    _accessToken = session.accessToken;
    _state = AdminSessionState.authorizing;
    notifyListeners();
    _debug('admin_authorization_started');
    try {
      final context = await _edge('session');
      _roles = _stringSet(context['roles']);
      _permissions = _stringSet(context['permissions']);
      if (!_roles.contains('SUPER_ADMIN') &&
          !_permissions.contains('dashboard.read')) {
        throw const AdminApiException('FORBIDDEN');
      }
      await _sessionStore.writeRefreshToken(session.refreshToken);
      _state = AdminSessionState.signedIn;
      _debug('admin_authorization_succeeded');
      notifyListeners();
      unawaited(_notifyAuthenticationChanged(session.accessToken));
    } catch (error) {
      _debug(
        'admin_authorization_failed',
        code: error is AdminApiException ? error.code : null,
      );
      rethrow;
    }
  }

  Set<String> _stringSet(Object? value) => value is List
      ? value.whereType<String>().where((item) => item.isNotEmpty).toSet()
      : <String>{};

  Future<void> _notifyAuthenticationChanged(String? token) async {
    try {
      await onAuthenticationChanged?.call(token);
    } catch (_) {
      // Device notification linking is useful, but never an admin auth gate.
      _debug('notification_device_link_failed');
    }
  }

  Future<void> _rejectSession() async {
    _accessToken = null;
    _roles = <String>{};
    _permissions = <String>{};
    _overview = null;
    _state = AdminSessionState.signedOut;
    await _sessionStore.clear();
    try {
      await _authGateway.signOut();
    } catch (_) {
      _debug('local_sign_out_failed');
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> _edge(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    final root = await _request(
      '$_adminEdgeRoot/$path',
      method: method,
      body: body,
      idempotencyKey: idempotencyKey,
    );
    final data = root['data'];
    if (data is! Map) {
      _debug('edge_invalid_response');
      throw const AdminApiException('INVALID_ADMIN_RESPONSE');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> getOverview() => _edge('overview');
  Future<void> refreshOverview() async {
    _overview = await getOverview();
    notifyListeners();
  }

  Future<List<dynamic>> notifications() async =>
      (await _edge('notifications'))['items'] as List<dynamic>? ??
      const <dynamic>[];
  Future<List<dynamic>> devices({bool history = false}) async =>
      (await _edge(history ? 'devices?history=true' : 'devices'))['items']
          as List<dynamic>? ??
      const <dynamic>[];
  Future<Map<String, dynamic>> health() => _edge('health');
  Future<List<dynamic>> announcements() async =>
      (await _edge('announcements'))['items'] as List<dynamic>? ??
      const <dynamic>[];
  Future<List<dynamic>> runtimeConfig() async =>
      (await _edge('runtime-config'))['items'] as List<dynamic>? ??
      const <dynamic>[];
  Future<List<dynamic>> audit() async =>
      (await _edge('audit'))['items'] as List<dynamic>? ?? const <dynamic>[];

  Future<void> createNotification(Map<String, dynamic> value) async {
    await _edge(
      'notifications',
      method: 'POST',
      body: value,
      idempotencyKey: 'mobile-${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  Future<void> sendTest(Map<String, dynamic> value) async {
    await _edge(
      'test',
      method: 'POST',
      body: value,
      idempotencyKey: 'mobile-test-${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  Future<void> cancel(String id) async {
    await _edge('notifications/$id/cancel', method: 'POST');
  }

  Future<void> retry(String id) async {
    await _edge('notifications/$id/retry', method: 'POST');
  }

  Future<void> updateRuntime(Map<String, dynamic> updates) async {
    await _edge(
      'runtime-config',
      method: 'PUT',
      body: <String, dynamic>{'updates': updates},
    );
  }

  Future<void> createAnnouncement(Map<String, dynamic> value) async {
    await _edge('announcements', method: 'POST', body: value);
  }

  Future<void> updateAnnouncement(String id, Map<String, dynamic> value) async {
    await _edge('announcements/$id', method: 'PUT', body: value);
  }

  Future<void> archiveAnnouncement(String id) async {
    await _edge('announcements/$id', method: 'DELETE');
  }

  Future<void> logout() async {
    try {
      await _authGateway.signOut();
    } catch (_) {
      _debug('local_sign_out_failed');
    }
    _accessToken = null;
    _roles = <String>{};
    _permissions = <String>{};
    _overview = null;
    _state = AdminSessionState.signedOut;
    await _sessionStore.clear();
    unawaited(_notifyAuthenticationChanged(null));
    notifyListeners();
  }
}
