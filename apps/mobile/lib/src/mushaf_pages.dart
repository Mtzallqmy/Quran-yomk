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

class MushafAssetUnavailableOfflineException implements Exception {
  const MushafAssetUnavailableOfflineException(this.page, this.edition);

  final int page;
  final MushafPageEdition edition;

  @override
  String toString() =>
      'Mushaf page $page (${edition.name}) is not cached and could not be downloaded.';
}

class MushafOfflineProgress {
  const MushafOfflineProgress({
    required this.edition,
    required this.completedPages,
    required this.totalPages,
    required this.receivedBytes,
    this.totalBytes,
    this.currentPage,
    this.error,
  });

  final MushafPageEdition edition;
  final int completedPages;
  final int totalPages;
  final int receivedBytes;
  final int? totalBytes;
  final int? currentPage;
  final Object? error;

  double get progress {
    if (totalBytes != null && totalBytes! > 0) {
      return (receivedBytes / totalBytes!).clamp(0, 1);
    }
    return totalPages == 0 ? 0 : completedPages / totalPages;
  }
}

/// Local-first page asset repository. Heavy Mushaf assets are distributed from
/// immutable Supabase Storage paths and cached under application support data.
class MushafPageRepository extends ChangeNotifier {
  MushafPageRepository({http.Client? client, Directory? root})
    : _client = client ?? http.Client(),
      _root = root;

  static const assetVersion = 'v1';
  static const normalPageBaseUrl = String.fromEnvironment(
    'TARTEEL_HAFS_SVG_BASE_URL',
    defaultValue:
        'https://qkroecnecdxghcqvvoxn.supabase.co/storage/v1/object/public/mushaf-assets/v1/hafs',
  );
  static const tajweedPageBaseUrl = String.fromEnvironment(
    'TARTEEL_TAJWEED_PAGE_BASE_URL',
    defaultValue:
        'https://qkroecnecdxghcqvvoxn.supabase.co/storage/v1/object/public/mushaf-assets/v1/tajweed',
  );
  static const normalPackUrl = String.fromEnvironment(
    'TARTEEL_HAFS_OFFLINE_PACK_URL',
    defaultValue:
        'https://qkroecnecdxghcqvvoxn.supabase.co/storage/v1/object/public/mushaf-assets/v1/packs/madinah-hafs-svg-pack.zip',
  );
  static const tajweedPackUrl = String.fromEnvironment(
    'TARTEEL_TAJWEED_OFFLINE_PACK_URL',
    defaultValue:
        'https://qkroecnecdxghcqvvoxn.supabase.co/storage/v1/object/public/mushaf-assets/v1/packs/madinah-tajweed-qcf-v4-pack.zip',
  );
  static const packChecksumsUrl =
      'https://qkroecnecdxghcqvvoxn.supabase.co/storage/v1/object/public/mushaf-assets/v1/packs/MUSHAF-PACK-SHA256SUMS.txt';

  static const _githubHafsBase =
      'https://raw.githubusercontent.com/quranpedia/quran-svg/b91d39e1065b57bdda3e94aca8ecf3575e50e1e6/mushafs/hafs/kfqc';
  static const _githubTajweedBase =
      'https://raw.githubusercontent.com/Mtzallqmy/Quran-yomk/mushaf-assets-v1/qcf-v4/1080';
  static const _githubHafsPack =
      'https://github.com/Mtzallqmy/Quran-yomk/releases/download/mushaf-assets-v1/madinah-hafs-svg-pack.zip';
  static const _githubTajweedPack =
      'https://github.com/Mtzallqmy/Quran-yomk/releases/download/mushaf-assets-v1/madinah-tajweed-qcf-v4-pack.zip';
  static const _githubPackChecksums =
      'https://github.com/Mtzallqmy/Quran-yomk/releases/download/mushaf-assets-v1/MUSHAF-PACK-SHA256SUMS.txt';

  final http.Client _client;
  Directory? _root;
  bool _cancelRequested = false;
  MushafOfflineProgress? offlineProgress;

  Future<void> initialize() async {
    if (_root == null) {
      final support = await getApplicationSupportDirectory();
      _root = Directory('${support.path}/mushaf-pages');
    }
    await _root!.create(recursive: true);
  }

