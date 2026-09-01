import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const mushafPageCount = 604;
const mushafSvgWidth = 345.0;
const mushafSvgHeight = 550.0;
const mushafTajweedWidth = 1080.0;
const mushafTajweedHeight = 2610.0;

enum MushafPageEdition { madinahHafsSvg, madinahTajweedQcfV4 }

extension MushafPageEditionInfo on MushafPageEdition {
  String get labelAr => switch (this) {
    MushafPageEdition.madinahHafsSvg => 'مصحف المدينة',
    MushafPageEdition.madinahTajweedQcfV4 => 'مصحف التجويد',
  };

  String get fileExtension => switch (this) {
    MushafPageEdition.madinahHafsSvg => 'svg',
    MushafPageEdition.madinahTajweedQcfV4 => 'webp',
  };

  double get nativeWidth => switch (this) {
    MushafPageEdition.madinahHafsSvg => mushafSvgWidth,
    MushafPageEdition.madinahTajweedQcfV4 => mushafTajweedWidth,
  };

  double get nativeHeight => switch (this) {
    MushafPageEdition.madinahHafsSvg => mushafSvgHeight,
    MushafPageEdition.madinahTajweedQcfV4 => mushafTajweedHeight,
  };
}

class MushafAyahRegion {
  const MushafAyahRegion({
    required this.surahNumber,
    required this.ayahNumber,
    required this.rects,
  });

  final int surahNumber;
  final int ayahNumber;
  final List<math.Rectangle<double>> rects;

  String get verseKey => '$surahNumber:$ayahNumber';

  bool contains(double x, double y) => rects.any(
    (rect) =>
        x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom,
  );
}

class MushafPageAsset {
  const MushafPageAsset({
    required this.page,
    required this.edition,
    required this.file,
    required this.regions,
    required this.width,
    required this.height,
  });

  final int page;
  final MushafPageEdition edition;
  final File file;
  final List<MushafAyahRegion> regions;
  final double width;
  final double height;
}

class MushafOfflineProgress {
  const MushafOfflineProgress({
    required this.edition,
    required this.completedPages,
    required this.totalPages,
    required this.receivedBytes,
    this.currentPage,
    this.error,
  });

  final MushafPageEdition edition;
  final int completedPages;
  final int totalPages;
  final int receivedBytes;
  final int? currentPage;
  final Object? error;

  double get progress => totalPages == 0 ? 0 : completedPages / totalPages;
}

/// Local-first page asset repository. The Quran artwork is always rendered as
/// an SVG/WebP file; this class never exposes Quran text to the page widget.
class MushafPageRepository extends ChangeNotifier {
  MushafPageRepository({http.Client? client})
    : _client = client ?? http.Client();

  static const normalPageBaseUrl = String.fromEnvironment(
    'TARTEEL_HAFS_SVG_BASE_URL',
    defaultValue:
        'https://raw.githubusercontent.com/quranpedia/quran-svg/b91d39e1065b57bdda3e94aca8ecf3575e50e1e6/mushafs/hafs/kfqc',
  );
  static const tajweedPageBaseUrl = String.fromEnvironment(
    'TARTEEL_TAJWEED_PAGE_BASE_URL',
    defaultValue:
        'https://raw.githubusercontent.com/Mtzallqmy/Quran-yomk/mushaf-assets-v1/qcf-v4/1080',
  );
  static const normalPackUrl = String.fromEnvironment(
    'TARTEEL_HAFS_OFFLINE_PACK_URL',
    defaultValue:
        'https://github.com/Mtzallqmy/Quran-yomk/releases/download/mushaf-assets-v1/madinah-hafs-svg-pack.zip',
  );
  static const tajweedPackUrl = String.fromEnvironment(
    'TARTEEL_TAJWEED_OFFLINE_PACK_URL',
    defaultValue:
        'https://github.com/Mtzallqmy/Quran-yomk/releases/download/mushaf-assets-v1/madinah-tajweed-qcf-v4-pack.zip',
  );

