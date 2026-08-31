import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'offline_clip_contract.dart';

OfflineClipService createOfflineClipService(SharedPreferences preferences) =>
    _IoOfflineClipService(preferences);

class _IoOfflineClipService extends OfflineClipService {
  _IoOfflineClipService(this._preferences);

  static const _metadataKey = 'offline_clips:v1';
  static const _minimumUsefulBytes = 8192;

  final SharedPreferences _preferences;
  final List<OfflineClip> _clips = <OfflineClip>[];

  HttpClient? _client;
  StreamSubscription<List<int>>? _subscription;
  IOSink? _sink;
  Timer? _limitTimer;
  Timer? _progressTimer;
  DateTime? _startedAt;
  Station? _station;
  String? _filePath;
  String? _format;
  int _bytes = 0;
  bool _finishing = false;
  String? _lastError;

  @override
  bool get supported => true;
  @override
  List<OfflineClip> get clips => List<OfflineClip>.unmodifiable(_clips);
  @override
  String? get activeStationId => _station?.id;
  @override
  Duration get activeElapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);
  @override
  int get activeBytes => _bytes;
  @override
  String? get lastError => _lastError;

  @override
  Future<void> initialize() async {
    final raw = _preferences.getString(_metadataKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final value in decoded) {
        if (value is! Map) continue;
        final clip = OfflineClip.fromJson(Map<String, dynamic>.from(value));
        if (await File(clip.filePath).exists()) _clips.add(clip);
      }
      _clips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      // Corrupt local metadata must not break application startup.
    }
    await _persist();
    notifyListeners();
  }

  @override
  Future<void> start({
    required Station station,
    required OfflineClipPolicy policy,
    Duration? maxDuration,
  }) async {
    if (_station != null) throw StateError('OFFLINE_CLIP_ALREADY_RECORDING');
    if (!policy.allowed || !policy.supportedStream) {
      throw StateError('OFFLINE_CLIP_NOT_ALLOWED');
    }
    final type = station.streamType.toUpperCase();
    if (type != 'MP3_STREAM' && type != 'AAC_STREAM') {
      throw StateError('OFFLINE_CLIP_STREAM_UNSUPPORTED');
    }
    final uri = Uri.tryParse(station.playbackUrl ?? '');
    if (uri == null || uri.scheme.toLowerCase() != 'https') {
      throw StateError('OFFLINE_CLIP_STREAM_INSECURE');
    }

    _lastError = null;
    _bytes = 0;
    _startedAt = DateTime.now();
    _station = station;
    _format = type == 'MP3_STREAM' ? 'mp3' : 'aac';

    try {
      final root = await getApplicationDocumentsDirectory();
      final directory = Directory('${root.path}/offline_clips');
      await directory.create(recursive: true);
      final id =
          '${_startedAt!.millisecondsSinceEpoch}_${station.id.replaceAll('-', '').substring(0, 8)}';
      _filePath = '${directory.path}/$id.${_format!}';
      _sink = File(_filePath!).openWrite(mode: FileMode.writeOnly);

      _client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
      final request = await _client!.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set(
        HttpHeaders.acceptHeader,
        'audio/mpeg,audio/aac,audio/aacp,*/*;q=0.1',
      );
      request.headers.set('Icy-MetaData', '0');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP_${response.statusCode}', uri: uri);
      }
      final mime = response.headers.contentType?.mimeType.toLowerCase();
      if (!_mimeCompatible(mime, type)) {
        throw StateError('OFFLINE_CLIP_CONTENT_UNSUPPORTED');
      }

      _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        notifyListeners();
      });
      if (maxDuration != null) {
        _limitTimer = Timer(maxDuration, () {
          unawaited(stop());
        });
      }

      _subscription = response.listen(
        (chunk) {
          _bytes += chunk.length;
          _sink?.add(chunk);
        },
        onError: (Object error, StackTrace stack) {
          _lastError = 'انقطع الاتصال أثناء حفظ المقطع';
          unawaited(_finish(partial: true));
        },
        onDone: () => unawaited(_finish(partial: false)),
        cancelOnError: true,
      );
      notifyListeners();
    } catch (error) {
      _lastError = 'تعذر بدء حفظ المقطع';
      await _discardActive();
      rethrow;
    }
  }

  bool _mimeCompatible(String? mime, String type) {
    if (mime == null || mime.isEmpty || mime == 'application/octet-stream') {
      return true; // Normalized stream type remains the available evidence.
    }
    if (type == 'MP3_STREAM') {
      return mime == 'audio/mpeg' || mime == 'audio/mp3';
    }
    return mime == 'audio/aac' || mime == 'audio/aacp' || mime == 'audio/x-aac';
  }

  @override
  Future<OfflineClip?> stop() async {
    if (_station == null) return null;
    await _subscription?.cancel();
    return _finish(partial: false);
  }

  Future<OfflineClip?> _finish({required bool partial}) async {
    if (_finishing ||
        _station == null ||
        _startedAt == null ||
        _filePath == null) {
      return null;
    }
    _finishing = true;
    final station = _station!;
    final startedAt = _startedAt!;
    final path = _filePath!;
    final format = _format ?? 'mp3';
    final duration = DateTime.now().difference(startedAt);

    _limitTimer?.cancel();
    _progressTimer?.cancel();
    _limitTimer = null;
    _progressTimer = null;
    _subscription = null;
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {}
    _sink = null;
    _client?.close(force: true);
    _client = null;

    OfflineClip? clip;
    final file = File(path);
    final length = await file.exists() ? await file.length() : 0;
    if (length >= _minimumUsefulBytes) {
      clip = OfflineClip(
        id: path.split(Platform.pathSeparator).last.split('.').first,
        stationId: station.id,
        stationNameAr: station.nameAr,
        artworkUrl: station.logoUrl,
        filePath: path,
        createdAt: startedAt,
        duration: duration,
        sizeBytes: length,
        format: format,
        partial: partial,
      );
      _clips.insert(0, clip);
      await _persist();
    } else if (await file.exists()) {
      await file.delete();
    }

    _station = null;
    _startedAt = null;
    _filePath = null;
    _format = null;
    _bytes = 0;
    _finishing = false;
    notifyListeners();
    return clip;
  }

  Future<void> _discardActive() async {
    _limitTimer?.cancel();
    _progressTimer?.cancel();
    await _subscription?.cancel();
    try {
      await _sink?.close();
    } catch (_) {}
    _client?.close(force: true);
    final path = _filePath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    _client = null;
    _subscription = null;
    _sink = null;
    _station = null;
    _startedAt = null;
    _filePath = null;
    _format = null;
    _bytes = 0;
    _finishing = false;
    notifyListeners();
  }

  @override
  Future<void> delete(String clipId) async {
    final index = _clips.indexWhere((clip) => clip.id == clipId);
    if (index < 0) return;
    final clip = _clips.removeAt(index);
    final file = File(clip.filePath);
    if (await file.exists()) await file.delete();
    await _persist();
    notifyListeners();
  }

  @override
  Future<bool> exists(OfflineClip clip) => File(clip.filePath).exists();

  Future<void> _persist() => _preferences.setString(
    _metadataKey,
    jsonEncode(_clips.map((clip) => clip.toJson()).toList(growable: false)),
  );
}
