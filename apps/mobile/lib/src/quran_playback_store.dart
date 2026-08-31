import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'playback.dart';

class QuranPlaybackSnapshot {
  const QuranPlaybackSnapshot({
    required this.provider,
    required this.reciterId,
    required this.edition,
    required this.reciterName,
    required this.bitrateKbps,
    required this.surahNumber,
    required this.position,
    this.riwayah,
    this.ayahNumber,
  });

  final String provider;
  final String reciterId;
  final String edition;
  final String reciterName;
  final String? riwayah;
  final int bitrateKbps;
  final int surahNumber;
  final int? ayahNumber;
  final Duration position;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'provider': provider,
    'reciter_id': reciterId,
    'edition': edition,
    'reciter_name': reciterName,
    'riwayah': riwayah,
    'bitrate_kbps': bitrateKbps,
    'surah_number': surahNumber,
    'ayah_number': ayahNumber,
    'position_ms': position.inMilliseconds,
  };

  factory QuranPlaybackSnapshot.fromJson(Map<String, dynamic> json) =>
      QuranPlaybackSnapshot(
        provider: json['provider'] as String? ?? '',
        reciterId: json['reciter_id'] as String? ?? '',
        edition: json['edition'] as String? ?? '',
        reciterName: json['reciter_name'] as String? ?? '',
        riwayah: json['riwayah'] as String?,
        bitrateKbps: (json['bitrate_kbps'] as num?)?.toInt() ?? 128,
        surahNumber: (json['surah_number'] as num?)?.toInt() ?? 1,
        ayahNumber: (json['ayah_number'] as num?)?.toInt(),
        position: Duration(
          milliseconds: (json['position_ms'] as num?)?.toInt() ?? 0,
        ),
      );
}

class QuranPlaybackStore extends ChangeNotifier {
  QuranPlaybackStore(this._preferences);

  static const _key = 'quran_playback:last:v1';
  final SharedPreferences _preferences;
  StreamSubscription<MediaItem?>? _mediaSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  MediaItem? _currentItem;
  DateTime _lastPositionWrite = DateTime.fromMillisecondsSinceEpoch(0);

  QuranPlaybackSnapshot? last;

  void load() {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final value = jsonDecode(raw);
      if (value is Map) {
        last = QuranPlaybackSnapshot.fromJson(Map<String, dynamic>.from(value));
      }
    } catch (_) {}
  }

  void bind(PlaybackPort playback) {
    _mediaSubscription?.cancel();
    _positionSubscription?.cancel();
    _mediaSubscription = playback.mediaItemStream.listen((item) {
      _currentItem = item?.extras?['kind'] == 'quran_audio' ? item : null;
      if (_currentItem != null) unawaited(_save(Duration.zero));
    });
    _positionSubscription = playback.positionStream.listen((position) {
      if (_currentItem == null ||
          DateTime.now().difference(_lastPositionWrite) <
              const Duration(seconds: 5)) {
        return;
      }
      _lastPositionWrite = DateTime.now();
      unawaited(_save(position));
    });
  }

  Future<void> _save(Duration position) async {
    final extras = _currentItem?.extras;
    if (extras == null) return;
    last = QuranPlaybackSnapshot(
      provider: extras['provider'] as String? ?? '',
      reciterId: extras['reciter_id'] as String? ?? '',
      edition: extras['edition'] as String? ?? '',
      reciterName: _currentItem?.artist ?? '',
      riwayah: extras['riwayah'] as String?,
      bitrateKbps: extras['bitrate_kbps'] as int? ?? 0,
      surahNumber: extras['surah_number'] as int? ?? 1,
      ayahNumber: extras['ayah_number'] as int?,
      position: position,
    );
    await _preferences.setString(_key, jsonEncode(last!.toJson()));
    notifyListeners();
  }

  @override
  void dispose() {
    _mediaSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
