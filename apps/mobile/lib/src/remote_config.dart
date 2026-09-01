import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'repository.dart';

/// Runtime configuration for content, flags and endpoints that may change
/// without shipping a new APK. It never downloads or executes Dart code.
class TarteelRemoteConfig extends ChangeNotifier {
  TarteelRemoteConfig(this._repository, this._preferences);

  static const _cacheKey = 'tarteel_remote_config:v1';
  final TarteelRepository _repository;
  final SharedPreferences _preferences;
  Map<String, dynamic> _values = <String, dynamic>{};
  bool _refreshing = false;

  bool get refreshing => _refreshing;
  Map<String, dynamic> get values => Map<String, dynamic>.unmodifiable(_values);

  bool get radioEnabled => boolValue('radio_enabled', fallback: true);
  bool get offlineDownloadsEnabled =>
      boolValue('offline_downloads_enabled', fallback: true);
  bool get mushafTajweedEnabled =>
      boolValue('mushaf_tajweed_enabled', fallback: true);
  bool get elysiaApiEnabled => boolValue('elysia_api_enabled', fallback: false);
  int get recitersPageSize =>
      intValue('reciters_page_size', fallback: 100).clamp(30, 300);
  String get elysiaApiBaseUrl => stringValue('elysia_api_base_url');
  String get contentManifestVersion =>
      stringValue('content_manifest_version', fallback: 'v1');
  String get minimumAndroidVersion =>
      stringValue('minimum_android_version', fallback: '0.0.0');
  String get latestAndroidVersion =>
      stringValue('latest_android_version', fallback: '0.0.0');

  void load() {
    final raw = _preferences.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _values = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Keep safe defaults when local cache is damaged.
    }
  }

  Future<void> refresh({bool notify = true}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (notify) notifyListeners();
    try {
      final incoming = await _repository.appConfig(refresh: true);
      _values = Map<String, dynamic>.from(incoming);
      await _preferences.setString(_cacheKey, jsonEncode(_values));
    } catch (_) {
      // Offline/stale startup must never block the application.
    } finally {
      _refreshing = false;
      if (notify) notifyListeners();
    }
  }

  bool boolValue(String key, {required bool fallback}) {
    final value = _unwrap(_values[key]);
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return fallback;
  }

  int intValue(String key, {required int fallback}) {
    final value = _unwrap(_values[key]);
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  String stringValue(String key, {String fallback = ''}) {
    final value = _unwrap(_values[key]);
    return value == null ? fallback : '$value';
  }

  dynamic _unwrap(dynamic value) {
    if (value is Map) {
      if (value.containsKey('value')) return _unwrap(value['value']);
      return value;
    }
    if (value is String) {
      final trimmed = value.trim();
      if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
          trimmed == 'true' ||
          trimmed == 'false' ||
          trimmed == 'null' ||
          num.tryParse(trimmed) != null) {
        try {
          return jsonDecode(trimmed);
        } catch (_) {}
      }
    }
    return value;
  }
}
