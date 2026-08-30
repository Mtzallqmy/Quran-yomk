typedef JsonMap = Map<String, dynamic>;

String _string(dynamic value, [String fallback = '']) => value is String ? value : fallback;
String? _nullableString(dynamic value) => value is String && value.isNotEmpty ? value : null;
int _int(dynamic value, [int fallback = 0]) => value is int ? value : (value is num ? value.toInt() : fallback);
bool _bool(dynamic value, [bool fallback = false]) => value is bool ? value : fallback;
JsonMap _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<dynamic> _list(dynamic value) => value is List ? value : const <dynamic>[];

class Station {
  const Station({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.source,
    required this.streamType,
    this.nameEn,
    this.description,
    this.logoUrl,
    this.categoryId,
    this.playbackUrl,
    this.timezone,
    this.status,
    this.healthStatus,
    this.isFeatured = false,
    this.attribution,
  });

  final String id;
  final String slug;
  final String nameAr;
  final String? nameEn;
  final String? description;
  final String? logoUrl;
  final String? categoryId;
  final String source;
  final String streamType;
  final String? playbackUrl;
  final String? timezone;
  final String? status;
  final String? healthStatus;
  final bool isFeatured;
  final String? attribution;

  bool get isInternal => source == 'INTERNAL';
  bool get isExternal => source == 'EXTERNAL';
  bool get isPlayable => playbackUrl != null && playbackUrl!.isNotEmpty;

  factory Station.fromJson(JsonMap json) => Station(
        id: _string(json['id']),
        slug: _string(json['slug']),
        nameAr: _string(json['name_ar']),
        nameEn: _nullableString(json['name_en']),
        description: _nullableString(json['description']),
        logoUrl: _nullableString(json['logo_url']),
        categoryId: _nullableString(json['category_id']),
        source: _string(json['station_source']),
        streamType: _string(json['stream_type']),
        playbackUrl: _nullableString(json['playback_url']),
        timezone: _nullableString(json['timezone']),
        status: _nullableString(json['status']),
        healthStatus: _nullableString(json['health_status']),
        isFeatured: _bool(json['is_featured']),
        attribution: _nullableString(json['attribution']),
      );

  JsonMap toJson() => <String, dynamic>{
        'id': id,
        'slug': slug,
        'name_ar': nameAr,
        'name_en': nameEn,
        'description': description,
        'logo_url': logoUrl,
        'category_id': categoryId,
        'station_source': source,
        'stream_type': streamType,
        'playback_url': playbackUrl,
        'timezone': timezone,
        'status': status,
        'health_status': healthStatus,
        'is_featured': isFeatured,
        'attribution': attribution,
      };
}

class Category {
  const Category({required this.id, required this.slug, required this.nameAr, this.nameEn, this.description, this.iconKey, this.sortOrder = 0});
  final String id;
  final String slug;
  final String nameAr;
  final String? nameEn;
  final String? description;
  final String? iconKey;
  final int sortOrder;
  factory Category.fromJson(JsonMap json) => Category(
        id: _string(json['id']), slug: _string(json['slug']), nameAr: _string(json['name_ar']),
        nameEn: _nullableString(json['name_en']), description: _nullableString(json['description']),
        iconKey: _nullableString(json['icon_key']), sortOrder: _int(json['sort_order']),
      );
  JsonMap toJson() => <String, dynamic>{'id': id, 'slug': slug, 'name_ar': nameAr, 'name_en': nameEn, 'description': description, 'icon_key': iconKey, 'sort_order': sortOrder};
}

class Reciter {
  const Reciter({required this.id, required this.slug, required this.nameAr, this.nameEn, this.imageUrl, this.country, this.rewaya, this.description});
  final String id;
  final String slug;
  final String nameAr;
  final String? nameEn;
  final String? imageUrl;
  final String? country;
  final String? rewaya;
  final String? description;
  factory Reciter.fromJson(JsonMap json) => Reciter(
        id: _string(json['id']), slug: _string(json['slug']), nameAr: _string(json['name_ar']),
        nameEn: _nullableString(json['name_en']), imageUrl: _nullableString(json['image_url']),
        country: _nullableString(json['country']), rewaya: _nullableString(json['rewaya']), description: _nullableString(json['description']),
      );
  JsonMap toJson() => <String, dynamic>{'id': id, 'slug': slug, 'name_ar': nameAr, 'name_en': nameEn, 'image_url': imageUrl, 'country': country, 'rewaya': rewaya, 'description': description};
}

