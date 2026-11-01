import 'package:shared_preferences/shared_preferences.dart';

import 'quran_audio.dart';
import 'quran_download_contract.dart';

QuranDownloadService createQuranDownloadService(
  SharedPreferences preferences,
) => _UnsupportedQuranDownloadService();

class _UnsupportedQuranDownloadService extends QuranDownloadService {
  @override
  bool get supported => false;
  @override
  List<QuranDownloadTask> get tasks => const <QuranDownloadTask>[];
  @override
  Future<void> initialize() async {}
  @override
  Future<QuranDownloadTask> download(QuranAudioMedia media) =>
      throw UnsupportedError('QURAN_DOWNLOADS_UNSUPPORTED');
  @override
  Future<List<QuranDownloadTask>> downloadMany(
    Iterable<QuranAudioMedia> media,
  ) => throw UnsupportedError('QURAN_DOWNLOADS_UNSUPPORTED');
  @override
  Future<QuranAudioMedia?> localMedia(QuranAudioMedia remote) async => null;
  @override
  Future<void> pause(String taskId) async {}
  @override
  Future<void> resume(String taskId) async {}
  @override
  Future<void> cancel(String taskId) async {}
  @override
  Future<void> retry(String taskId) async {}
  @override
  Future<void> delete(String taskId) async {}
}