  final http.Client _client;
  Directory? _root;
  bool _cancelRequested = false;
  MushafOfflineProgress? offlineProgress;

  Future<void> initialize() async {
    final support = await getApplicationSupportDirectory();
    _root = Directory('${support.path}/mushaf-pages');
    await _root!.create(recursive: true);
  }

  Future<MushafPageAsset> page(int page, MushafPageEdition edition) async {
    _checkPage(page);
    await _ensureInitialized();
    final image = await _ensureFile(page, edition, metadata: false);
    final metadata = await _ensureFile(page, edition, metadata: true);
    final regions = edition == MushafPageEdition.madinahHafsSvg
        ? parseMadinahHafsRegions(await metadata.readAsString())
        : parseQcfV4TajweedRegions(await metadata.readAsString(), page);
    return MushafPageAsset(
      page: page,
      edition: edition,
      file: image,
      regions: regions,
      width: edition.nativeWidth,
      height: edition.nativeHeight,
    );
  }

  Future<bool> isPageCached(int page, MushafPageEdition edition) async {
    await _ensureInitialized();
    return _imageFile(page, edition).exists() &&
        _metadataFile(page, edition).exists();
  }

  Future<void> downloadOfflinePack(MushafPageEdition edition) async {
    await _ensureInitialized();
    _cancelRequested = false;
    offlineProgress = MushafOfflineProgress(
      edition: edition,
      completedPages: 0,
      totalPages: mushafPageCount,
      receivedBytes: 0,
    );
    notifyListeners();
    try {
      // A release pack is preferred because it is one resumable transfer and
      // avoids hundreds of CDN requests. Fall back to verified page downloads.
      final installed = await _tryInstallPack(edition);
      if (!installed) {
        var bytes = 0;
        for (var page = 1; page <= mushafPageCount; page++) {
          if (_cancelRequested) return;
          final image = await _ensureFile(page, edition, metadata: false);
          final metadata = await _ensureFile(page, edition, metadata: true);
          bytes += await image.length() + await metadata.length();
          offlineProgress = MushafOfflineProgress(
            edition: edition,
            completedPages: page,
            totalPages: mushafPageCount,
            receivedBytes: bytes,
            currentPage: page,
          );
          notifyListeners();
        }
      }
      await _verifyEdition(edition);
      offlineProgress = MushafOfflineProgress(
        edition: edition,
        completedPages: mushafPageCount,
        totalPages: mushafPageCount,
        receivedBytes: await _editionSize(edition),
      );
      notifyListeners();
    } catch (error) {
      offlineProgress = MushafOfflineProgress(
        edition: edition,
        completedPages: offlineProgress?.completedPages ?? 0,
        totalPages: mushafPageCount,
        receivedBytes: offlineProgress?.receivedBytes ?? 0,
        error: error,
      );
      notifyListeners();
      rethrow;
    }
  }

  void cancelOfflinePack() {
    _cancelRequested = true;
  }

  Future<void> deleteOfflinePack(MushafPageEdition edition) async {
    await _ensureInitialized();
    final directory = _editionDirectory(edition);
    if (directory.existsSync()) await directory.delete(recursive: true);
    offlineProgress = null;
    notifyListeners();
  }

