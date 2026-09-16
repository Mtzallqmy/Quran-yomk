import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_models.dart';

class QuranYutlaRepository {
  final List<RadioStationModel> stations = const [
    RadioStationModel(
      id: 'station-1',
      nameAr: 'إذاعة التلاوات الخاشعة',
      streamUrl: 'https://stream.quranyutla.app/live/khashia.mp3',
      currentTrack: 'سورة مريم — الشيخ عبد الباسط عبد الصمد',
      bitrateKbps: 128,
      isFeatured: true,
      listenerCount: 1420,
    ),
    RadioStationModel(
      id: 'station-2',
      nameAr: 'إذاعة المصحف المرتل',
      streamUrl: 'https://stream.quranyutla.app/live/murattal.mp3',
      currentTrack: 'سورة البقرة — الشيخ محمود خليل الحصري',
      bitrateKbps: 128,
      isFeatured: true,
      listenerCount: 890,
    ),
    RadioStationModel(
      id: 'station-3',
      nameAr: 'إذاعة تلاوات الحرمين الشريفين',
      streamUrl: 'https://stream.quranyutla.app/live/haramain.mp3',
      currentTrack: 'تلاوات المسجد الحرام والمسجد النبوي',
      bitrateKbps: 128,
      isFeatured: false,
      listenerCount: 640,
    ),
    RadioStationModel(
      id: 'station-4',
      nameAr: 'إذاعة الشيخ محمد صديق المنشاوي',
      streamUrl: 'https://stream.quranyutla.app/live/minshawi.mp3',
      currentTrack: 'المصحف المجود والمرتل',
      bitrateKbps: 128,
      isFeatured: false,
      listenerCount: 510,
    ),
  ];

  final List<ReciterModel> reciters = const [
    ReciterModel(
      id: 'reciter-1',
      nameAr: 'الشيخ عبد الباسط عبد الصمد',
      riwaya: 'المصحف المجود • حفص عن عاصم',
      surahsCount: 114,
      bio: 'من كبار أعلام قراء القرآن الكريم في العالم الإسلامي، تميز بجمال صوته وأدائه المحكم.',
      provider: 'مجمع الملك فهد / أرشيف إذاعة القرآن',
      audioQuality: '192 kbps • MP3',
    ),
    ReciterModel(
      id: 'reciter-2',
      nameAr: 'الشيخ محمد صديق المنشاوي',
      riwaya: 'المصحف المرتل • حفص عن عاصم',
      surahsCount: 114,
      bio: 'تميز بنبرته الخاشعة الباكية وصوته الرخيم، صاحب التلاوة المؤثرة.',
      provider: 'مجمع الملك فهد / أرشيف القاهرة',
      audioQuality: '192 kbps • MP3',
    ),
    ReciterModel(
      id: 'reciter-3',
      nameAr: 'الشيخ محمود خليل الحصري',
      riwaya: 'المصحف المرتل • رواية ورش عن نافع',
      surahsCount: 114,
      bio: 'شيخ عموم المقارئ المصرية الأسبق وأول من سجل المصحف المرتل بروايات متعددة.',
      provider: 'مجمع الملك فهد',
      audioQuality: '192 kbps • MP3',
    ),
    ReciterModel(
      id: 'reciter-4',
      nameAr: 'الشيخ علي عبد الله جابر',
      riwaya: 'تلاوات الحرم المكي • حفص عن عاصم',
      surahsCount: 114,
      bio: 'إمام المسجد الحرام الأسبق رحمه الله، صاحب القراءة الهادئة العذبة.',
      provider: 'أرشيف الحرم المكي الشريف',
      audioQuality: '192 kbps • MP3',
    ),
  ];

  final List<DhikrModel> adhkarList = const [
    DhikrModel(
      id: 'd-1',
      title: 'أذكار الصباح',
      text: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لاَ إِلَـهَ إِلاَّ اللهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
      targetCount: 1,
      currentCount: 1,
      reward: 'حفظ من الشرور حتى يمسي',
    ),
    DhikrModel(
      id: 'd-2',
      title: 'سيد الاستغفار',
      text: 'اللَّهُمَّ أَنْتَ رَبِّي لاَ إِلَهَ إِلاَّ أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ لَكَ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لاَ يَغْفِرُ الذُّنُوبَ إِلاَّ أَنْتَ.',
      targetCount: 1,
      currentCount: 0,
      reward: 'موجبة للجنة لمن قالها موقناً بها',
    ),
    DhikrModel(
      id: 'd-3',
      title: 'التسبيح والتحميد',
      text: 'سُبْحَانَ اللهِ وَبِحَمْدِهِ',
      targetCount: 100,
      currentCount: 33,
      reward: 'حُطّت خطاياه وإن كانت مثل زبد البحر',
    ),
  ];

  final List<MemorizationPlanModel> memorizationPlans = const [
    MemorizationPlanModel(
      id: 'm-1',
      title: 'خطة حفظ جزء عمّ',
      targetSurah: 'سورة النبأ',
      currentVerse: 25,
      targetVerse: 40,
      completedPercent: 62,
      dueReviewDays: 0,
    ),
    MemorizationPlanModel(
      id: 'm-2',
      title: 'مراجعة سورة الكهف الأسبوعية',
      targetSurah: 'سورة الكهف',
      currentVerse: 110,
      targetVerse: 110,
      completedPercent: 100,
      dueReviewDays: 2,
    ),
  ];
}