  Future<MushafPageAsset> page(int page, MushafPageEdition edition) async {
    _checkPage(page);
    await _ensureInitialized();
    final manifest = await _loadManifestBestEffort(edition);
    final image = await _ensureFile(
      page,
      edition,
      metadata: false,
      manifest: manifest,
    );
    final metadata = await _ensureFile(
      page,
      edition,
      metadata: true,
      manifest: manifest,
    );
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
    _checkPage(page);
    await _ensureInitialized();
    final manifest = await _readLocalManifest(edition);
    return await _isValid(
          _imageFile(page, edition),
          metadata: false,
          expectedSha: _expectedSha(manifest, _assetRelative(page, edition, false)),
        ) &&
        await _isValid(
          _metadataFile(page, edition),
          metadata: true,
          expectedSha: _expectedSha(manifest, _assetRelative(page, edition, true)),
        );
  }

  Future<bool> isOfflinePackAvailable(MushafPageEdition edition) async {
    await _ensureInitialized();
    try {
      await _verifyEdition(edition);
      return true;
    } catch (_) {
      return false;
    }
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
      final installed = await _tryInstallPack(edition);
      if (_cancelRequested) return;
      if (!installed) {
        final manifest = await _loadManifestBestEffort(edition);
        var bytes = 0;
        for (var page = 1; page <= mushafPageCount; page++) {
          if (_cancelRequested) return;
          final image = await _ensureFile(
            page,
            edition,
            metadata: false,
            manifest: manifest,
          );
          final metadata = await _ensureFile(
            page,
            edition,
            metadata: true,
            manifest: manifest,
          );
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
      final size = await _editionSize(edition);
      offlineProgress = MushafOfflineProgress(
        edition: edition,
        completedPages: mushafPageCount,
        totalPages: mushafPageCount,
        receivedBytes: size,
        totalBytes: size,
      );
      notifyListeners();
    } catch (error) {
      offlineProgress = MushafOfflineProgress(
        edition: edition,
        completedPages: offlineProgress?.completedPages ?? 0,
        totalPages: mushafPageCount,
        receivedBytes: offlineProgress?.receivedBytes ?? 0,
        totalBytes: offlineProgress?.totalBytes,
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
    final installing = _installingDirectory(edition);
    if (installing.existsSync()) await installing.delete(recursive: true);
    final partial = _packPartial(edition);
    if (await partial.exists()) await partial.delete();
    offlineProgress = null;
    notifyListeners();
  }

  Future<File> _ensureFile(
    int page,
    MushafPageEdition edition, {
    required bool metadata,
    Map<String, dynamic>? manifest,
  }) async {
    final target = metadata
        ? _metadataFile(page, edition)
        : _imageFile(page, edition);
    final relative = _assetRelative(page, edition, metadata);
    final expectedSha = _expectedSha(manifest, relative);
    if (await _isValid(target, metadata: metadata, expectedSha: expectedSha)) {
      return target;
    }
    if (await target.exists()) await target.delete();
    await target.parent.create(recursive: true);

    Object? lastError;
    for (final url in _assetUrls(page, edition, metadata: metadata)) {
      final uri = Uri.parse(url);
      try {
        final response = await _client.get(uri);
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          lastError = HttpException(
            'Mushaf asset HTTP ${response.statusCode}',
            uri: uri,
          );
          continue;
        }
        final partial = File('${target.path}.partial');
        await partial.writeAsBytes(response.bodyBytes, flush: true);
        if (!await _isValid(
          partial,
          metadata: metadata,
          expectedSha: expectedSha,
        )) {
          await partial.delete();
          lastError = const FormatException('Invalid Mushaf page asset');
          continue;
        }
        if (await target.exists()) await target.delete();
        await partial.rename(target.path);
        return target;
      } catch (error) {
        lastError = error;
      }
    }
    debugPrint('Mushaf asset download failed: $lastError');
    throw MushafAssetUnavailableOfflineException(page, edition);
  }

  String _assetRelative(
    int page,
    MushafPageEdition edition,
    bool metadata,
  ) {
    final number = page.toString().padLeft(3, '0');
    return '${metadata ? 'bounds' : 'pages'}/$number.${metadata ? 'json' : edition.fileExtension}';
  }

  List<String> _assetUrls(
    int page,
    MushafPageEdition edition, {
    required bool metadata,
  }) {
    final number = page.toString().padLeft(3, '0');
    if (edition == MushafPageEdition.madinahHafsSvg) {
      return <String>[
        '$normalPageBaseUrl/${metadata ? 'bounds' : 'pages'}/$number.${metadata ? 'json' : 'svg'}',
        '$_githubHafsBase/${metadata ? 'json' : 'svg'}/$number.${metadata ? 'json' : 'svg'}',
      ];
    }
    return <String>[
      '$tajweedPageBaseUrl/${metadata ? 'bounds' : 'pages'}/$number.${metadata ? 'json' : 'webp'}',
      '$_githubTajweedBase/${metadata ? 'bounds' : 'pages'}/$number.${metadata ? 'json' : 'webp'}',
    ];
  }

  Future<Map<String, dynamic>?> _loadManifestBestEffort(
    MushafPageEdition edition,
  ) async {
    final local = await _readLocalManifest(edition);
    if (local != null) return local;
    final url = edition == MushafPageEdition.madinahHafsSvg
        ? '$normalPageBaseUrl/manifest.json'
        : '$tajweedPageBaseUrl/manifest.json';
    try {
      final response = await _client.get(Uri.parse(url));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> || !_manifestLooksValid(decoded, edition)) {
        return null;
      }
      final target = _manifestFile(edition);
      await target.parent.create(recursive: true);
      final partial = File('${target.path}.partial');
      await partial.writeAsBytes(response.bodyBytes, flush: true);
      if (await target.exists()) await target.delete();
      await partial.rename(target.path);
      return decoded;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _readLocalManifest(
    MushafPageEdition edition,
  ) async {
    final file = _manifestFile(edition);
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic> && _manifestLooksValid(decoded, edition)) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  bool _manifestLooksValid(
    Map<String, dynamic> manifest,
    MushafPageEdition edition,
  ) {
    final count = manifest['pageCount'] ?? manifest['pages'];
    if (count != mushafPageCount) return false;
    final manifestEdition = manifest['edition'];
    if (manifestEdition != null) {
      final expected = edition == MushafPageEdition.madinahHafsSvg
          ? 'hafs'
          : 'tajweed';
      if (manifestEdition != expected) return false;
    }
    return manifest['files'] is Map || manifest['sha256'] is Map;
  }

  String? _expectedSha(Map<String, dynamic>? manifest, String relative) {
    if (manifest == null) return null;
    final files = manifest['files'];
    if (files is Map) {
      final value = files[relative];
      if (value is Map && value['sha256'] is String) {
        return value['sha256'] as String;
      }
      if (value is String) return value;
    }
    final legacy = manifest['sha256'];
    if (legacy is Map && legacy[relative] is String) {
      return legacy[relative] as String;
    }
    return null;
  }

  Future<bool> _tryInstallPack(MushafPageEdition edition) async {
    final expectedSha = await _expectedPackSha(edition);
    if (expectedSha == null) return false;
    final temporary = _packPartial(edition);

    for (final url in _packUrls(edition)) {
      try {
        final existingBytes = await temporary.exists()
            ? await temporary.length()
            : 0;
        final request = http.Request('GET', Uri.parse(url));
        if (existingBytes > 0) {
          request.headers['Range'] = 'bytes=$existingBytes-';
        }
        final response = await _client.send(request);
        if (response.statusCode != 200 && response.statusCode != 206) continue;
        if (response.statusCode == 200 && existingBytes > 0) {
          await temporary.writeAsBytes(const <int>[], flush: true);
        }
        final resumedBytes = response.statusCode == 206 ? existingBytes : 0;
        final totalBytes = _responseTotalBytes(response, resumedBytes);
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
            totalBytes: totalBytes,
          );
          notifyListeners();
        }
        await sink.close();
        if (sha256Hex(await temporary.readAsBytes()) != expectedSha) {
          await temporary.delete();
          continue;
        }
        await _extractAndInstallPack(temporary, edition);
        await temporary.delete();
        return true;
      } catch (_) {
        // Try the emergency GitHub backup, then fall back to per-page delivery.
      }
    }
    return false;
  }

  int? _responseTotalBytes(http.StreamedResponse response, int resumedBytes) {
    final contentRange = response.headers['content-range'];
    if (contentRange != null) {
      final match = RegExp(r'/([0-9]+)$').firstMatch(contentRange);
      if (match != null) return int.tryParse(match.group(1)!);
    }
    final length = response.contentLength;
    if (length != null) return resumedBytes + length;
    return null;
  }

  List<String> _packUrls(MushafPageEdition edition) =>
      edition == MushafPageEdition.madinahHafsSvg
      ? <String>[normalPackUrl, _githubHafsPack]
      : <String>[tajweedPackUrl, _githubTajweedPack];

  Future<String?> _expectedPackSha(MushafPageEdition edition) async {
    final filename = edition == MushafPageEdition.madinahHafsSvg
        ? 'madinah-hafs-svg-pack.zip'
        : 'madinah-tajweed-qcf-v4-pack.zip';
    for (final url in <String>[packChecksumsUrl, _githubPackChecksums]) {
      try {
        final response = await _client.get(Uri.parse(url));
        if (response.statusCode != 200) continue;
        for (final line in const LineSplitter().convert(response.body)) {
          if (line.trim().endsWith(filename)) {
            final value = line.trim().split(RegExp(r'\s+')).first;
            if (RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) return value;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _extractAndInstallPack(
    File archiveFile,
    MushafPageEdition edition,
  ) async {
    final staging = _installingDirectory(edition);
    if (staging.existsSync()) await staging.delete(recursive: true);
    await staging.create(recursive: true);

    final input = InputFileStream(archiveFile.path);
    try {
      final archive = ZipDecoder().decodeStream(input);
      for (final entry in archive) {
        if (!entry.isFile) continue;
        if (!_isSafeArchivePath(entry.name)) {
          throw const FormatException('Unsafe Mushaf ZIP path');
        }
        final target = File('${staging.path}/${entry.name}');
        await target.parent.create(recursive: true);
        final bytes = entry.readBytes();
        if (bytes == null) throw const FormatException('Invalid ZIP entry');
        await target.writeAsBytes(bytes, flush: true);
      }
    } finally {
      input.close();
    }

    await _verifyDirectory(staging, edition);
    final destination = _editionDirectory(edition);
    if (destination.existsSync()) await destination.delete(recursive: true);
    await staging.rename(destination.path);
  }

  bool _isSafeArchivePath(String name) {
    if (name.isEmpty || name.startsWith('/') || name.startsWith('\\')) {
      return false;
    }
    final parts = name.replaceAll('\\', '/').split('/');
    return !parts.any((part) => part == '..' || part.isEmpty);
  }

  Future<void> _verifyEdition(MushafPageEdition edition) async {
    await _verifyDirectory(_editionDirectory(edition), edition);
  }

  Future<void> _verifyDirectory(
    Directory directory,
    MushafPageEdition edition,
  ) async {
    final manifestFile = File('${directory.path}/manifest.json');
    if (!await manifestFile.exists()) {
      throw const FormatException('Missing Mushaf manifest');
    }
    final decoded = jsonDecode(await manifestFile.readAsString());
    if (decoded is! Map<String, dynamic> || !_manifestLooksValid(decoded, edition)) {
      throw const FormatException('Invalid Mushaf manifest');
    }

    for (var page = 1; page <= mushafPageCount; page++) {
      final number = page.toString().padLeft(3, '0');
      final imageRelative = 'pages/$number.${edition.fileExtension}';
      final boundsRelative = 'bounds/$number.json';
      final image = File('${directory.path}/$imageRelative');
      final bounds = File('${directory.path}/$boundsRelative');
      if (!await _isValid(
            image,
            metadata: false,
            expectedSha: _expectedSha(decoded, imageRelative),
          ) ||
          !await _isValid(
            bounds,
            metadata: true,
            expectedSha: _expectedSha(decoded, boundsRelative),
          )) {
        throw StateError('Offline Mushaf verification failed at page $page');
      }
    }

    final files = decoded['files'] ?? decoded['sha256'];
    if (files is Map) {
      for (final rawEntry in files.entries) {
        final relative = rawEntry.key.toString();
        if (!_isSafeArchivePath(relative)) {
          throw const FormatException('Unsafe Mushaf manifest path');
        }
        final expected = rawEntry.value is Map
            ? (rawEntry.value as Map)['sha256']?.toString()
            : rawEntry.value.toString();
        if (expected == null) continue;
        final file = File('${directory.path}/$relative');
        if (!await file.exists() || sha256Hex(await file.readAsBytes()) != expected) {
          throw StateError('Mushaf checksum failed: $relative');
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

  Future<bool> _isValid(
    File file, {
    required bool metadata,
    String? expectedSha,
  }) async {
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
        if (value is! List && value is! Map) return false;
      } catch (_) {
        return false;
      }
    } else if (isSvg) {
      if (!utf8.decode(bytes, allowMalformed: true).contains('<svg')) {
        return false;
      }
    } else if (bytes.length < 12 ||
        ascii.decode(bytes.take(4).toList(), allowInvalid: true) != 'RIFF' ||
        ascii.decode(bytes.skip(8).take(4).toList(), allowInvalid: true) !=
            'WEBP') {
      return false;
    }
    if (expectedSha != null &&
        sha256Hex(await file.readAsBytes()) != expectedSha) {
      return false;
    }
    return true;
  }

  Directory _editionDirectory(MushafPageEdition edition) =>
      Directory('${_root!.path}/${edition.name}');

  Directory _installingDirectory(MushafPageEdition edition) =>
      Directory('${_root!.path}/${edition.name}.installing');

  File _packPartial(MushafPageEdition edition) =>
      File('${_root!.path}/${edition.name}.zip.partial');

  File _manifestFile(MushafPageEdition edition) =>
      File('${_editionDirectory(edition).path}/manifest.json');

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
    if (_root == null || !_root!.existsSync()) await initialize();
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
