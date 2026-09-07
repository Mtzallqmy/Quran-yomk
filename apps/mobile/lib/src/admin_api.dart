import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _supabaseUrl = 'https://qkroecnecdxghcqvvoxn.supabase.co';
const _supabaseKey = 'sb_publishable_dLYCid35ZkeIE95xqiyHoQ_bEhWWISK';

class AdminApiException implements Exception {
  const AdminApiException(this.code);
  final String code;
}

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
    AdminSessionStore? sessionStore,
    this.onAuthenticationChanged,
  }) : _client = client ?? http.Client(),
       _sessionStore = sessionStore ?? const SecureAdminSessionStore();
  final http.Client _client;
  final AdminSessionStore _sessionStore;
  final Future<void> Function(String? token)? onAuthenticationChanged;
  String? _accessToken;
  Set<String> _permissions = <String>{};
  Map<String, dynamic>? _overview;

  bool get signedIn => _accessToken != null;
  Set<String> get permissions => Set<String>.unmodifiable(_permissions);
  Map<String, dynamic>? get overview => _overview;
  bool has(String permission) => _permissions.contains(permission);

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
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 12));
    final bytes = await response.stream.toBytes();
    Map<String, dynamic> decoded = <String, dynamic>{};
    try {
      final value = jsonDecode(utf8.decode(bytes));
      if (value is Map) decoded = Map<String, dynamic>.from(value);
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      final code = error is Map && error['code'] is String
          ? error['code'] as String
          : 'ADMIN_REQUEST_FAILED';
      throw AdminApiException(code);
    }
    return decoded;
  }

  Future<void> login(String email, String password) async {
    final auth = await _request(
      '/auth/v1/token?grant_type=password',
      method: 'POST',
      body: <String, dynamic>{'email': email.trim(), 'password': password},
      auth: false,
    );
    final token = auth['access_token'];
    final refreshToken = auth['refresh_token'];
    if (token is! String || token.isEmpty || refreshToken is! String) {
      throw const AdminApiException('INVALID_AUTH_RESPONSE');
    }
    await _activate(token, refreshToken);
  }

  Future<void> restore() async {
    final saved = await _sessionStore.readRefreshToken();
    if (saved == null || saved.isEmpty || signedIn) return;
    try {
      final auth = await _request(
        '/auth/v1/token?grant_type=refresh_token',
        method: 'POST',
        body: <String, dynamic>{'refresh_token': saved},
        auth: false,
      );
      final token = auth['access_token'];
      final rotated = auth['refresh_token'];
      if (token is! String || rotated is! String) {
        throw const AdminApiException('INVALID_AUTH_RESPONSE');
      }
      await _activate(token, rotated);
    } catch (_) {
      await _sessionStore.clear();
    }
  }

  Future<void> _activate(String token, String refreshToken) async {
    _accessToken = token;
    try {
      final session = await _edge('session');
      _permissions =
          (session['permissions'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toSet();
      await onAuthenticationChanged?.call(token);
      _overview = await getOverview();
      await _sessionStore.writeRefreshToken(refreshToken);
      notifyListeners();
    } catch (_) {
      _accessToken = null;
      _permissions = <String>{};
      _overview = null;
      await _sessionStore.clear();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _edge(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    final root = await _request(
      '/functions/v1/notifications/admin/$path',
      method: method,
      body: body,
      idempotencyKey: idempotencyKey,
    );
    final data = root['data'];
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getOverview() => _edge('overview');
  Future<void> refreshOverview() async {
    _overview = await getOverview();
    notifyListeners();
  }

  Future<List<dynamic>> notifications() async =>
      (await _edge('notifications'))['items'] as List<dynamic>? ??
      const <dynamic>[];
  Future<List<dynamic>> devices() async =>
      (await _edge('devices'))['items'] as List<dynamic>? ?? const <dynamic>[];
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

  Future<void> logout() async {
    if (_accessToken != null) {
      await _request(
        '/auth/v1/logout',
        method: 'POST',
      ).catchError((_) => <String, dynamic>{});
    }
    _accessToken = null;
    _permissions = <String>{};
    _overview = null;
    await _sessionStore.clear();
    await onAuthenticationChanged?.call(null);
    notifyListeners();
  }
}