final quranRepositoryProvider = Provider<QuranYutlaRepository>((ref) {
  return QuranYutlaRepository();
});

// Favorites State
class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super({'station-1', 'reciter-1', 'surah-18'});

  void toggleFavorite(String id) {
    if (state.contains(id)) {
      state = state.where((item) => item != id).toSet();
    } else {
      state = {...state, id};
    }
  }

  bool isFavorite(String id) => state.contains(id);
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier();
});

// Playlists State
class PlaylistsNotifier extends StateNotifier<List<PlaylistModel>> {
  PlaylistsNotifier()
      : super([
          PlaylistModel(
            id: 'pl-1',
            name: 'تلاوات الفجر الخاشعة',
            createdAt: DateTime.now().subtract(const Duration(days: 5)),
            items: const [
              PlaylistItemModel(
                id: 'p1',
                title: 'سورة الفاتحة',
                subtitle: 'الشيخ محمود خليل الحصري',
                audioUrl: 'https://audio.quranyutla.app/001.mp3',
                surahNumber: 1,
                reciterId: 'reciter-3',
              ),
              PlaylistItemModel(
                id: 'p2',
                title: 'سورة الكهف',
                subtitle: 'الشيخ عبد الباسط عبد الصمد',
                audioUrl: 'https://audio.quranyutla.app/018.mp3',
                surahNumber: 18,
                reciterId: 'reciter-1',
              ),
            ],
          ),
          PlaylistModel(
            id: 'pl-2',
            name: 'ورد النوم والسكينة',
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
            items: const [
              PlaylistItemModel(
                id: 'p3',
                title: 'سورة الملك',
                subtitle: 'الشيخ محمد صديق المنشاوي',
                audioUrl: 'https://audio.quranyutla.app/067.mp3',
                surahNumber: 67,
                reciterId: 'reciter-2',
              ),
            ],
          ),
        ]);

  void createPlaylist(String name) {
    final newPl = PlaylistModel(
      id: 'pl-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      createdAt: DateTime.now(),
      items: const [],
    );
    state = [...state, newPl];
  }

  void renamePlaylist(String id, String newName) {
    state = state.map((pl) => pl.id == id ? pl.copyWith(name: newName) : pl).toList();
  }

  void deletePlaylist(String id) {
    state = state.where((pl) => pl.id != id).toList();
  }

  void addItemToPlaylist(String playlistId, PlaylistItemModel item) {
    state = state.map((pl) {
      if (pl.id == playlistId) {
        return pl.copyWith(items: [...pl.items, item]);
      }
      return pl;
    }).toList();
  }
}

final playlistsProvider =
    StateNotifierProvider<PlaylistsNotifier, List<PlaylistModel>>((ref) {
  return PlaylistsNotifier();
});

// Offline Downloads State
class DownloadsNotifier extends StateNotifier<List<DownloadTaskModel>> {
  DownloadsNotifier()
      : super(const [
          DownloadTaskModel(
            id: 'dl-1',
            surahNumber: 18,
            surahNameAr: 'سورة الكهف',
            reciterNameAr: 'الشيخ عبد الباسط عبد الصمد',
            expectedSha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
            progressPercent: 100,
            status: DownloadStatus.completed,
            localPath: '/data/user/0/app.quranyutla/files/quran/018_abdulbasit.mp3',
            totalBytes: 28400000,
            downloadedBytes: 28400000,
          ),
          DownloadTaskModel(
            id: 'dl-2',
            surahNumber: 36,
            surahNameAr: 'سورة يس',
            reciterNameAr: 'الشيخ محمد صديق المنشاوي',
            expectedSha256: 'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb',
            progressPercent: 65,
            status: DownloadStatus.downloading,
            localPath: '/data/user/0/app.quranyutla/files/quran/036_minshawi.mp3.part',
            totalBytes: 16200000,
            downloadedBytes: 10530000,
          ),
        ]);

  void addDownload(int surahNumber, String surahName, String reciterName) {
    final newTask = DownloadTaskModel(
      id: 'dl-${DateTime.now().millisecondsSinceEpoch}',
      surahNumber: surahNumber,
      surahNameAr: surahName,
      reciterNameAr: reciterName,
      expectedSha256: 'canonical_sha256_verified_hash',
      progressPercent: 15,
      status: DownloadStatus.downloading,
      totalBytes: 24000000,
      downloadedBytes: 3600000,
    );
    state = [...state, newTask];
  }

  void deleteDownload(String id) {
    state = state.where((d) => d.id != id).toList();
  }

  void togglePauseResume(String id) {
    state = state.map((d) {
      if (d.id == id) {
        final newStatus = d.status == DownloadStatus.downloading
            ? DownloadStatus.paused
            : DownloadStatus.downloading;
        return d.copyWith(status: newStatus);
      }
      return d;
    }).toList();
  }
}

final downloadsProvider =
    StateNotifierProvider<DownloadsNotifier, List<DownloadTaskModel>>((ref) {
  return DownloadsNotifier();
});
