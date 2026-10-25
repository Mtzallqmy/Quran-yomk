import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'playback.dart';
import 'quran_audio.dart';

class QuranPlaybackSnapshot {
  const QuranPlaybackSnapshot({
    required this.provider,
    required this.reciterId,
    required this.edition,
    required this.reciterName,
    required this.bitrateKbps,
    required this.surahNumber,
    required this.position,
    required this.playedAt,
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
  final DateTime playedAt;

  bool get hasValidIdentity {
    final providerKind = quranAudioProviderFromPersistedName(provider);
    return providerKind != null &&
        validQuranReciterIdentityFields(
          provider: providerKind,
          reciterId: reciterId,
          edition: edition,
        ) &&
        surahNumber >= 1 &&
        surahNumber <= 114 &&
        (ayahNumber == null || ayahNumber! >= 1) &&
        bitrateKbps >= 0;
  }

  String get identityKey => <Object?>[
    'v1',
    provider,
    reciterId,
    edition,
    riwayah ?? '',
    surahNumber,
    ayahNumber ?? 0,
  ].map((value) => Uri.encodeComponent('$value')).join('|');

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
    'played_at': playedAt.toIso8601String(),
  };

  factory QuranPlaybackSnapshot.fromJson(Map<String, dynamic> json) {
    final playedAt = DateTime.tryParse(json['played_at'] as String? ?? '');
    if (playedAt == null) {
      throw const FormatException('QURAN_PLAYBACK_TIMESTAMP_INVALID');
    }
    final snapshot = QuranPlaybackSnapshot(
      provider: json['provider'] as String? ?? '',
      reciterId: json['reciter_id'] as String? ?? '',
      edition: json['edition'] as String? ?? '',
      reciterName: json['reciter_name'] as String? ?? '',
      riwayah: json['riwayah'] as String?,
      bitrateKbps: (json['bitrate_kbps'] as num?)?.toInt() ?? -1,
      surahNumber: (json['surah_number'] as num?)?.toInt() ?? 0,
      ayahNumber: (json['ayah_number'] as num?)?.toInt(),
      position: Duration(
        milliseconds: (json['position_ms'] as num?)?.toInt() ?? 0,
      ),
      playedAt: playedAt,
    );
    if (!snapshot.hasValidIdentity) {
      throw const FormatException('QURAN_PLAYBACK_IDENTITY_INVALID');
    }
    return snapshot;
  }
}

class QuranPlaybackStore extends ChangeNotifier {
  QuranPlaybackStore(this._preferences);

  static const _key = 'quran_playback:last:v2';
  static const _historyKey = 'quran_playback:history:v1';
  static const _historyLimit = 50;
  final SharedPreferences _preferences;
  StreamSubscription<MediaItem?>? _mediaSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  MediaItem? _currentItem;
  DateTime _lastPositionWrite = DateTime.fromMillisecondsSinceEpoch(0);

  QuranPlaybackSnapshot? last;
  List<QuranPlaybackSnapshot> _history = const <QuranPlaybackSnapshot>[];
  List<QuranPlaybackSnapshot> get history =>
      List<QuranPlaybackSnapshot>.unmodifiable(_history);

  void load() {
    final raw =
        _preferences.getString(_key) ??
        _preferences.getString('quran_playback:last:v1');
    if (raw != null && raw.isNotEmpty) {
      try {
        final value = jsonDecode(raw);
        if (value is Map) {
          last = QuranPlaybackSnapshot.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      } catch (_) {
        last = null;
      }
    }
    final historyRaw = _preferences.getString(_historyKey);
    if (historyRaw != null && historyRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(historyRaw);
        if (decoded is List<dynamic>) {
          final values = <QuranPlaybackSnapshot>[];
          for (final value in decoded) {
            if (value is! Map) continue;
            try {
              values.add(
                QuranPlaybackSnapshot.fromJson(
                  Map<String, dynamic>.from(value),
                ),
              );
            } catch (_) {
              // Reject only the malformed history row; never coerce its identity.
            }
            if (values.length >= _historyLimit) break;
          }
          _history = List<QuranPlaybackSnapshot>.unmodifiable(values);
        }
      } catch (_) {
        _history = const <QuranPlaybackSnapshot>[];
      }
    }
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
    final snapshot = QuranPlaybackSnapshot(
      provider: extras['provider'] as String? ?? '',
      reciterId: extras['reciter_id'] as String? ?? '',
      edition: extras['edition'] as String? ?? '',
      reciterName: _currentItem?.artist ?? '',
      riwayah: extras['riwayah'] as String?,
      bitrateKbps: extras['bitrate_kbps'] as int? ?? -1,
      surahNumber: extras['surah_number'] as int? ?? 0,
      ayahNumber: extras['ayah_number'] as int?,
      position: position,
      playedAt: DateTime.now(),
    );
    if (!snapshot.hasValidIdentity) return;
    last = snapshot;
    final next = <QuranPlaybackSnapshot>[
      snapshot,
      ..._history.where((entry) => entry.identityKey != snapshot.identityKey),
    ];
    _history = next.take(_historyLimit).toList(growable: false);
    await Future.wait<bool>([
      _preferences.setString(_key, jsonEncode(snapshot.toJson())),
      _preferences.setString(
        _historyKey,
        jsonEncode(_history.map((entry) => entry.toJson()).toList()),
      ),
    ]);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history = const <QuranPlaybackSnapshot>[];
    await _preferences.remove(_historyKey);
    notifyListeners();
  }

  @override
  void dispose() {
    _mediaSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
