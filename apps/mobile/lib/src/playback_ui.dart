import 'quran_audio.dart';
import 'quran_models.dart';
import 'quran_playback_store.dart';
import 'services.dart';

/// Resolve persisted identity through the existing catalog. Never choose a
/// different reciter as a fallback when the requested edition is unavailable.
Future<QuranAudioMedia> resolveQuranListening(
  AppServices services,
  QuranPlaybackSnapshot session,
) async {
  if (!session.hasValidIdentity) throw StateError('INVALID_PLAYBACK_IDENTITY');
  final catalog = await services.quranAudio.reciters(
    surahNumber: session.surahNumber,
  );
  final matches = catalog.where(
    (reciter) =>
        reciter.provider.name == session.provider &&
        reciter.id == session.reciterId &&
        reciter.edition == session.edition,
  );
  if (matches.isEmpty) throw StateError('RECITER_UNAVAILABLE');
  final surahs = await services.repository.surahs();
  final surah = surahs.firstWhere(
    (value) => value.number == session.surahNumber,
  );
  int? globalAyah;
  if (session.ayahNumber != null) {
    final passage = await services.repository.quranPassage(
      QuranBrowseMode.surah,
      session.surahNumber,
    );
    globalAyah = passage.verses
        .firstWhere((value) => value.ayahNumber == session.ayahNumber)
        .globalNumber;
  }
  final media = await services.quranAudio.resolve(
    QuranAudioRequest(
      surah: surah,
      reciter: matches.first,
      bitrateKbps: session.bitrateKbps,
      ayahGlobalNumber: globalAyah,
      ayahInSurah: session.ayahNumber,
    ),
  );
  return media;
}

Future<void> resumeQuranListening(
  AppServices services,
  QuranPlaybackSnapshot session,
) async {
  final media = await resolveQuranListening(services, session);
  await services.playback.playQuranAudio([media], 0);
  await services.playback.seek(session.position);
  await services.playback.setSpeed(services.settings.playbackSpeed);
}
