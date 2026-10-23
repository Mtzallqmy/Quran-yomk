import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_audio.dart';

/// Offline assets shipped with the application; never fetched from a server.
@immutable
class BuiltInAdhanSound {
  const BuiltInAdhanSound(
    this.id,
    this.nameAr,
    this.path,
    this.descriptionAr, {
    this.author = '',
    this.sourceUrl = '',
    this.licenseUrl = '',
    this.durationSeconds = 0,
  });
  final String id;
  final String nameAr;
  final String path;
  final String descriptionAr;
  final String author;
  final String sourceUrl;
  final String licenseUrl;
  final int durationSeconds;
}

const builtInAdhanSounds = <BuiltInAdhanSound>[
  BuiltInAdhanSound(
    'built-in-sweden-fajr',
    'أذان الفجر — مالمو، السويد',
    'assets/audio/adhan_sweden_fajr.ogg',
    'المؤذن بيسيم عزمي • المركز الإسلامي بمالمو • CC BY 3.0',
    author: 'Islamic Center Malmö; Besim Azemi',
    durationSeconds: 248,
    sourceUrl:
        'https://commons.wikimedia.org/wiki/File:Eid_al-Fitr_Fajr_azan_at_Malmö_Mosque_-_19_August_2012.webm',
    licenseUrl: 'https://creativecommons.org/licenses/by/3.0/',
  ),
  BuiltInAdhanSound(
    'built-in-makkah',
    'أذان الحرم المكي',
    'assets/audio/adhan_makkah.ogg',
    'مكة المكرمة • تسجيل ميداني • CC BY 3.0',
    author: 'Seyfula Islam',
    durationSeconds: 197,
    sourceUrl:
        'https://commons.wikimedia.org/wiki/File:Adhan,_Great_Mosque_of_Mecca_-_Jan_21,_2013.webm',
    licenseUrl: 'https://creativecommons.org/licenses/by/3.0/',
  ),
  BuiltInAdhanSound(
    'built-in-madinah',
    'أذان المسجد النبوي',
    'assets/audio/adhan_madinah.ogg',
    'المدينة المنورة • تسجيل ميداني • CC BY 3.0',
    author: 'ejaz215',
    durationSeconds: 187,
    sourceUrl:
        'https://commons.wikimedia.org/wiki/File:33937_ejaz215_call-to-prayer-from-the-prophet-s-mo.ogg',
    licenseUrl: 'https://creativecommons.org/licenses/by/3.0/',
  ),
  BuiltInAdhanSound(
    'built-in-kazakhstan',
    'أذان شالقار — كازاخستان',
    'assets/audio/adhan_kazakhstan.ogg',
    'مسجد ماتاي قوقان أولي • CC BY-SA 4.0',
    author: 'Esetok',
    durationSeconds: 155,
    sourceUrl:
        'https://commons.wikimedia.org/wiki/File:Adhan_in_Shalqar_mosque.webm',
    licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
  ),
  BuiltInAdhanSound(
    'built-in-adhan',
    'الأذان المرفق',
    'assets/audio/adhan.ogg',
    'عينة أذان 42 ثانية • Aishatu98 • CC0 1.0',
    author: 'Aishatu98',
    durationSeconds: 42,
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Adhan.ogg',
    licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
  ),
  BuiltInAdhanSound(
    'built-in-reminder',
    'تنبيه هادئ',
    'assets/audio/reminder.wav',
    'تنبيه قصير للأذكار والتذكير • صوت مولّد داخل المشروع',
    author: 'Tarteel',
    durationSeconds: 1,
    licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
  ),
];

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
    sourceUrl:
        'https://archive.org/download/AsrAzanFromMakkah/AsrAzanFromMakkah.ogv',
    licenseUrl: 'https://archive.org/details/AsrAzanFromMakkah',
    licenseLabel: 'ملكية عامة (Internet Archive)',
    fileExtension: 'ogv',
  ),
  AdhanRecording(
    id: 'makkah-asr-public-domain-mp4',
    nameAr: 'أذان مكة — نسخة متوافقة',
    nameEn: 'Makkah — Compatible audio copy',
    placeAr: 'مكة المكرمة',
    sourceUrl:
        'https://archive.org/download/AsrAzanFromMakkah/AsrAzanFromMakkah_512kb.mp4',
    licenseUrl: 'https://archive.org/details/AsrAzanFromMakkah',
    licenseLabel: 'ملكية عامة (Internet Archive)',
    fileExtension: 'mp4',
  ),
];

class AdhanLibraryStore extends ChangeNotifier {
  AdhanLibraryStore(this._preferences);

  static const _selectedKey = 'adhan:selected:v1';
  static const _filesKey = 'adhan:files:v1';
  static const _labelsKey = 'adhan:labels:v1';
  final SharedPreferences _preferences;
  final Map<String, String> _files = <String, String>{};
  final Map<String, String> _labels = <String, String>{};
  String? _selectedId;
  bool _busy = false;
  String? _error;

