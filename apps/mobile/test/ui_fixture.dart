import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/announcements.dart';
import 'package:tarteel/src/feature_manager.dart';
import 'package:tarteel/src/islamic_content.dart';
import 'package:tarteel/src/local_notifications.dart';
import 'package:tarteel/src/models.dart';
import 'package:tarteel/src/mushaf_pages.dart';
import 'package:tarteel/src/mushaf_store.dart';
import 'package:tarteel/src/playback.dart';
import 'package:tarteel/src/offline_clip_service.dart';
import 'package:tarteel/src/push_notifications.dart';
import 'package:tarteel/src/quran_audio.dart';
import 'package:tarteel/src/quran_download_contract.dart';
import 'package:tarteel/src/quran_models.dart';
import 'package:tarteel/src/quran_playback_store.dart';
import 'package:tarteel/src/quran_playlist_store.dart';
import 'package:tarteel/src/remote_config.dart';
import 'package:tarteel/src/repository.dart';
import 'package:tarteel/src/services.dart';
import 'package:tarteel/src/storage.dart';
import 'package:tarteel/src/virtual_radio.dart';

/// Deterministic UI fixtures only; never imported by lib/ or production startup.
class UiServices implements AppServices {
  UiServices(SharedPreferences preferences) {
    settings = SettingsStore(preferences)..load();
    favorites = FavoritesStore(preferences)..load();
    mushaf = MushafStore(preferences)..load();
    quranPlayback = QuranPlaybackStore(preferences)..load();
    quranPlaylists = QuranPlaylistStore(preferences)..load();
    remoteConfig = TarteelRemoteConfig(repository, preferences)..load();
    features = FeatureManager(config: remoteConfig, installedVersion: '0.7.2');
    announcements = AnnouncementService(preferences);
  }
  @override
  final UiRepository repository = UiRepository();
  @override
  late final SettingsStore settings;
  @override
  late final FavoritesStore favorites;
  @override
  late final MushafStore mushaf;
  @override
  late final QuranPlaybackStore quranPlayback;
  @override
  late final QuranPlaylistStore quranPlaylists;
  @override
  late final TarteelRemoteConfig remoteConfig;
  @override
  late final FeatureManager features;
  @override
  late final AnnouncementService announcements;
  @override
  final UiPlayback playback = UiPlayback();
  @override
  final OfflineClipService offlineClips = UiClips();
  @override
  final QuranAudioRepository quranAudio = UiAudio();
  @override
  final QuranDownloadService quranDownloads = UiDownloads();
  @override
  final MushafPageRepository mushafPages = UiPages();
  @override
  final IslamicContentRepository islamicContent = UiContent();
  @override
  final LocalNotificationService localNotifications = UiNotifications();
  @override
  final PushNotificationService pushNotifications = UiPush();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class UiRepository implements TarteelRepository {
  final openedPages = <int>[];
  List<Station> stationValues = [];
  @override
  Future<NowPlaying> nowPlaying(String slug) async => NowPlaying(
    stationId: stationValues.first.id,
    stationSlug: slug,
    isLive: true,
    title: 'تلاوة من بيانات الاختبار',
  );
  JsonMap config = {'radio_enabled': true, 'prayer_features_enabled': false};
  @override
  Future<JsonMap> appConfig({bool refresh = false}) async => config;
  @override
  Future<List<Surah>> surahs({bool refresh = false}) async => const [
    Surah(
      id: 1,
      number: 1,
      nameAr: 'الفاتحة',
      nameEn: 'Al-Fatihah',
      ayahCount: 7,
    ),
    Surah(
      id: 2,
      number: 2,
      nameAr: 'البقرة',
      nameEn: 'Al-Baqarah',
      ayahCount: 286,
    ),
  ];
  @override
  Future<List<Station>> stations({bool refresh = false}) async => stationValues;
  @override
  Future<List<Reciter>> reciters({bool refresh = false}) async => [];
  @override
  Future<SearchBundle> search(String query) async =>
      const SearchBundle(stations: [], reciters: [], surahs: []);
  @override
  Future<QuranPassage> quranPassage(
    QuranBrowseMode mode,
    int number, {
    bool refresh = false,
  }) async {
    openedPages.add(number);
    return QuranPassage(
      mode: mode,
      number: number,
      source: 'TEST_ONLY',
      verses: const [],
      themeSections: const [],
    );
  }

  @override
  Future<VirtualRadioResolution> virtualRadio({
    List<String> failedStationIds = const [],
  }) async => VirtualRadioResolution.fromJson({
    'available': false,
    'server_time': '2026-09-30T00:00:00Z',
  });
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class UiAudio implements QuranAudioRepository {
  List<QuranAudioCatalogReciter> values = [];
  @override
  Future<List<QuranAudioCatalogReciter>> reciters({
    int? surahNumber,
    bool refresh = false,
  }) async => values;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class UiDownloads extends QuranDownloadService {
  @override
  Future<void> initialize() async {}
  @override
  bool get supported => true;
  @override
  List<QuranDownloadTask> get tasks => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class UiPages extends ChangeNotifier implements MushafPageRepository {
  @override
  Future<MushafPageAsset> page(int page, MushafPageEdition edition) async =>
      throw MushafAssetUnavailableOfflineException(page, edition);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class UiContent implements IslamicContentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class UiNotifications implements LocalNotificationService {
  @override
  Stream<String> get payloads => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class UiPush implements PushNotificationService {
  @override
  Stream<String> get routes => const Stream.empty();
  @override
  bool get needsConsent => false;
  @override
  Future<void> refreshPermissionState() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class UiPlayback implements PlaybackPort {
  MediaItem? item;
  Duration position = Duration.zero;
  bool playing = false;
  int playCalls = 0;
  int pauseCalls = 0;
  final playedStations = <Station>[];
  @override
  Future<void> playStation(Station station) async {
    playedStations.add(station);
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Stream<MediaItem?> get mediaItemStream => Stream.value(item);
  @override
  Stream<PlaybackState> get playbackStateStream => Stream.value(
    PlaybackState(
      playing: playing,
      processingState: item == null
          ? AudioProcessingState.idle
          : AudioProcessingState.ready,
    ),
  );
  @override
  Stream<Duration> get positionStream => Stream.value(position);
  @override
  Stream<Duration?> get durationStream => Stream.value(item?.duration);
  @override
  Stream<String> get errorStream => const Stream.empty();
  @override
  Stream<Duration?> get sleepRemainingStream => Stream.value(null);
  @override
  Stream<double> get volumeStream => Stream.value(1);
  @override
  bool get isLive => item?.isLive == true;
  @override
  void cancelSleepTimer() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class UiClips extends ChangeNotifier implements OfflineClipService {
  @override
  bool get supported => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const uiRadioStation = Station(
  id: 'test-station',
  slug: 'test-radio',
  nameAr: 'إذاعة الحرم للاختبار',
  source: 'EXTERNAL',
  streamType: 'LIVE',
  category: 'QURAN_GENERAL',
  healthStatus: 'HEALTHY',
  playbackUrl: 'https://example.invalid/test-only.mp3',
  isFeatured: true,
);
