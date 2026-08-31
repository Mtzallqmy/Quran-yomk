import 'package:flutter/foundation.dart';

import 'quran_audio.dart';

enum QuranDownloadState {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

class QuranDownloadTask {
  const QuranDownloadTask({
    required this.id,
    required this.media,
    required this.state,
    required this.downloadedBytes,
    required this.createdAt,
    this.totalBytes,
    this.localPath,
    this.actualChecksumSha256,
    this.error,
  });

  final String id;
  final QuranAudioMedia media;
  final QuranDownloadState state;
  final int downloadedBytes;
  final int? totalBytes;
  final DateTime createdAt;
  final String? localPath;
  final String? actualChecksumSha256;
  final String? error;

  double? get progress => totalBytes == null || totalBytes == 0
      ? null
      : (downloadedBytes / totalBytes!).clamp(0, 1);
}

abstract class QuranDownloadService extends ChangeNotifier
    implements QuranAudioLocalLookup {
  bool get supported;
  List<QuranDownloadTask> get tasks;
  Future<void> initialize();
  Future<QuranDownloadTask> download(QuranAudioMedia media);
  Future<List<QuranDownloadTask>> downloadMany(Iterable<QuranAudioMedia> media);
  Future<List<QuranDownloadTask>> downloadSurahs(
    Iterable<QuranAudioMedia> surahs,
  ) => downloadMany(surahs);
  Future<List<QuranDownloadTask>> downloadMushaf(
    Iterable<QuranAudioMedia> allSurahs,
  ) {
    final values = allSurahs.toList(growable: false);
    if (values.map((item) => item.surah.number).toSet().length != 114) {
      throw ArgumentError.value(
        values.length,
        'allSurahs',
        'Expected 114 surahs',
      );
    }
    return downloadMany(values);
  }

  Future<void> pause(String taskId);
  Future<void> resume(String taskId);
  Future<void> cancel(String taskId);
  Future<void> retry(String taskId);
  Future<void> delete(String taskId);
}
