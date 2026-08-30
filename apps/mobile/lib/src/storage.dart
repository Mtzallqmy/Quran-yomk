import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MetadataCache {
  MetadataCache(this._prefs);
  final SharedPreferences _prefs;

  dynamic read(String key, Duration maxAge) {
    final raw = _prefs.getString('cache:$key');
    final written = _prefs.getInt('cache:$key:written');
    if (raw == null || written == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - written;
    if (age > maxAge.inMilliseconds) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  dynamic readStale(String key) {
    final raw = _prefs.getString('cache:$key');
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, Object value) async {
    await _prefs.setString('cache:$key', jsonEncode(value));
    await _prefs.setInt(
      'cache:$key:written',
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class FavoritesStore extends ChangeNotifier {
  FavoritesStore(this._prefs);
  final SharedPreferences _prefs;
  final Set<String> stationIds = <String>{};
  final Set<String> reciterIds = <String>{};
  final Set<String> trackIds = <String>{};

  void load() {
    stationIds.addAll(
      _prefs.getStringList('favorites:stations') ?? const <String>[],
    );
    reciterIds.addAll(
      _prefs.getStringList('favorites:reciters') ?? const <String>[],
    );
    trackIds.addAll(
      _prefs.getStringList('favorites:tracks') ?? const <String>[],
    );
  }

  bool isStation(String id) => stationIds.contains(id);
  bool isReciter(String id) => reciterIds.contains(id);
  bool isTrack(String id) => trackIds.contains(id);

  Future<void> toggleStation(String id) =>
      _toggle(stationIds, id, 'favorites:stations');
  Future<void> toggleReciter(String id) =>
      _toggle(reciterIds, id, 'favorites:reciters');
  Future<void> toggleTrack(String id) =>
      _toggle(trackIds, id, 'favorites:tracks');

  Future<void> _toggle(Set<String> values, String id, String key) async {
    values.contains(id) ? values.remove(id) : values.add(id);
    await _prefs.setStringList(key, values.toList(growable: false));
    notifyListeners();
  }
}

class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs);
  final SharedPreferences _prefs;
  ThemeMode themeMode = ThemeMode.system;
  Locale locale = const Locale('ar');
  double playbackSpeed = 1.0;

  void load() {
    themeMode = switch (_prefs.getString('settings:theme')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    locale = Locale(_prefs.getString('settings:locale') == 'en' ? 'en' : 'ar');
    playbackSpeed = _prefs.getDouble('settings:speed') ?? 1.0;
  }

  Future<void> setThemeMode(ThemeMode value) async {
    themeMode = value;
    await _prefs.setString('settings:theme', value.name);
    notifyListeners();
  }

  Future<void> setLocale(Locale value) async {
    locale = value.languageCode == 'en'
        ? const Locale('en')
        : const Locale('ar');
    await _prefs.setString('settings:locale', locale.languageCode);
    notifyListeners();
  }

  Future<void> setPlaybackSpeed(double value) async {
    playbackSpeed = value.clamp(0.75, 2.0);
    await _prefs.setDouble('settings:speed', playbackSpeed);
    notifyListeners();
  }
}
