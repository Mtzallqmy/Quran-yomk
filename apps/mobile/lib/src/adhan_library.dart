import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class AdhanRecording {
  const AdhanRecording({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.placeAr,
    required this.sourceUrl,
    required this.licenseUrl,
    required this.licenseLabel,
    required this.fileExtension,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String placeAr;
  final String sourceUrl;
  final String licenseUrl;
  final String licenseLabel;
  final String fileExtension;

  String get attribution => '$nameAr — $licenseLabel';
}

/// Only recordings with an explicit public-domain statement are included.
/// The app keeps the provider URL and attribution beside the offline copy.
const adhanRecordings = <AdhanRecording>[
  AdhanRecording(
    id: 'makkah-asr-public-domain',
    nameAr: 'أذان الحرم المكي — العصر',
    nameEn: 'Makkah Haram — Asr',
    placeAr: 'مكة المكرمة',
    sourceUrl: 'https://archive.org/download/AsrAzanFromMakkah/AsrAzanFromMakkah.ogv',
    licenseUrl: 'https://archive.org/details/AsrAzanFromMakkah',
    licenseLabel: 'ملكية عامة (Internet Archive)',
    fileExtension: 'ogv',
  ),
  AdhanRecording(
    id: 'makkah-asr-public-domain-mp4',
    nameAr: 'أذان مكة — نسخة متوافقة',
    nameEn: 'Makkah — Compatible audio copy',
    placeAr: 'مكة المكرمة',
    sourceUrl: 'https://archive.org/download/AsrAzanFromMakkah/AsrAzanFromMakkah_512kb.mp4',
    licenseUrl: 'https://archive.org/details/AsrAzanFromMakkah',
    licenseLabel: 'ملكية عامة (Internet Archive)',
    fileExtension: 'mp4',
  ),
];

class AdhanLibraryStore extends ChangeNotifier {
  AdhanLibraryStore(this._preferences);

  static const _selectedKey = 'adhan:selected:v1';
  static const _filesKey = 'adhan:files:v1';
  final SharedPreferences _preferences;
  final Map<String, String> _files = <String, String>{};
  String? _selectedId;
  bool _busy = false;
  String? _error;

  bool get busy => _busy;
  String? get error => _error;
  String? get selectedId => _selectedId;
  AdhanRecording? get selected => _find(_selectedId);
  String? get selectedPath => _selectedId == null ? null : _files[_selectedId];

  void load() {
    _selectedId = _preferences.getString(_selectedKey);
    final raw = _preferences.getString(_filesKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _files.addAll(decoded.map((key, value) => MapEntry(key, value.toString())));
      }
    } catch (_) {
      _files.clear();
    }
    _removeMissing();
  }

  bool isDownloaded(String id) => _files.containsKey(id) && File(_files[id]!).existsSync();

  Future<bool> download(AdhanRecording recording) async {
    if (isDownloaded(recording.id)) {
      await select(recording.id);
      return true;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    File? part;
    try {
      final directory = await getApplicationSupportDirectory();
      final target = File('${directory.path}/adhan_${recording.id}.${recording.fileExtension}');
      part = File('${target.path}.part');
      if (await part.exists()) await part.delete();
      final request = await client.getUrl(Uri.parse(recording.sourceUrl));
      // The Archive download endpoint redirects to its immutable CDN object.
      // The URL is from the built-in, reviewed catalog and is capped.
      request.followRedirects = true;
      request.maxRedirects = 3;
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('ADHAN_DOWNLOAD_HTTP_${response.statusCode}');
      }
      var total = 0;
      final output = part.openWrite();
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        total += chunk.length;
        if (total > 80 * 1024 * 1024) throw StateError('ADHAN_DOWNLOAD_TOO_LARGE');
        output.add(chunk);
      }
      await output.close();
      if (total < 4096) throw StateError('ADHAN_DOWNLOAD_EMPTY');
      await part.rename(target.path);
      _files[recording.id] = target.path;
      await _persist();
      await select(recording.id);
      return true;
    } catch (error) {
      _error = error is StateError ? error.message : 'ADHAN_DOWNLOAD_FAILED';
      if (part != null && await part.exists()) await part.delete();
      return false;
    } finally {
      client.close(force: true);
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> select(String id) async {
    if (!isDownloaded(id)) throw StateError('ADHAN_NOT_DOWNLOADED');
    _selectedId = id;
    await _preferences.setString(_selectedKey, id);
    notifyListeners();
  }

  Future<void> remove(String id) async {
    final path = _files.remove(id);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    if (_selectedId == id) {
      _selectedId = null;
      await _preferences.remove(_selectedKey);
    }
    await _persist();
    notifyListeners();
  }

  AdhanRecording? _find(String? id) {
    if (id == null) return null;
    for (final recording in adhanRecordings) {
      if (recording.id == id) return recording;
    }
    return null;
  }

  void _removeMissing() {
    _files.removeWhere((_, path) => !File(path).existsSync());
    if (_selectedId != null && !_files.containsKey(_selectedId)) _selectedId = null;
  }

  Future<void> _persist() => _preferences.setString(_filesKey, jsonEncode(_files));
}
