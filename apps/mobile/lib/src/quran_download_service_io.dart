import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'quran_audio.dart';
import 'quran_download_contract.dart';

QuranDownloadService createQuranDownloadService(
  SharedPreferences preferences, {
  Duration inactivityTimeout = const Duration(seconds: 20),
  Duration downloadDeadline = const Duration(minutes: 30),
}) => _IoQuranDownloadService(preferences, inactivityTimeout, downloadDeadline);

class _IoQuranDownloadService extends QuranDownloadService {
  _IoQuranDownloadService(
    this._preferences,
    this._inactivityTimeout,
    this._downloadDeadline,
  );

  final Duration _inactivityTimeout;
  final Duration _downloadDeadline;

  static const _metadataKey = 'quran_audio_downloads:v1';
  static const _minimumAudioBytes = 4096;

  final SharedPreferences _preferences;
  final List<_TaskRecord> _records = <_TaskRecord>[];
  StreamSubscription<List<int>>? _activeSubscription;
  Completer<void>? _activeDone;
  IOSink? _activeSink;
  HttpClient? _activeClient;
  String? _activeId;
  bool _pumping = false;

  @override
  bool get supported => true;

  @override
  List<QuranDownloadTask> get tasks => List<QuranDownloadTask>.unmodifiable(
    _records.map((record) => record.snapshot),
  );

  @override
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void>? _initialization;

