import 'api.dart';
import 'models.dart';
import 'storage.dart';

class HomeData {
  const HomeData({
    required this.featured,
    required this.stations,
    required this.reciters,
    required this.categories,
    required this.config,
  });
  final List<FeaturedItem> featured;
  final List<Station> stations;
  final List<Reciter> reciters;
  final List<Category> categories;
  final JsonMap config;
}

class TarteelRepository {
  TarteelRepository(this.api, this.cache);
  final TarteelApiClient api;
  final MetadataCache cache;

  Future<HomeData> home({bool refresh = false}) async {
    final values = await Future.wait<Object>(<Future<Object>>[
      featured(refresh: refresh),
      stations(refresh: refresh),
      reciters(refresh: refresh),
      categories(refresh: refresh),
      appConfig(refresh: refresh),
    ]);
    return HomeData(
      featured: values[0] as List<FeaturedItem>,
      stations: values[1] as List<Station>,
      reciters: values[2] as List<Reciter>,
      categories: values[3] as List<Category>,
      config: values[4] as JsonMap,
    );
  }

  Future<List<Station>> stations({bool refresh = false}) async {
    const key = 'stations';
    final cached = refresh ? null : cache.read(key, const Duration(minutes: 5));
    if (cached is List) {
      return cached
          .map((e) => Station.fromJson(jsonMap(e)))
          .toList(growable: false);
    }
    try {
      final result = (await api.stations()).data;
      await cache.write(
        key,
        result.map((e) => e.toJson()).toList(growable: false),
      );
      return result;
    } catch (_) {
      final stale = cache.readStale(key);
      if (stale is List) {
        return stale
            .map((e) => Station.fromJson(jsonMap(e)))
            .toList(growable: false);
      }
      rethrow;
    }
  }

  Future<List<Category>> categories({bool refresh = false}) async {
    const key = 'categories';
    final cached = refresh ? null : cache.read(key, const Duration(hours: 1));
    if (cached is List) {
      return cached
          .map((e) => Category.fromJson(jsonMap(e)))
          .toList(growable: false);
    }
    try {
      final result = await api.categories();
      await cache.write(
        key,
        result.map((e) => e.toJson()).toList(growable: false),
      );
      return result;
    } catch (_) {
      final stale = cache.readStale(key);
      if (stale is List) {
        return stale
            .map((e) => Category.fromJson(jsonMap(e)))
            .toList(growable: false);
      }
      rethrow;
    }
  }

  Future<List<Reciter>> reciters({bool refresh = false}) async {
    const key = 'reciters';
    final cached = refresh
        ? null
        : cache.read(key, const Duration(minutes: 30));
    if (cached is List) {
      return cached
          .map((e) => Reciter.fromJson(jsonMap(e)))
          .toList(growable: false);
    }
    try {
      final result = (await api.reciters(limit: 50)).data;
      await cache.write(
        key,
        result.map((e) => e.toJson()).toList(growable: false),
      );
      return result;
    } catch (_) {
      final stale = cache.readStale(key);
      if (stale is List) {
        return stale
            .map((e) => Reciter.fromJson(jsonMap(e)))
            .toList(growable: false);
      }
      rethrow;
    }
  }

  Future<PageResult<Reciter>> searchReciters(String query, {int page = 1}) =>
      api.reciters(query: query, page: page, limit: 30);

  Future<List<Surah>> surahs({bool refresh = false}) async {
    const key = 'surahs';
    final cached = refresh ? null : cache.read(key, const Duration(days: 7));
    if (cached is List) {
      final result = cached
          .map((e) => Surah.fromJson(jsonMap(e)))
          .toList(growable: false);
      if (result.length == 114) return result;
    }
    try {
      final result = await api.surahs();
      await cache.write(
        key,
        result.map((e) => e.toJson()).toList(growable: false),
      );
      return result;
    } catch (_) {
      final stale = cache.readStale(key);
      if (stale is List) {
        final result = stale
            .map((e) => Surah.fromJson(jsonMap(e)))
            .toList(growable: false);
        if (result.length == 114) return result;
      }
      rethrow;
    }
  }

  Future<List<FeaturedItem>> featured({bool refresh = false}) async {
    const key = 'featured';
    final cached = refresh ? null : cache.read(key, const Duration(minutes: 5));
    if (cached is List) {
      return cached
          .map((e) => FeaturedItem.fromJson(jsonMap(e)))
          .toList(growable: false);
    }
    try {
      final result = await api.featured();
      await cache.write(
        key,
        result.map((e) => e.toJson()).toList(growable: false),
      );
      return result;
    } catch (_) {
      final stale = cache.readStale(key);
      if (stale is List) {
        return stale
            .map((e) => FeaturedItem.fromJson(jsonMap(e)))
            .toList(growable: false);
      }
      rethrow;
    }
  }

  Future<JsonMap> appConfig({bool refresh = false}) async {
    const key = 'app-config';
    final cached = refresh
        ? null
        : cache.read(key, const Duration(minutes: 10));
    if (cached is Map) return jsonMap(cached);
    try {
      final result = await api.appConfig();
      await cache.write(key, result);
      return result;
    } catch (_) {
      final stale = cache.readStale(key);
      if (stale is Map) return jsonMap(stale);
      rethrow;
    }
  }

  Future<NowPlaying> nowPlaying(String slug) => api.nowPlaying(slug);
  Future<List<ReciterTrack>> reciterTracks(String id) => api.reciterTracks(id);
  Future<SearchBundle> search(String query) => api.search(query);
}
