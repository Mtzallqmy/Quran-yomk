import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'storage.dart';
import 'prayer_settings.dart';
import 'prayer_backup.dart';

/// Optional, explicitly requested library backup. Never called by prayer/startup.
class CloudBackupClient {
  CloudBackupClient({
    http.Client? client,
    FlutterSecureStorage? storage,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage(),
       _baseUrl =
           baseUrl ?? const String.fromEnvironment('TARTEEL_CLOUD_BASE_URL');

  static const _credentialKey = 'tarteel:cloud:device-token:v1';
  final http.Client _client;
  final FlutterSecureStorage _storage;
  final String _baseUrl;
  bool get configured {
    final uri = Uri.tryParse(_baseUrl);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  Future<bool> enabled() async =>
      await _storage.read(key: _credentialKey) != null;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? body,
    String? token,
  }) async {
    if (!configured) throw StateError('CLOUD_NOT_CONFIGURED');
    final request = http.Request(
      method,
      Uri.parse('${_baseUrl.replaceFirst(RegExp(r'/$'), '')}$path'),
    );
    request.followRedirects = false;
    request.headers['content-type'] = 'application/json';
    if (token != null) request.headers['authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 15)),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        response.statusCode == 409 ? 'CLOUD_CONFLICT' : 'CLOUD_REQUEST_FAILED',
      );
    }
    final value = jsonDecode(response.body);
    if (value is! Map<String, dynamic>)
      throw const FormatException('INVALID_CLOUD_RESPONSE');
    return value;
  }

  Future<void> connectWithConsent() async {
    if (await enabled()) return;
    final data = await _request(
      'POST',
      '/v1/devices',
      body: {'consent': 'favorites-backup-v1'},
    );
    final token = data['token'];
    if (token is! String || !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
      throw const FormatException('INVALID_CLOUD_CREDENTIAL');
    }
    await _storage.write(key: _credentialKey, value: token);
  }

  Future<String> _token() async {
    final token = await _storage.read(key: _credentialKey);
    if (token == null) throw StateError('CLOUD_CONSENT_REQUIRED');
    return token;
  }

  Future<void> upload(FavoritesStore favorites) async {
    final token = await _token();
    final current = (await _request(
      'GET',
      '/v1/library-backup',
      token: token,
    ))['data'];
    final revision = current is Map
        ? int.tryParse('${current['revision']}')
        : 0;
    if (revision == null) throw const FormatException('INVALID_CLOUD_REVISION');
    await _request(
      'PUT',
      '/v1/library-backup',
      token: token,
      body: {
        'revision': revision,
        'payload': {
          'stations': favorites.stationIds.toList(),
          'reciters': favorites.reciterIds.toList(),
          'tracks': favorites.trackIds.toList(),
        },
      },
    );
  }

  /// Merge only after validating every incoming row; never clear local favorites.
  Future<void> restore(FavoritesStore favorites) async {
    final result = await _request(
      'GET',
      '/v1/library-backup',
      token: await _token(),
    );
    final data = result['data'];
    if (data == null) throw StateError('CLOUD_BACKUP_EMPTY');
    final payload = data is Map ? data['payload'] : null;
    if (payload is! Map) throw const FormatException('INVALID_CLOUD_BACKUP');
    final values = <String, List<String>>{};
    for (final key in ['stations', 'reciters', 'tracks']) {
      final rows = payload[key];
      if (rows is! List ||
          rows.length > 500 ||
          rows.any(
            (value) => value is! String || value.isEmpty || value.length > 200,
          )) {
        throw const FormatException('INVALID_CLOUD_BACKUP');
      }
      values[key] = rows.cast<String>();
    }
    for (final id in values['stations']!) {
      if (!favorites.isStation(id)) await favorites.toggleStation(id);
    }
    for (final id in values['reciters']!) {
      if (!favorites.isReciter(id)) await favorites.toggleReciter(id);
    }
    for (final id in values['tracks']!) {
      if (!favorites.isTrack(id)) await favorites.toggleTrack(id);
    }
  }

  Future<void> disconnectAndDelete() async {
    await _request('DELETE', '/v1/device', token: await _token());
    await _storage.delete(key: _credentialKey);
  }

  Future<void> uploadPrayerPreferences(PrayerSettings value) async {
    final token = await _token();
    final data = (await _request(
      'GET',
      '/v1/prayer-preferences',
      token: token,
    ))['data'];
    final revision = data == null
        ? 0
        : data is Map
        ? int.tryParse('${data['revision']}')
        : null;
    if (revision == null || revision < 0)
      throw const FormatException('INVALID_CLOUD_REVISION');
    await _request(
      'PUT',
      '/v1/prayer-preferences',
      token: token,
      body: {
        'consent': 'prayer-preferences-v1',
        'revision': revision,
        'payload': PrayerBackup.encode(value),
      },
    );
  }

  Future<void> restorePrayerPreferences(PrayerSettingsStore store) async {
    final data = (await _request(
      'GET',
      '/v1/prayer-preferences',
      token: await _token(),
    ))['data'];
    if (data == null) throw StateError('CLOUD_BACKUP_EMPTY');
    final restored = PrayerBackup.decode(
      data is Map ? data['payload'] : null,
      store.value,
    );
    await store.restorePreferences(restored);
  }

  void close() => _client.close();
}
