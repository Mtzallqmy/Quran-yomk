import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'quran_search.dart';

/// A source-authored topical index over the existing Hafs verse identities.
/// It deliberately carries no second copy of Quran text and makes no claim
/// that its overlapping topics form an exhaustive partition of the Quran.
class MushafTopic {
  const MushafTopic(this.id, this.title, this.parentId, this.verseKeys);
  final int id;
  final String title;
  final int? parentId;
  final List<String> verseKeys;
}

class MushafTopicIndex {
  MushafTopicIndex(this.topics)
    : byId = {for (final topic in topics) topic.id: topic};

  static const source = 'https://quranpedia.net';
  static const version = '2026-10-24';
  final List<MushafTopic> topics;
  final Map<int, MushafTopic> byId;
  static Future<MushafTopicIndex>? _bundled;
  static MushafTopicIndex? _cached;

  static Future<MushafTopicIndex> load() =>
      _cached != null ? Future.value(_cached) : _bundled ??= _load();

  static Future<MushafTopicIndex> _load() async {
    final data = await rootBundle.load(
      'assets/mushaf_library/topics-2026-10-24.json.gz',
    );
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (sha256.convert(bytes).toString() != topicPackageSha256) {
      throw const FormatException('Invalid topical index checksum');
    }
    return _cached = parse(
      jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>,
    );
  }

  static MushafTopicIndex parse(Map<String, dynamic> json) {
    if (json['schema'] != '/v1/topics' ||
        (json['license'] as Map)['version'] != version) {
      throw const FormatException('Unsupported topical source/version');
    }
    final topics = <MushafTopic>[];
    for (final row in json['data'] as List) {
      final keys = (row['ayahs'] as String)
          .split(',')
          .where((key) => key.isNotEmpty)
          .toSet()
          .toList();
      if (keys.any(
        (key) =>
            !RegExp(r'^([1-9][0-9]{0,2}):([1-9][0-9]{0,2})$').hasMatch(key),
      )) {
        throw const FormatException('Invalid topical verse identity');
      }
      topics.add(
        MushafTopic(
          row['id'] as int,
          row['name'] as String,
          row['parent_id'] as int?,
          List.unmodifiable(keys),
        ),
      );
    }
    if (topics.map((t) => t.id).toSet().length != topics.length) {
      throw const FormatException('Duplicate topic identity');
    }
    final result = MushafTopicIndex(List.unmodifiable(topics));
    for (final topic in topics) {
      final seen = <int>{topic.id};
      var parent = topic.parentId;
      while (parent != null) {
        if (!seen.add(parent) || !result.byId.containsKey(parent)) {
          throw const FormatException('Invalid topic hierarchy');
        }
        parent = result.byId[parent]!.parentId;
      }
    }
    return result;
  }

  List<MushafTopic> search(String query, {int? parentId}) {
    final normalized = normalizeQuranQuery(query);
    return topics
        .where(
          (topic) => normalized.isEmpty
              ? topic.parentId == parentId
              : normalizeQuranQuery(topic.title).contains(normalized),
        )
        .toList();
  }

  List<MushafTopic> forVerse(String key) =>
      topics.where((topic) => topic.verseKeys.contains(key)).toList();

  String ancestry(MushafTopic topic) {
    final parts = <String>[];
    var parent = topic.parentId;
    while (parent != null) {
      final item = byId[parent]!;
      parts.insert(0, item.title);
      parent = item.parentId;
    }
    return parts.join(' / ');
  }
}

const topicPackageSha256 =
    '149f3e4532761dbd9365903fa48ab0e8d5eabcdb8971c42fed7f9ce6b4858b8c';

/// Visual-page identities are distinct from the remote text provider's page
/// metadata. Resolve navigation against the actual pinned artwork's bounds.
class MushafVisualPages {
  static Future<Map<String, int>>? _pages;
  static Future<Map<String, int>> load() => _pages ??= _load();
  static Future<Map<String, int>> _load() async {
    final text = await rootBundle.loadString(
      'assets/mushaf_library/hafs-page-map.json',
    );
    if (sha256.convert(utf8.encode(text)).toString() !=
        '0f58f1a5a58d4e4b7b07e21498e9a3b7abb461728775973a96049786ffb163e7') {
      throw const FormatException('Invalid visual page map checksum');
    }
    final json = jsonDecode(text) as Map<String, dynamic>;
    return Map<String, int>.from(json['pages'] as Map);
  }
}
