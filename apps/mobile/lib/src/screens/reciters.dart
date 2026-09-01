import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../quran_audio.dart';
import '../quran_download_contract.dart';
import '../services.dart';

class RecitersPage extends ConsumerStatefulWidget {
  const RecitersPage({super.key});

  @override
  ConsumerState<RecitersPage> createState() => _RecitersPageState();
}

class _RecitersPageState extends ConsumerState<RecitersPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<QuranAudioCatalogReciter> _all = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref
          .read(servicesProvider)
          .quranAudio
          .reciters(refresh: refresh);
      final unique = <String, QuranAudioCatalogReciter>{};
      for (final row in rows) {
        unique[row.identityKey] = row;
      }
      final next = unique.values.toList(growable: false)
        ..sort((a, b) => a.nameAr.compareTo(b.nameAr));
      if (mounted) setState(() => _all = next);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');

  List<QuranAudioCatalogReciter> get _visible {
    final query = _normalize(_search.text);
    if (query.isEmpty) return _all;
    return _all.where((reciter) {
      final haystack = _normalize(
        '${reciter.nameAr} ${reciter.nameEn} ${reciter.riwayah ?? ''}',
      );
      return haystack.contains(query);
    }).toList(growable: false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    if (_error != null && _all.isEmpty) {
      return ErrorPane(error: _error!, onRetry: () => _load(refresh: true));
    }
    final values = _visible;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: english
                  ? 'Search reciters or riwayah'
                  : 'ابحث عن قارئ أو رواية',
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 180), () {
                if (mounted) setState(() {});
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.library_music_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  english
                      ? '${values.length} available reciter editions'
                      : '${values.length} قارئ/رواية متاحة',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              IconButton(
                tooltip: english ? 'Refresh' : 'تحديث القراء',
                onPressed: _loading ? null : () => _load(refresh: true),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading && _all.isEmpty
              ? const LoadingPane()
              : values.isEmpty
              ? EmptyPane(
                  message: english ? 'No matching reciters' : 'لا يوجد قارئ مطابق',
                )
              : RefreshIndicator(
                  onRefresh: () => _load(refresh: true),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 120),
                    itemCount: values.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) => _ReciterTile(
                      reciter: values[index],
                      english: english,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ReciterTile extends ConsumerWidget {
  const _ReciterTile({required this.reciter, required this.english});

  final QuranAudioCatalogReciter reciter;
  final bool english;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    return AnimatedBuilder(
      animation: services.quranDownloads,
      builder: (context, _) {
        final offlineCount = services.quranDownloads.tasks.where((task) {
          return task.state == QuranDownloadState.completed &&
              task.media.reciter.sameIdentity(reciter);
        }).length;
        final displayName = english && reciter.nameEn.isNotEmpty
            ? reciter.nameEn
            : reciter.nameAr;
        final initial = displayName.trim().isEmpty
            ? 'ق'
            : displayName.trim().substring(0, 1);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: CircleAvatar(child: Text(initial)),
          title: Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              if (reciter.riwayah?.isNotEmpty == true) reciter.riwayah!,
              english
                  ? '${reciter.availableSurahs.length} surahs'
                  : '${reciter.availableSurahs.length} سورة',
              if (offlineCount > 0)
                english
                    ? '$offlineCount offline'
                    : '$offlineCount بدون إنترنت',
            ].join(' • '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => QuranAudioReciterDetailPage(reciter: reciter),
            ),
          ),
        );
      },
    );
  }
}

class QuranAudioReciterDetailPage extends ConsumerStatefulWidget {
  const QuranAudioReciterDetailPage({super.key, required this.reciter});

  final QuranAudioCatalogReciter reciter;

  @override
  ConsumerState<QuranAudioReciterDetailPage> createState() =>
      _QuranAudioReciterDetailPageState();
}