  Future<File> _ensureFile(
    int page,
    MushafPageEdition edition, {
    required bool metadata,
  }) async {
    final target = metadata
        ? _metadataFile(page, edition)
        : _imageFile(page, edition);
    if (await _isValid(target, metadata: metadata)) return target;
    await target.parent.create(recursive: true);
    final uri = Uri.parse(_url(page, edition, metadata: metadata));
    final response = await _client.get(uri);
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw HttpException('Mushaf asset HTTP ${response.statusCode}', uri: uri);
    }
    final partial = File('${target.path}.partial');
    await partial.writeAsBytes(response.bodyBytes, flush: true);
    if (!await _isValid(partial, metadata: metadata)) {
      await partial.delete();
      throw const FormatException('Invalid Mushaf page asset');
    }
    await partial.rename(target.path);
    return target;
  }

  String _url(int page, MushafPageEdition edition, {required bool metadata}) {
    final number = page.toString().padLeft(3, '0');
    if (edition == MushafPageEdition.madinahHafsSvg) {
      return '$normalPageBaseUrl/${metadata ? 'json' : 'svg'}/$number.${metadata ? 'json' : 'svg'}';
    }
    return '$tajweedPageBaseUrl/${metadata ? 'bounds' : 'pages'}/$number.${metadata ? 'json' : 'webp'}';
  }

  Future<bool> _tryInstallPack(MushafPageEdition edition) async {
    final url = edition == MushafPageEdition.madinahHafsSvg
        ? normalPackUrl
        : tajweedPackUrl;
    final temporary = File('${_root!.path}/${edition.name}.zip.partial');
    final existingBytes = await temporary.exists()
        ? await temporary.length()
        : 0;
    final request = http.Request('GET', Uri.parse(url));
    if (existingBytes > 0) request.headers['Range'] = 'bytes=$existingBytes-';
    final response = await _client.send(request);
    if (response.statusCode != 200 && response.statusCode != 206) return false;
    if (response.statusCode == 200 && existingBytes > 0) {
      await temporary.writeAsBytes(const <int>[], flush: true);
    }
    final resumedBytes = response.statusCode == 206 ? existingBytes : 0;
    final sink = temporary.openWrite(mode: FileMode.append);
    var received = resumedBytes;
    await for (final chunk in response.stream) {
      if (_cancelRequested) {
        await sink.close();
        return false;
      }
      received += chunk.length;
      sink.add(chunk);
      offlineProgress = MushafOfflineProgress(
        edition: edition,
        completedPages: 0,
        totalPages: mushafPageCount,
        receivedBytes: received,
      );
      notifyListeners();
    }
    await sink.close();
    final archive = ZipDecoder().decodeBytes(await temporary.readAsBytes());
    for (final entry in archive) {
      if (!entry.isFile || entry.name.contains('..')) continue;
      final target = File('${_editionDirectory(edition).path}/${entry.name}');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(entry.readBytes(), flush: true);
    }
    await temporary.delete();
    return true;
  }

  Future<void> _verifyEdition(MushafPageEdition edition) async {
    for (var page = 1; page <= mushafPageCount; page++) {
      if (!await _isValid(_imageFile(page, edition), metadata: false) ||
          !await _isValid(_metadataFile(page, edition), metadata: true)) {
        throw StateError('Offline Mushaf verification failed at page $page');
      }
    }
    final manifest = File('${_editionDirectory(edition).path}/manifest.json');
    if (await manifest.exists()) {
      final decoded = jsonDecode(await manifest.readAsString());
      final files = Map<String, dynamic>.from(
        (decoded as Map<String, dynamic>)['sha256'] as Map,
      );
      for (final entry in files.entries) {
        if (entry.key.contains('..') || entry.key.startsWith('/')) {
          throw const FormatException('Unsafe Mushaf manifest path');
        }
        final file = File('${_editionDirectory(edition).path}/${entry.key}');
        if (!await file.exists() ||
            sha256Hex(await file.readAsBytes()) != entry.value) {
          throw StateError('Mushaf checksum failed: ${entry.key}');
        }
      }
    }
  }

  Future<int> _editionSize(MushafPageEdition edition) async {
    final directory = _editionDirectory(edition);
    if (!directory.existsSync()) return 0;
    var size = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) size += await entity.length();
    }
    return size;
  }

  Future<bool> _isValid(File file, {required bool metadata}) async {
    if (!await file.exists() || await file.length() < (metadata ? 2 : 64)) {
      return false;
    }
    final isSvg = file.path.endsWith('.svg') || file.path.contains('.svg.');
    final bytes = await file
        .openRead(0, math.min(await file.length(), isSvg ? 256 : 16))
        .first;
    if (metadata) {
      try {
        final value = jsonDecode(await file.readAsString());
        return value is List || value is Map;
      } catch (_) {
        return false;
      }
    }
    if (isSvg) {
      return utf8.decode(bytes, allowMalformed: true).contains('<svg');
    }
    return bytes.length >= 12 &&
        ascii.decode(bytes.take(4).toList(), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.skip(8).take(4).toList(), allowInvalid: true) ==
            'WEBP';
  }

  Directory _editionDirectory(MushafPageEdition edition) =>
      Directory('${_root!.path}/${edition.name}');

  File _imageFile(int page, MushafPageEdition edition) {
    final number = page.toString().padLeft(3, '0');
    return File(
      '${_editionDirectory(edition).path}/pages/$number.${edition.fileExtension}',
    );
  }

  File _metadataFile(int page, MushafPageEdition edition) {
    final number = page.toString().padLeft(3, '0');
    return File('${_editionDirectory(edition).path}/bounds/$number.json');
  }

  Future<void> _ensureInitialized() async {
    if (_root == null) await initialize();
  }

  void _checkPage(int page) {
    if (page < 1 || page > mushafPageCount) {
      throw RangeError.range(page, 1, mushafPageCount, 'page');
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

List<MushafAyahRegion> parseMadinahHafsRegions(String raw) {
  final values = jsonDecode(raw) as List<dynamic>;
  return values
      .map((value) {
        final map = Map<String, dynamic>.from(value as Map);
        return MushafAyahRegion(
          surahNumber: (map['surahNumber'] as num).toInt(),
          ayahNumber: (map['ayahNumber'] as num).toInt(),
          rects: _rectanglesFromSvgPath(map['polygon'] as String),
        );
      })
      .toList(growable: false);
}

List<MushafAyahRegion> parseQcfV4TajweedRegions(String raw, int page) {
  final decoded = jsonDecode(raw);
  final values = decoded is List
      ? decoded
      : (decoded as Map<String, dynamic>)['bounds'] as List<dynamic>;
  final grouped = <String, List<math.Rectangle<double>>>{};
  for (final value in values) {
    final map = Map<String, dynamic>.from(value as Map);
    if ((map['page'] as num?)?.toInt() != page) continue;
    final surah = (map['surahNumber'] as num).toInt();
    final ayah = (map['ayahNumber'] as num).toInt();
    grouped
        .putIfAbsent('$surah:$ayah', () => <math.Rectangle<double>>[])
        .add(
          math.Rectangle<double>(
            (map['x'] as num).toDouble(),
            (map['y'] as num).toDouble(),
            (map['width'] as num).toDouble(),
            (map['height'] as num).toDouble(),
          ),
        );
  }
  return grouped.entries
      .map((entry) {
        final key = entry.key.split(':');
        return MushafAyahRegion(
          surahNumber: int.parse(key[0]),
          ayahNumber: int.parse(key[1]),
          rects: entry.value,
        );
      })
      .toList(growable: false);
}

List<math.Rectangle<double>> _rectanglesFromSvgPath(String path) {
  final numbers = RegExp(r'-?\d+(?:\.\d+)?')
      .allMatches(path)
      .map((match) => double.parse(match.group(0)!))
      .toList(growable: false);
  final result = <math.Rectangle<double>>[];
  for (var offset = 0; offset + 7 < numbers.length; offset += 8) {
    final xs = <double>[
      numbers[offset],
      numbers[offset + 2],
      numbers[offset + 4],
      numbers[offset + 6],
    ];
    final ys = <double>[
      numbers[offset + 1],
      numbers[offset + 3],
      numbers[offset + 5],
      numbers[offset + 7],
    ];
    final left = xs.reduce(math.min);
    final top = ys.reduce(math.min);
    result.add(
      math.Rectangle<double>(
        left,
        top,
        xs.reduce(math.max) - left,
        ys.reduce(math.max) - top,
      ),
    );
  }
  return result;
}