  Future<void> _initialize() async {
    final raw = _preferences.getString(_metadataKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List<dynamic>) {
          for (final value in decoded.whereType<Map<Object?, Object?>>()) {
            try {
              final record = _TaskRecord.fromJson(
                Map<String, dynamic>.from(value),
              );
              if (record.state == QuranDownloadState.downloading ||
                  record.state == QuranDownloadState.queued) {
                record.state = QuranDownloadState.paused;
              }
              if (record.state == QuranDownloadState.completed &&
                  !(await File(record.localPath).exists())) {
                record.state = QuranDownloadState.failed;
                record.error = 'LOCAL_FILE_MISSING';
              }
              _records.add(record);
            } catch (_) {
              // Fail closed for the malformed record only. Never coerce provider
              // identity and never discard unrelated valid downloads.
            }
          }
        }
      } catch (_) {
        _records.clear();
      }
    }
    await _persist();
    notifyListeners();
  }

  @override
  Future<QuranDownloadTask> download(QuranAudioMedia media) async {
    await initialize();
    if (!media.hasValidIdentity ||
        media.downloadUri.scheme != 'https' ||
        media.provider != media.reciter.provider) {
      throw StateError('QURAN_DOWNLOAD_IDENTITY_INVALID');
    }
    final existing = _records
        .where((record) => record.media.storageKey == media.storageKey)
        .firstOrNull;
    if (existing != null) {
      if (existing.state == QuranDownloadState.completed &&
          await _validCompleted(existing)) {
        return existing.snapshot;
      }
      if (existing.state != QuranDownloadState.downloading &&
          existing.state != QuranDownloadState.queued) {
        existing.state = QuranDownloadState.queued;
        existing.error = null;
        await _persistAndNotify();
        unawaited(_pump());
      }
      return existing.snapshot;
    }

    final root = await getApplicationDocumentsDirectory();
    final safeEdition = media.reciter.edition.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
    final identityDigest = sha256
        .convert(utf8.encode(media.reciter.identityKey))
        .toString()
        .substring(0, 24);
    final directory = Directory(
      '${root.path}/quran_audio/${media.provider.name}/$safeEdition-$identityDigest/${media.bitrateKbps}',
    );
    await directory.create(recursive: true);
    final suffix = media.ayahGlobalNumber == null
        ? 'surah-${media.surah.number.toString().padLeft(3, '0')}'
        : 'ayah-${media.ayahGlobalNumber}';
    final id =
        '${media.provider.name}-$identityDigest-${media.bitrateKbps}-$suffix';
    final record = _TaskRecord(
      id: id,
      media: media,
      state: QuranDownloadState.queued,
      downloadedBytes: 0,
      totalBytes: media.expectedSize,
      createdAt: DateTime.now(),
      localPath: '${directory.path}/$suffix.mp3',
    );
    _records.add(record);
    await _persistAndNotify();
    unawaited(_pump());
    return record.snapshot;
  }

  @override
  Future<List<QuranDownloadTask>> downloadMany(
    Iterable<QuranAudioMedia> media,
  ) async {
    final result = <QuranDownloadTask>[];
    for (final item in media) {
      result.add(await download(item));
    }
    return result;
  }

  Future<void> _pump() async {
    if (_pumping || _activeId != null) return;
    _pumping = true;
    try {
      while (_activeId == null) {
        final record = _records
            .where((value) => value.state == QuranDownloadState.queued)
            .firstOrNull;
        if (record == null) break;
        await _run(record);
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _run(_TaskRecord record) async {
    if (!record.media.hasValidIdentity) {
      record.state = QuranDownloadState.failed;
      record.error = 'QURAN_DOWNLOAD_IDENTITY_INVALID';
      await _persistAndNotify();
      return;
    }
    _activeId = record.id;
    record.state = QuranDownloadState.downloading;
    record.error = null;
    await _persistAndNotify();
    final partial = File('${record.localPath}.part');
    var offset = await partial.exists() ? await partial.length() : 0;
    final elapsed = Stopwatch()..start();
    Duration remainingTime() {
      final remaining = _downloadDeadline - elapsed.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('QURAN_DOWNLOAD_TIMEOUT');
      }
      return remaining;
    }

    try {
      _activeClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final request = await _activeClient!
          .getUrl(record.media.downloadUri)
          .timeout(remainingTime());
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'audio/mpeg,*/*;q=0.1');
      if (offset > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
      }
      final budget = remainingTime();
      final headerTimeout = budget < const Duration(seconds: 20)
          ? budget
          : const Duration(seconds: 20);
      final response = await request.close().timeout(headerTimeout);
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        throw HttpException(
          'HTTP_${response.statusCode}',
          uri: record.media.downloadUri,
        );
      }
      if (offset > 0 && response.statusCode == HttpStatus.ok) {
        await partial.writeAsBytes(const <int>[], flush: true);
        offset = 0;
      }
      final contentType = response.headers.contentType?.mimeType.toLowerCase();
      if (contentType != null &&
          contentType.isNotEmpty &&
          contentType != 'application/octet-stream' &&
          !contentType.startsWith('audio/')) {
        throw StateError('QURAN_DOWNLOAD_NOT_AUDIO');
      }
      final remaining = response.contentLength;
      record.totalBytes = remaining > 0
          ? offset + remaining
          : record.media.expectedSize;
      record.downloadedBytes = offset;
      _activeSink = partial.openWrite(
        mode: offset > 0 ? FileMode.append : FileMode.writeOnly,
      );
      final done = Completer<void>();
      _activeDone = done;
      final stream = response.timeout(_inactivityTimeout);
      _activeSubscription = stream.listen(
        (chunk) {
          record.downloadedBytes += chunk.length;
          _activeSink?.add(chunk);
          notifyListeners();
        },
        onError: (Object error, StackTrace stack) {
          if (!done.isCompleted) done.completeError(error, stack);
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
      await done.future.timeout(remainingTime());
      await _closeActive();
      if (record.state != QuranDownloadState.downloading) return;

      final length = await partial.length();
      if (length < _minimumAudioBytes) {
        throw StateError('QURAN_DOWNLOAD_TOO_SMALL');
      }
      if (record.totalBytes != null && length != record.totalBytes) {
        throw StateError('QURAN_DOWNLOAD_SIZE_MISMATCH');
      }
      final digest = await sha256.bind(partial.openRead()).first;
      final checksum = digest.toString();
      final expected = record.media.checksumSha256?.toLowerCase();
      if (expected != null && expected.isNotEmpty && checksum != expected) {
        throw StateError('QURAN_DOWNLOAD_CHECKSUM_MISMATCH');
      }
      final destination = File(record.localPath);
      if (await destination.exists()) await destination.delete();
      await partial.rename(record.localPath);
      record.actualChecksumSha256 = checksum;
      record.downloadedBytes = length;
      record.totalBytes = length;
      record.state = QuranDownloadState.completed;
      record.error = null;
    } catch (error) {
      await _closeActive();
      if (record.state == QuranDownloadState.downloading) {
        record.state = QuranDownloadState.failed;
        record.error = error is TimeoutException
            ? 'QURAN_DOWNLOAD_TIMEOUT'
            : error.toString();
        if (await partial.exists()) await partial.delete();
        record.downloadedBytes = 0;
      }
    } finally {
      elapsed.stop();
      _activeId = null;
      await _persistAndNotify();
    }
  }

  Future<void> _closeActive() async {
    _activeClient?.close(force: true);
    _activeClient = null;
    await _activeSubscription?.cancel();
    _activeSubscription = null;
    if (_activeDone case final done? when !done.isCompleted) {
      done.complete();
    }
    _activeDone = null;
    try {
      await _activeSink?.flush();
      await _activeSink?.close();
    } catch (_) {}
    _activeSink = null;
  }

  @override
  Future<void> pause(String taskId) async {
    await initialize();
    final record = _find(taskId);
    if (record == null) return;
    if (record.state == QuranDownloadState.queued) {
      record.state = QuranDownloadState.paused;
    } else if (_activeId == taskId &&
        record.state == QuranDownloadState.downloading) {
      record.state = QuranDownloadState.paused;
      await _closeActive();
      _activeId = null;
    }
    await _persistAndNotify();
    unawaited(_pump());
  }

  @override
  Future<void> resume(String taskId) async {
    await initialize();
    final record = _find(taskId);
    if (record == null || record.state == QuranDownloadState.completed) return;
    if (!record.media.hasValidIdentity) {
      record.state = QuranDownloadState.failed;
      record.error = 'QURAN_DOWNLOAD_IDENTITY_INVALID';
      await _persistAndNotify();
      return;
    }
    record.state = QuranDownloadState.queued;
    record.error = null;
    await _persistAndNotify();
    unawaited(_pump());
  }

  @override
  Future<void> retry(String taskId) => resume(taskId);

  @override
  Future<void> cancel(String taskId) async {
    await initialize();
    final record = _find(taskId);
    if (record == null) return;
    record.state = QuranDownloadState.cancelled;
    if (_activeId == taskId) {
      await _closeActive();
      _activeId = null;
    }
    final partial = File('${record.localPath}.part');
    if (await partial.exists()) await partial.delete();
    await _persistAndNotify();
    unawaited(_pump());
  }

  @override
  Future<void> delete(String taskId) async {
    await initialize();
    final record = _find(taskId);
    if (record == null) return;
    if (_activeId == taskId) await cancel(taskId);
    for (final path in <String>[record.localPath, '${record.localPath}.part']) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    _records.remove(record);
    await _persistAndNotify();
  }

  @override
  Future<QuranAudioMedia?> localMedia(QuranAudioMedia remote) async {
    await initialize();
    if (!remote.hasValidIdentity) return null;
    final record = _records
        .where(
          (value) =>
              value.media.storageKey == remote.storageKey &&
              value.media.sameTrackIdentity(remote) &&
              value.state == QuranDownloadState.completed,
        )
        .firstOrNull;
    if (record == null || !await _validCompleted(record)) return null;
    final local = remote.asLocal(
      record.localPath,
      checksum: record.actualChecksumSha256,
      size: record.totalBytes,
    );
    return local.sameTrackIdentity(remote) ? local : null;
  }

  Future<bool> _validCompleted(_TaskRecord record) async {
    if (!record.media.hasValidIdentity) return false;
    final file = File(record.localPath);
    if (!await file.exists()) return false;
    final length = await file.length();
    if (length < _minimumAudioBytes ||
        (record.totalBytes != null && length != record.totalBytes)) {
      return false;
    }
    final expected = record.actualChecksumSha256;
    if (expected == null || expected.isEmpty) return false;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == expected;
  }

  _TaskRecord? _find(String id) =>
      _records.where((record) => record.id == id).firstOrNull;

  Future<void> _persistAndNotify() async {
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() => _preferences.setString(
    _metadataKey,
    jsonEncode(_records.map((record) => record.toJson()).toList()),
  );
}

class _TaskRecord {
  _TaskRecord({
    required this.id,
    required this.media,
    required this.state,
    required this.downloadedBytes,
    required this.createdAt,
    required this.localPath,
    this.totalBytes,
    this.actualChecksumSha256,
    this.error,
  });

  final String id;
  final QuranAudioMedia media;
  QuranDownloadState state;
  int downloadedBytes;
  int? totalBytes;
  final DateTime createdAt;
  final String localPath;
  String? actualChecksumSha256;
  String? error;

  QuranDownloadTask get snapshot => QuranDownloadTask(
    id: id,
    media: media,
    state: state,
    downloadedBytes: downloadedBytes,
    totalBytes: totalBytes,
    createdAt: createdAt,
    localPath: localPath,
    actualChecksumSha256: actualChecksumSha256,
    error: error,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'state': state.name,
    'downloaded_bytes': downloadedBytes,
    'total_bytes': totalBytes,
    'created_at': createdAt.toIso8601String(),
    'local_path': localPath,
    'actual_checksum_sha256': actualChecksumSha256,
    'error': error,
    'media': _mediaToJson(media),
  };

  factory _TaskRecord.fromJson(Map<String, dynamic> json) {
    final mediaValue = json['media'];
    if (mediaValue is! Map) {
      throw const FormatException('QURAN_DOWNLOAD_MEDIA_MISSING');
    }
    final media = _mediaFromJson(Map<String, dynamic>.from(mediaValue));
    final id = json['id'] as String? ?? '';
    final localPath = json['local_path'] as String? ?? '';
    final createdAt = DateTime.tryParse(json['created_at'] as String? ?? '');
    if (id.isEmpty ||
        localPath.isEmpty ||
        createdAt == null ||
        !media.hasValidIdentity) {
      throw const FormatException('QURAN_DOWNLOAD_RECORD_IDENTITY_INVALID');
    }
    return _TaskRecord(
      id: id,
      media: media,
      state: QuranDownloadState.values.firstWhere(
        (value) => value.name == json['state'],
        orElse: () => QuranDownloadState.failed,
      ),
      downloadedBytes: (json['downloaded_bytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['total_bytes'] as num?)?.toInt(),
      createdAt: createdAt,
      localPath: localPath,
      actualChecksumSha256: json['actual_checksum_sha256'] as String?,
      error: json['error'] as String?,
    );
  }
}

Map<String, dynamic> _mediaToJson(QuranAudioMedia media) => <String, dynamic>{
  'id': media.id,
  'provider': media.provider.name,
  'bitrate_kbps': media.bitrateKbps,
  'ayah_global_number': media.ayahGlobalNumber,
  'ayah_in_surah': media.ayahInSurah,
  'playback_uri': media.playbackUri.toString(),
  'download_uri': media.downloadUri.toString(),
  'expected_size': media.expectedSize,
  'checksum_sha256': media.checksumSha256,
  'rehosting_allowed': media.rehostingAllowed,
  'rights_status': media.rightsStatus,
  'reciter': <String, dynamic>{
    'id': media.reciter.id,
    'provider': media.reciter.provider.name,
    'edition': media.reciter.edition,
    'name_ar': media.reciter.nameAr,
    'name_en': media.reciter.nameEn,
    'riwayah': media.reciter.riwayah,
    'server_url': media.reciter.serverUrl,
    'available_surahs': media.reciter.availableSurahs.toList(),
    'bitrates': media.reciter.bitrates.toList(),
    'supports_ayah_audio': media.reciter.supportsAyahAudio,
  },
  'surah': media.surah.toJson(),
};

QuranAudioMedia _mediaFromJson(Map<String, dynamic> json) {
  final reciterValue = json['reciter'];
  if (reciterValue is! Map) {
    throw const FormatException('QURAN_DOWNLOAD_RECITER_MISSING');
  }
  final reciterJson = Map<String, dynamic>.from(reciterValue);
  final reciterProvider = quranAudioProviderFromPersistedName(
    reciterJson['provider'] as String?,
  );
  final mediaProvider = quranAudioProviderFromPersistedName(
    json['provider'] as String?,
  );
  if (reciterProvider == null ||
      mediaProvider == null ||
      reciterProvider != mediaProvider) {
    throw const FormatException('QURAN_DOWNLOAD_PROVIDER_IDENTITY_INVALID');
  }
  final reciter = QuranAudioCatalogReciter(
    id: reciterJson['id'] as String? ?? '',
    provider: reciterProvider,
    edition: reciterJson['edition'] as String? ?? '',
    nameAr: reciterJson['name_ar'] as String? ?? '',
    nameEn: reciterJson['name_en'] as String? ?? '',
    riwayah: reciterJson['riwayah'] as String?,
    serverUrl: reciterJson['server_url'] as String?,
    availableSurahs: (reciterJson['available_surahs'] as List? ?? const [])
        .whereType<num>()
        .map((value) => value.toInt())
        .where((value) => value >= 1 && value <= 114)
        .toSet(),
    bitrates: (reciterJson['bitrates'] as List? ?? const [])
        .whereType<num>()
        .map((value) => value.toInt())
        .where((value) => value >= 0)
        .toSet(),
    supportsAyahAudio: reciterJson['supports_ayah_audio'] == true,
  );
  if (!reciter.hasValidIdentity) {
    throw const FormatException('QURAN_DOWNLOAD_RECITER_IDENTITY_INVALID');
  }
  final surahValue = json['surah'];
  if (surahValue is! Map) {
    throw const FormatException('QURAN_DOWNLOAD_SURAH_MISSING');
  }
  final playbackUri = Uri.tryParse(json['playback_uri'] as String? ?? '');
  final downloadUri = Uri.tryParse(json['download_uri'] as String? ?? '');
  if (playbackUri == null ||
      downloadUri == null ||
      downloadUri.scheme != 'https' ||
      (playbackUri.scheme != 'https' && playbackUri.scheme != 'file')) {
    throw const FormatException('QURAN_DOWNLOAD_URI_INVALID');
  }
  final media = QuranAudioMedia(
    id: json['id'] as String? ?? '',
    provider: mediaProvider,
    reciter: reciter,
    surah: Surah.fromJson(Map<String, dynamic>.from(surahValue)),
    bitrateKbps: (json['bitrate_kbps'] as num?)?.toInt() ?? 0,
    ayahGlobalNumber: (json['ayah_global_number'] as num?)?.toInt(),
    ayahInSurah: (json['ayah_in_surah'] as num?)?.toInt(),
    playbackUri: playbackUri,
    downloadUri: downloadUri,
    expectedSize: (json['expected_size'] as num?)?.toInt(),
    checksumSha256: json['checksum_sha256'] as String?,
    rehostingAllowed: json['rehosting_allowed'] == true,
    rightsStatus: json['rights_status'] as String? ?? 'UNKNOWN',
  );
  if (!media.hasValidIdentity) {
    throw const FormatException('QURAN_DOWNLOAD_MEDIA_IDENTITY_INVALID');
  }
  return media;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
