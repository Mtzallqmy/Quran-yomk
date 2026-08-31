import 'api.dart';
import 'models.dart';
import 'offline_clip_contract.dart';
import 'quran_models.dart';
import 'storage.dart';
import 'virtual_radio.dart';

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
    const key = 'stations-v3';
    final cached = refresh ? null : cache.read(key, const Duration(minutes: 5));
    if (cached is List) {
      return cached
          .map((e) => Station.fromJson(jsonMap(e)))
          .toList(growable: false);
    }
    try {
      final values = <Station>[];
      var page = 1;
      for (var guard = 0; guard < 20; guard++) {
        final result = await api.stations(page: page, limit: 200);
        values.addAll(result.data);
        final next = result.nextPage;
        if (next == null || next <= page) break;
        page = next;
      }
      final deduped = <String, Station>{
        for (final station in values) station.id: station,
      }.values.toList(growable: false);
      await cache.write(
        key,
        deduped.map((e) => e.toJson()).toList(growable: false),
      );
      return deduped;
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

  Future<OfflineClipPolicy> offlineClipPolicy(String stationSlug) =>
      api.offlineClipPolicy(stationSlug);

  Future<VirtualRadioResolution> virtualRadio({
    List<String> failedStationIds = const <String>[],
  }) async => VirtualRadioResolution.fromJson(
    await api.virtualRadio(failedStationIds: failedStationIds),
  );

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

  Future<QuranPassage> quranPassage(
    QuranBrowseMode mode,
    int number, {
    bool refresh = false,
  }) async {
    final key = 'quran:${mode.name}:$number';
    final maxAge = mode == QuranBrowseMode.surah
        ? const Duration(days: 1)
        : const Duration(hours: 6);
    final cached = refresh ? null : cache.read(key, maxAge);
    if (cached is Map) return QuranPassage.fromJson(jsonMap(cached));
    try {
      final result = await api.quranPassage(mode, number);
      await cache.write(key, <String, dynamic>{
        'mode': result.mode.name,
        'number': result.number,
        'source': result.source,
        'total_pages': result.totalPages,
        'tajweed_available': result.tajweedAvailable,
        'verses': result.verses
            .map((verse) => <String, dynamic>{
                  'global_number': verse.globalNumber,
                  'surah_number': verse.surahNumber,
                  'ayah_number': verse.ayahNumber,
                  'verse_key': verse.verseKey,
                  'text_uthmani': verse.textUthmani,
                  'text_tajweed': verse.textTajweed,
                  'juz_number': verse.juzNumber,
                  'page_number': verse.pageNumber,
                  'ruku_number': verse.rukuNumber,
                  'hizb_quarter': verse.hizbQuarter,
                  'sajda': verse.sajda,
                  'surah_name_ar': verse.surahNameAr,
                  'surah_name_en': verse.surahNameEn,
                })
            .toList(growable: false),
        'theme_sections': result.themeSections
            .map((section) => <String, dynamic>{
                  'surah_number': section.surahNumber,
                  'from_ayah': section.fromAyah,
                  'to_ayah': section.toAyah,
                  'title_ar': section.titleAr,
                  'title_en': section.titleEn,
                  'color_key': section.colorKey,
                  'ruku_number': section.rukuNumber,
                })
            .toList(growable: false),
      });
      return result;
    } catch (_) {
      final stale = cache.readStale(key);
      if (stale is Map) return QuranPassage.fromJson(jsonMap(stale));
      rethrow;
    }
  }

  Future<List<QuranAudioReciter>> quranAudioReciters(
    int surahNumber, {
    bool refresh = false,
  }) async {
    final key = 'quran:audio-reciters:$surahNumber';
    final cached = refresh
        ? null
        : cache.read(key, const Duration(hours: 6));
    if (cached is List) {
      return cached
          .map((e) => QuranAudioReciter.fromJson(jsonMap(e)))
          .toList(growable: false);
    }
    try {
      final values = await api.quranAudioReciters(surahNumber);
      await cache.write(
        key,
        values
            .map((reciter) => <String, dynamic>{
                  'id': reciter.id,
                  'provider_reciter_id': reciter.providerReciterId,
                  'moshaf_id': reciter.moshafId,
                  'name_ar': reciter.nameAr,
                  'name_en': reciter.nameEn,
                  'rewaya_ar': reciter.rewayaAr,
                  'rewaya_en': reciter.rewayaEn,
                  'image_url': reciter.imageUrl,
                  'available_surahs': reciter.availableSurahs.toList()..sort(),
                })
            .toList(growable: false),
      );
      return values;
    } catch (_) {
      final stale = cache.readStale(key);
      if (stale is List) {
        return stale
            .map((e) => QuranAudioReciter.fromJson(jsonMap(e)))
            .toList(growable: false);
      }
      rethrow;
    }
  }

  Future<List<QuranAudioTrack>> quranAudioTracks(String reciterId) =>
      api.quranAudioTracks(reciterId);

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
