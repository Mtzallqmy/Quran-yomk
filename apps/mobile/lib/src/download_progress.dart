import 'package:flutter/material.dart';
import 'quran_audio.dart';
import 'quran_download_contract.dart';
import 'navigation.dart';

class DownloadProgress extends StatelessWidget {
  const DownloadProgress({super.key, required this.task, this.english = false});
  final QuranDownloadTask task;
  final bool english;
  @override
  Widget build(BuildContext context) {
    final progress = task.progress;
    final status = switch (task.state) {
      QuranDownloadState.queued => english ? 'Queued' : 'بانتظار التنزيل',
      QuranDownloadState.downloading => progress == null ? (english ? 'Downloading' : 'جارٍ التنزيل') : '${(progress * 100).floor()}%',
      QuranDownloadState.paused => english ? 'Paused' : 'متوقف مؤقتًا',
      QuranDownloadState.completed => english ? 'Saved • Available offline' : 'تم الحفظ • متاحة دون إنترنت',
      QuranDownloadState.failed => english ? 'Failed • Tap to retry' : 'فشل التنزيل • أعد المحاولة',
      QuranDownloadState.cancelled => english ? 'Cancelled' : 'ملغى',
    };
    final received = (task.downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
    final total = task.totalBytes == null ? '' : ' / ${(task.totalBytes! / (1024 * 1024)).toStringAsFixed(1)}';
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$status • $received$total MB'),
      if (task.state == QuranDownloadState.downloading || task.state == QuranDownloadState.queued)
        Padding(padding: const EdgeInsets.only(top: 4), child: LinearProgressIndicator(value: progress)),
      if (task.state == QuranDownloadState.failed && task.error != null)
        Text(task.error!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

Future<void> showDownloadProgress(BuildContext context, QuranDownloadService service, QuranAudioMedia media) =>
  showDialog<void>(context: context, builder: (context) => AlertDialog(
    title: Text(media.surah.nameAr),
    content: AnimatedBuilder(animation: service, builder: (context, _) {
      final tasks = service.tasks.where((value) => value.media.storageKey == media.storageKey);
      if (tasks.isEmpty) return const Text('بانتظار بدء التنزيل');
      return DownloadProgress(task: tasks.first);
    }),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
      TextButton(onPressed: () { Navigator.pop(context); Navigator.pushNamed(context, MobileRoutes.downloads); }, child: const Text('كل التنزيلات'))],
  ));
