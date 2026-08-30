import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../services.dart';
import 'radio.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});
  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryData {
  const _LibraryData(this.categories, this.surahs);
  final List<Category> categories;
  final List<Surah> surahs;
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  late Future<_LibraryData> future;
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_LibraryData> load({bool refresh = false}) async {
    final repo = ref.read(servicesProvider).repository;
    final categories = await repo.categories(refresh: refresh);
    final surahs = await repo.surahs(refresh: refresh);
    return _LibraryData(categories, surahs);
  }

  void _openCategory(Category category) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => RadioBrowsePage(
        initialCategory: category.slug,
        initialSource: 'EXTERNAL',
        title: category.nameAr,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<_LibraryData>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done &&
          !snapshot.hasData) {
        return const LoadingPane();
      }
      if (snapshot.hasError && !snapshot.hasData) {
        return ErrorPane(
          error: snapshot.error!,
          onRetry: () => setState(() => future = load(refresh: true)),
        );
      }
      final data = snapshot.data;
      if (data == null) return const EmptyPane();
      return RefreshIndicator(
        onRefresh: () async {
          setState(() => future = load(refresh: true));
          await future;
        },
        child: ListView(
          children: <Widget>[
            const SectionHeader('التصنيفات'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: data.categories
                    .map(
                      (category) => ActionChip(
                        avatar: const Icon(Icons.folder_outlined, size: 18),
                        label: Text(category.nameAr),
                        onPressed: () => _openCategory(category),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            const SectionHeader('سور القرآن — 114 سورة'),
            for (final surah in data.surahs)
              ListTile(
                leading: CircleAvatar(child: Text('${surah.number}')),
                title: Text(surah.nameAr),
                subtitle: Text('${surah.nameEn} • ${surah.ayahCount} آية'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SurahDetailPage(surah: surah),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      );
    },
  );
}

class SurahDetailPage extends ConsumerStatefulWidget {
  const SurahDetailPage({super.key, required this.surah});
  final Surah surah;

  @override
  ConsumerState<SurahDetailPage> createState() => _SurahDetailPageState();
}

class _SurahDetailPageState extends ConsumerState<SurahDetailPage> {
  late Future<List<Reciter>> future;
  String? loadingReciter;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<List<Reciter>> _load() async {
    final page = await ref
        .read(servicesProvider)
        .repository
        .api
        .reciters(surah: widget.surah.number, limit: 100);
    return page.data;
  }

  Future<void> _play(Reciter reciter) async {
    if (loadingReciter != null) return;
    setState(() => loadingReciter = reciter.id);
    try {
      final services = ref.read(servicesProvider);
      final tracks = await services.repository.api.reciterTracks(reciter.id);
      final index = tracks.indexWhere(
        (track) =>
            track.surah.number == widget.surah.number && track.isPlayable,
      );
      if (index < 0) {
        throw StateError('No playable track for this surah');
      }
      await services.playback.playTracks(tracks, index, reciter);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يتم الآن تشغيل ${widget.surah.nameAr} — ${reciter.nameAr}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تشغيل هذه التلاوة الآن. جرّب قارئًا آخر.'),
        ),
      );
    } finally {
      if (mounted) setState(() => loadingReciter = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.surah.nameAr)),
    body: FutureBuilder<List<Reciter>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const LoadingPane();
        }
        if (snapshot.hasError && !snapshot.hasData) {
          return ErrorPane(
            error: snapshot.error!,
            onRetry: () => setState(() => future = _load()),
          );
        }
        final reciters = snapshot.data ?? const <Reciter>[];
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(18),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 30,
                        child: Text('${widget.surah.number}'),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              widget.surah.nameAr,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              '${widget.surah.nameEn} • ${widget.surah.ayahCount} آية',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SectionHeader('اختر القارئ للتشغيل'),
            if (reciters.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('لا توجد تلاوة متاحة لهذه السورة حاليًا.'),
              )
            else
              ...reciters.map(
                (reciter) => ListTile(
                  leading: Artwork(
                    url: reciter.imageUrl,
                    size: 48,
                    icon: Icons.record_voice_over_outlined,
                  ),
                  title: Text(reciter.nameAr),
                  subtitle: reciter.rewaya == null
                      ? const Text('تلاوة خارجية')
                      : Text(reciter.rewaya!),
                  trailing: loadingReciter == reciter.id
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton.filledTonal(
                          tooltip: 'تشغيل السورة',
                          onPressed: () => _play(reciter),
                          icon: const Icon(Icons.play_arrow),
                        ),
                  onTap: () => _play(reciter),
                ),
              ),
          ],
        );
      },
    ),
  );
}
