import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'quran_audio.dart';

class QuranPlaylistEntry {
  const QuranPlaylistEntry({
    required this.id,
    required this.reciter,
    required this.surah,
    required this.bitrateKbps,
  });

  final String id;
  final QuranAudioCatalogReciter reciter;
  final Surah surah;
  final int bitrateKbps;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'bitrate_kbps': bitrateKbps,
    'surah': surah.toJson(),
    'reciter': <String, dynamic>{
      'id': reciter.id,
      'provider': reciter.provider.name,
      'edition': reciter.edition,
      'name_ar': reciter.nameAr,
      'name_en': reciter.nameEn,
      'riwayah': reciter.riwayah,
      'server_url': reciter.serverUrl,
      'available_surahs': reciter.availableSurahs.toList(),
      'bitrates': reciter.bitrates.toList(),
      'supports_ayah_audio': reciter.supportsAyahAudio,
    },
  };

  factory QuranPlaylistEntry.fromJson(Map<String, dynamic> json) {
    final rawValue = json['reciter'];
    if (rawValue is! Map)
      throw const FormatException('QURAN_PLAYLIST_RECITER_MISSING');
    final raw = Map<String, dynamic>.from(rawValue);
    final provider = quranAudioProviderFromPersistedName(
      raw['provider'] as String?,
    );
    if (provider == null) {
      throw const FormatException('QURAN_PLAYLIST_PROVIDER_INVALID');
    }
    final reciter = QuranAudioCatalogReciter(
      id: raw['id'] as String? ?? '',
      provider: provider,
      edition: raw['edition'] as String? ?? '',
      nameAr: raw['name_ar'] as String? ?? '',
      nameEn: raw['name_en'] as String? ?? '',
      riwayah: raw['riwayah'] as String?,
      serverUrl: raw['server_url'] as String?,
      availableSurahs:
          (raw['available_surahs'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<num>()
              .map((e) => e.toInt())
              .where((e) => e >= 1 && e <= 114)
              .toSet(),
      bitrates: (raw['bitrates'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<num>()
          .map((e) => e.toInt())
          .where((e) => e >= 0)
          .toSet(),
      supportsAyahAudio: raw['supports_ayah_audio'] == true,
    );
    if (!reciter.hasValidIdentity) {
      throw const FormatException('QURAN_PLAYLIST_RECITER_IDENTITY_INVALID');
    }
    final surahValue = json['surah'];
    if (surahValue is! Map)
      throw const FormatException('QURAN_PLAYLIST_SURAH_MISSING');
    final surah = Surah.fromJson(Map<String, dynamic>.from(surahValue));
    if (surah.number < 1 || surah.number > 114) {
      throw const FormatException('QURAN_PLAYLIST_SURAH_INVALID');
    }
    final id = json['id'] as String? ?? '';
    if (id.isEmpty)
      throw const FormatException('QURAN_PLAYLIST_ENTRY_ID_INVALID');
    return QuranPlaylistEntry(
      id: id,
      bitrateKbps: (json['bitrate_kbps'] as num?)?.toInt() ?? 128,
      surah: surah,
      reciter: reciter,
    );
  }
}

class QuranPlaylist {
  const QuranPlaylist({
    required this.id,
    required this.name,
    required this.entries,
  });

  final String id;
  final String name;
  final List<QuranPlaylistEntry> entries;

  QuranPlaylist copyWith({String? name, List<QuranPlaylistEntry>? entries}) =>
      QuranPlaylist(
        id: id,
        name: name ?? this.name,
        entries: entries ?? this.entries,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory QuranPlaylist.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final name = json['name'] as String? ?? '';
    if (id.isEmpty || name.trim().isEmpty) {
      throw const FormatException('QURAN_PLAYLIST_IDENTITY_INVALID');
    }
    final entries = <QuranPlaylistEntry>[];
    final rawEntries = json['entries'];
    if (rawEntries is List<dynamic>) {
      for (final value in rawEntries) {
        if (value is! Map) continue;
        try {
          entries.add(
            QuranPlaylistEntry.fromJson(Map<String, dynamic>.from(value)),
          );
        } catch (_) {
          // Fail closed for the invalid entry. A malformed identity must never
          // become a playable entry or be coerced to another provider.
        }
      }
    }
    return QuranPlaylist(
      id: id,
      name: name,
      entries: List.unmodifiable(entries),
    );
  }
}

class QuranPlaylistStore extends ChangeNotifier {
  QuranPlaylistStore(this._preferences);

  static const _key = 'quran_playlists:v1';
  final SharedPreferences _preferences;
  List<QuranPlaylist> _playlists = const <QuranPlaylist>[];

  List<QuranPlaylist> get playlists =>
      List<QuranPlaylist>.unmodifiable(_playlists);

  void load() {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        final values = <QuranPlaylist>[];
        for (final value in decoded) {
          if (value is! Map) continue;
          try {
            values.add(
              QuranPlaylist.fromJson(Map<String, dynamic>.from(value)),
            );
          } catch (_) {
            // Preserve valid playlists while rejecting malformed persisted data.
          }
        }
        _playlists = List<QuranPlaylist>.unmodifiable(values);
      }
    } catch (_) {
      _playlists = const <QuranPlaylist>[];
    }
  }

  Future<QuranPlaylist> create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name');
    final playlist = QuranPlaylist(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      entries: const <QuranPlaylistEntry>[],
    );
    _playlists = <QuranPlaylist>[..._playlists, playlist];
    await _persist();
    return playlist;
  }

  Future<void> delete(String id) async {
    _playlists = _playlists.where((e) => e.id != id).toList(growable: false);
    await _persist();
  }

  Future<void> add(String playlistId, QuranAudioMedia media) async {
    if (!media.hasValidIdentity) {
      throw StateError('QURAN_PLAYLIST_MEDIA_IDENTITY_INVALID');
    }
    final index = _playlists.indexWhere((e) => e.id == playlistId);
    if (index < 0) throw StateError('PLAYLIST_NOT_FOUND');
    final playlist = _playlists[index];
    final entryId =
        '${media.reciter.identityKey}|${media.surah.number}|${media.bitrateKbps}';
    if (playlist.entries.any((e) => e.id == entryId)) return;
    final entry = QuranPlaylistEntry(
      id: entryId,
      reciter: media.reciter,
      surah: media.surah,
      bitrateKbps: media.bitrateKbps,
    );
    _replace(
      index,
      playlist.copyWith(
        entries: <QuranPlaylistEntry>[...playlist.entries, entry],
      ),
    );
    await _persist();
  }

  Future<void> remove(String playlistId, String entryId) async {
    final index = _playlists.indexWhere((e) => e.id == playlistId);
    if (index < 0) return;
    final playlist = _playlists[index];
    _replace(
      index,
      playlist.copyWith(
        entries: playlist.entries
            .where((e) => e.id != entryId)
            .toList(growable: false),
      ),
    );
    await _persist();
  }

  Future<void> reorder(String playlistId, int oldIndex, int newIndex) async {
    final index = _playlists.indexWhere((e) => e.id == playlistId);
    if (index < 0) return;
    final entries = List<QuranPlaylistEntry>.from(_playlists[index].entries);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = entries.removeAt(oldIndex);
    entries.insert(newIndex, item);
    _replace(index, _playlists[index].copyWith(entries: entries));
    await _persist();
  }

  void _replace(int index, QuranPlaylist value) {
    final next = List<QuranPlaylist>.from(_playlists);
    next[index] = value;
    _playlists = List<QuranPlaylist>.unmodifiable(next);
  }

  Future<void> _persist() async {
    await _preferences.setString(
      _key,
      jsonEncode(_playlists.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }
}