class _QuranAudioReciterDetailPageState
    extends ConsumerState<QuranAudioReciterDetailPage> {
  late Future<List<Surah>> _surahs;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _surahs = ref.read(servicesProvider).repository.surahs();
  }

  Future<QuranAudioMedia> _resolve(Surah surah) => ref
      .read(servicesProvider)
      .quranAudio
      .resolve(QuranAudioRequest(surah: surah, reciter: widget.reciter));

  Future<void> _play(Surah surah) async {
    setState(() => _busy.add(surah.number));
    try {
      final media = await _resolve(surah);
      _assertIdentity(media);
      await ref
          .read(servicesProvider)
          .playback
          .playQuranAudio([media], 0);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy.remove(surah.number));
    }
  }

  Future<void> _download(Surah surah) async {
    final services = ref.read(servicesProvider);
    if (!services.remoteConfig.offlineDownloadsEnabled) {
      _message(
        _english
            ? 'Offline downloads are temporarily disabled.'
            : 'التنزيل بدون إنترنت متوقف مؤقتًا.',
      );
      return;
    }
    setState(() => _busy.add(surah.number));
    try {
      final media = await _resolve(surah);
      _assertIdentity(media);
      await services.quranDownloads.download(media);
      if (mounted) {
        _message(
          _english
              ? 'Download queued for ${_surahTitle(surah)}'
              : 'تمت إضافة سورة ${surah.nameAr} إلى التنزيل',
        );
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy.remove(surah.number));
    }
  }

  bool get _english => Localizations.localeOf(context).languageCode == 'en';

  String _surahTitle(Surah surah) =>
      _english && surah.nameEn.isNotEmpty ? surah.nameEn : surah.nameAr;

  void _assertIdentity(QuranAudioMedia media) {
    if (!media.reciter.sameIdentity(widget.reciter)) {
      throw StateError('QURAN_AUDIO_RECITER_MISMATCH');
    }
  }

  void _showError(Object error) {
    final mismatch = error.toString().contains('RECITER_MISMATCH');
    _message(
      mismatch
          ? _english
                ? 'The audio source did not match the selected reciter.'
                : 'تم رفض المصدر لأن القارئ لا يطابق القارئ المحدد.'
          : _english
          ? 'Audio is unavailable for this surah.'
          : 'التلاوة غير متاحة لهذه السورة حاليًا.',
    );
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  QuranDownloadTask? _taskFor(int surahNumber) {
    final tasks = ref.read(servicesProvider).quranDownloads.tasks;
    for (final task in tasks.reversed) {
      if (task.media.surah.number == surahNumber &&
          task.media.reciter.sameIdentity(widget.reciter)) {
        return task;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final english = _english;
    final services = ref.watch(servicesProvider);
    final title = english && widget.reciter.nameEn.isNotEmpty
        ? widget.reciter.nameEn
        : widget.reciter.nameAr;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          AnimatedBuilder(
            animation: services.favorites,
            builder: (_, _) => IconButton(
              tooltip: english ? 'Favorite' : 'المفضلة',
              onPressed: () =>
                  services.favorites.toggleReciter(widget.reciter.id),
              icon: Icon(
                services.favorites.isReciter(widget.reciter.id)
                    ? Icons.favorite
                    : Icons.favorite_border,
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Surah>>(
        future: _surahs,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const LoadingPane();
          }
          if (snapshot.hasError) {
            return ErrorPane(
              error: snapshot.error!,
              onRetry: () => setState(
                () => _surahs = services.repository.surahs(refresh: true),
              ),
            );
          }
          final surahs = (snapshot.data ?? const <Surah>[])
              .where(
                (surah) => widget.reciter.availableSurahs.contains(surah.number),
              )
              .toList(growable: false);
          return AnimatedBuilder(
            animation: services.quranDownloads,
            builder: (context, _) => CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (widget.reciter.riwayah?.isNotEmpty == true) ...[
                              const SizedBox(height: 6),
                              Text(widget.reciter.riwayah!),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              english
                                  ? '${surahs.length} available surahs • downloads stay tied to this exact reciter'
                                  : '${surahs.length} سورة متاحة • التنزيلات مرتبطة بهذا القارئ نفسه',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: surahs.length,
                  itemBuilder: (context, index) {
                    final surah = surahs[index];
                    final task = _taskFor(surah.number);
                    final busy = _busy.contains(surah.number);
                    return ListTile(
                      leading: CircleAvatar(child: Text('${surah.number}')),
                      title: Text(_surahTitle(surah)),
                      subtitle: task == null
                          ? Text(
                              english
                                  ? '${surah.ayahCount} verses'
                                  : '${surah.ayahCount} آية',
                            )
                          : _DownloadStatus(task: task, english: english),
                      trailing: Wrap(
                        spacing: 0,
                        children: [
                          IconButton(
                            tooltip: english ? 'Play' : 'تشغيل',
                            onPressed: busy ? null : () => _play(surah),
                            icon: const Icon(Icons.play_circle_fill),
                          ),
                          if (task?.state == QuranDownloadState.completed)
                            IconButton(
                              tooltip: english ? 'Delete download' : 'حذف التنزيل',
                              onPressed: () =>
                                  services.quranDownloads.delete(task!.id),
                              icon: const Icon(Icons.download_done),
                            )
                          else
                            IconButton(
                              tooltip: english ? 'Download' : 'تنزيل',
                              onPressed: busy ? null : () => _download(surah),
                              icon: busy
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.download_outlined),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DownloadStatus extends StatelessWidget {
  const _DownloadStatus({required this.task, required this.english});

  final QuranDownloadTask task;
  final bool english;

  @override
  Widget build(BuildContext context) {
    final text = switch (task.state) {
      QuranDownloadState.queued => english ? 'Queued' : 'في قائمة التنزيل',
      QuranDownloadState.downloading => task.progress == null
          ? (english ? 'Downloading…' : 'جارٍ التنزيل…')
          : '${(task.progress! * 100).round()}%',
      QuranDownloadState.paused => english ? 'Paused' : 'متوقف مؤقتًا',
      QuranDownloadState.completed => english
          ? 'Available offline'
          : 'متاحة بدون إنترنت',
      QuranDownloadState.failed => english ? 'Download failed' : 'فشل التنزيل',
      QuranDownloadState.cancelled => english ? 'Cancelled' : 'تم الإلغاء',
    };
    return Text(text);
  }
}