class Surah {
  const Surah({required this.id, required this.number, required this.nameAr, required this.nameEn, required this.ayahCount});
  final int id;
  final int number;
  final String nameAr;
  final String nameEn;
  final int ayahCount;
  factory Surah.fromJson(JsonMap json) => Surah(id: _int(json['id']), number: _int(json['number']), nameAr: _string(json['name_ar']), nameEn: _string(json['name_en']), ayahCount: _int(json['ayah_count']));
  JsonMap toJson() => <String, dynamic>{'id': id, 'number': number, 'name_ar': nameAr, 'name_en': nameEn, 'ayah_count': ayahCount};
}

class ReciterTrack {
  const ReciterTrack({required this.id, required this.surah, this.mediaId, this.durationMs, this.quality, this.rewaya, this.format, this.bitrateKbps, this.playbackUrl});
  final String id;
  final Surah surah;
  final String? mediaId;
  final int? durationMs;
  final String? quality;
  final String? rewaya;
  final String? format;
  final int? bitrateKbps;
  final String? playbackUrl;
  bool get isPlayable => playbackUrl != null && playbackUrl!.isNotEmpty;
  factory ReciterTrack.fromJson(JsonMap json) {
    final track = _map(json['track']);
    return ReciterTrack(
      id: _string(track['id']), surah: Surah.fromJson(_map(json['surah'])), mediaId: _nullableString(track['media_id']),
      durationMs: track['duration_ms'] == null ? null : _int(track['duration_ms']), quality: _nullableString(track['quality']),
      rewaya: _nullableString(track['rewaya']), format: _nullableString(track['format']),
      bitrateKbps: track['bitrate_kbps'] == null ? null : _int(track['bitrate_kbps']), playbackUrl: _nullableString(track['playback_url']),
    );
  }
}

class NowPlaying {
  const NowPlaying({required this.stationId, required this.stationSlug, required this.isLive, this.title, this.subtitle, this.startedAt, this.expectedEndAt, this.source, this.mediaId});
  final String stationId;
  final String stationSlug;
  final bool isLive;
  final String? title;
  final String? subtitle;
  final DateTime? startedAt;
  final DateTime? expectedEndAt;
  final String? source;
  final String? mediaId;
  factory NowPlaying.fromJson(JsonMap json) {
    final station = _map(json['station']);
    final media = _map(json['media']);
    return NowPlaying(
      stationId: _string(station['id']), stationSlug: _string(station['slug']), isLive: _bool(json['is_live'], true),
      title: _nullableString(json['title']), subtitle: _nullableString(json['subtitle']), mediaId: _nullableString(media['id']),
      startedAt: DateTime.tryParse(_string(json['started_at'])), expectedEndAt: DateTime.tryParse(_string(json['expected_end_at'])), source: _nullableString(json['source']),
    );
  }
}

class FeaturedItem {
  const FeaturedItem({required this.type, required this.id, required this.nameAr, this.slug, this.nameEn, this.logoUrl, this.playbackUrl});
  final String type;
  final String id;
  final String nameAr;
  final String? slug;
  final String? nameEn;
  final String? logoUrl;
  final String? playbackUrl;
  factory FeaturedItem.fromJson(JsonMap json) => FeaturedItem(type: _string(json['type']), id: _string(json['id']), nameAr: _string(json['name_ar']), slug: _nullableString(json['slug']), nameEn: _nullableString(json['name_en']), logoUrl: _nullableString(json['logo_url']), playbackUrl: _nullableString(json['playback_url']));
  JsonMap toJson() => <String, dynamic>{'type': type, 'id': id, 'name_ar': nameAr, 'slug': slug, 'name_en': nameEn, 'logo_url': logoUrl, 'playback_url': playbackUrl};
}

class SearchBundle {
  const SearchBundle({required this.stations, required this.reciters, required this.surahs});
  final List<Station> stations;
  final List<Reciter> reciters;
  final List<Surah> surahs;
  factory SearchBundle.fromJson(JsonMap json) => SearchBundle(
        stations: _list(json['stations']).map((e) => Station.fromJson(_map(e))).toList(growable: false),
        reciters: _list(json['reciters']).map((e) => Reciter.fromJson(_map(e))).toList(growable: false),
        surahs: _list(json['surahs']).map((e) => Surah.fromJson(_map(e))).toList(growable: false),
      );
}

class PageResult<T> {
  const PageResult({required this.data, required this.page, required this.limit, required this.total, this.nextPage});
  final List<T> data;
  final int page;
  final int limit;
  final int total;
  final int? nextPage;
}

JsonMap jsonMap(dynamic value) => _map(value);
List<dynamic> jsonList(dynamic value) => _list(value);