  bool get busy => _busy;
  bool get hasLocalFile => importedIds.isNotEmpty;
  List<String> get importedIds => _files.keys
      .where((id) => id.startsWith('phone-') && isDownloaded(id))
      .toList(growable: false);

  /// Stable private paths are also used by independent per-prayer settings.
  Map<String, String> get availablePaths => Map.unmodifiable({
    for (final sound in builtInAdhanSounds) sound.id: sound.path,
    for (final entry in _files.entries)
      if (isDownloaded(entry.key)) entry.key: entry.value,
  });

  String labelFor(String id) {
    for (final sound in builtInAdhanSounds) {
      if (sound.id == id) return sound.nameAr;
    }
    return _labels[id] ?? _find(id)?.nameAr ?? 'صوت محلي';
  }

  Future<void> rename(String id, String value) async {
    final name = value.trim();
    if (!importedIds.contains(id) || name.isEmpty || name.length > 80) return;
    _labels[id] = name;
    await _preferences.setString(_labelsKey, jsonEncode(_labels));
    notifyListeners();
  }

  Future<bool> importPhoneAudio() async {
    final path = await NativeAudio.pickAudio();
    if (path == null) return false;
    // Keep older imports: a prayer may still reference their private path.
    final id = 'phone-${DateTime.now().microsecondsSinceEpoch}';
    _files[id] = path;
    _labels[id] = 'صوت محلي ${importedIds.length}';
    await _persist();
    await select(id);
    return true;
  }

  Future<void> selectBuiltIn() async {
    _selectedId = null;
    await _preferences.remove(_selectedKey);
    notifyListeners();
  }

  String? get error => _error;
  String? get selectedId => _selectedId;
  AdhanRecording? get selected => _find(_selectedId);
  String? get selectedPath =>
      _selectedId == null ? null : availablePaths[_selectedId];

  void load() {
    _selectedId = _preferences.getString(_selectedKey);
    try {
      final labels = jsonDecode(_preferences.getString(_labelsKey) ?? '{}');
      if (labels is Map) {
        for (final entry in labels.entries) {
          if (entry.key is String && entry.value is String) {
            _labels[entry.key as String] = entry.value as String;
          }
        }
      }
    } catch (_) {
      /* Keep existing paths even if optional labels are damaged. */
    }
    final raw = _preferences.getString(_filesKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _files.addAll(
          decoded.map((key, value) => MapEntry(key, value.toString())),
        );
      }
    } catch (_) {
      _files.clear();
    }
    _removeMissing();
  }

  bool isDownloaded(String id) =>
      builtInAdhanSounds.any((sound) => sound.id == id) ||
      (_files.containsKey(id) && File(_files[id]!).existsSync());

  Future<bool> download(AdhanRecording recording) async {
    if (_busy) return false;
    if (isDownloaded(recording.id)) {
      await select(recording.id);
      return true;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    File? part;
    IOSink? output;
    try {
      final directory = await getApplicationSupportDirectory();
      final target = File(
        '${directory.path}/adhan_${recording.id}.${recording.fileExtension}',
      );
      part = File('${target.path}.part');
      if (await part.exists()) await part.delete();
      final request = await client.getUrl(Uri.parse(recording.sourceUrl));
      // The Archive download endpoint redirects to its immutable CDN object.
      // The URL is from the built-in, reviewed catalog and is capped.
      request.followRedirects = true;
      request.maxRedirects = 3;
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('ADHAN_DOWNLOAD_HTTP_${response.statusCode}');
      }
      var total = 0;
      output = part.openWrite();
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        total += chunk.length;
        if (total > 80 * 1024 * 1024)
          throw StateError('ADHAN_DOWNLOAD_TOO_LARGE');
        output.add(chunk);
      }
      await output.close();
      output = null;
      if (total < 4096) throw StateError('ADHAN_DOWNLOAD_EMPTY');
      await part.rename(target.path);
      _files[recording.id] = target.path;
      await _persist();
      await select(recording.id);
      return true;
    } catch (error) {
      _error = error is StateError ? error.message : 'ADHAN_DOWNLOAD_FAILED';
      if (output != null) {
        try {
          await output.close();
        } catch (_) {
          // Preserve the original error and clean up the incomplete download.
        }
      }
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
    _labels.remove(id);
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
    if (id.startsWith('phone-'))
      return AdhanRecording(
        id: id,
        nameAr: 'صوت من الهاتف',
        nameEn: 'Phone audio',
        placeAr: 'ملف محلي',
        sourceUrl: '',
        licenseUrl: '',
        licenseLabel: 'ملف اختاره المستخدم',
        fileExtension: 'audio',
      );
    for (final recording in adhanRecordings) {
      if (recording.id == id) return recording;
    }
    return null;
  }

  void _removeMissing() {
    _files.removeWhere((_, path) => !File(path).existsSync());
    if (_selectedId != null && !isDownloaded(_selectedId!)) _selectedId = null;
  }

  Future<void> _persist() async {
    await _preferences.setString(_filesKey, jsonEncode(_files));
    await _preferences.setString(_labelsKey, jsonEncode(_labels));
  }
}
