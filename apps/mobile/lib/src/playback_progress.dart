import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local bounded progress, keyed by media identity, without URLs or credentials.
class PlaybackProgressStore {
  PlaybackProgressStore(this.preferences);
  final SharedPreferences preferences;
  static const key = 'playback:progress:v1';
  Map<String, dynamic> _read() {
    try {
      return Map<String, dynamic>.from(
        jsonDecode(preferences.getString(key) ?? '{}') as Map,
      );
    } catch (_) {
      return {};
    }
  }

  Duration position(String id, Duration? duration) {
    final item = _read()[id];
    final ms = item is Map ? item['ms'] : null;
    if (ms is! int ||
        ms < 5000 ||
        duration != null && ms >= duration.inMilliseconds - 3000)
      return Duration.zero;
    return Duration(milliseconds: ms);
  }

  Future<void> save(
    String id,
    Duration position, {
    bool completed = false,
  }) async {
    final values = _read()..remove(id);
    if (!completed && position.inSeconds >= 5)
      values[id] = {'ms': position.inMilliseconds};
    while (values.length > 80) {
      values.remove(values.keys.first);
    }
    await preferences.setString(key, jsonEncode(values));
  }
}
