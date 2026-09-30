import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common.dart';
import '../feature_manager.dart';
import '../models.dart';
import '../navigation.dart';
import '../quran_audio.dart';
import '../quran_models.dart';
import '../quran_playlist_store.dart';
import '../services.dart';
import 'legacy_reciter_detail.dart';
import 'quran_index.dart';
import 'quran_playlists.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.initialQuery});
  final String? initialQuery;
  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _request = 0;
  int _filter = 0;
  bool _loading = false;
  bool _partialFailure = false;
  List<Surah> _surahs = [];
  List<Station> _stations = [];
  List<Reciter> _legacy = [];
  List<QuranAudioCatalogReciter> _reciters = [];
  String? _pending;
  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery ?? '';
    if (_controller.text.isNotEmpty)
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _search(_controller.text),
      );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final request = ++_request;
    final normalized = normalizeQuranQuery(query);
    if (normalized.isEmpty) {
      setState(() {
        _loading = false;
        _partialFailure = false;
        _surahs = [];
        _stations = [];
        _legacy = [];
        _reciters = [];
      });
      return;
    }
    setState(() => _loading = true);
    final services = ref.read(servicesProvider);
    var failed = false;
    Future<T> safely<T>(Future<T> value, T fallback) async {
      try {
        return await value;
      } catch (_) {
        failed = true;
        return fallback;
      }
    }

    // A remote directory failure must not discard cached Quran or playlists.
    final values = await Future.wait<Object>([
      safely(
        services.repository.search(query),
        const SearchBundle(stations: [], reciters: [], surahs: []),
      ),
      safely(services.repository.surahs(), <Surah>[]),
      safely(services.quranAudio.reciters(), <QuranAudioCatalogReciter>[]),
    ]);
    if (!mounted || request != _request) return;
    final remote = values[0] as SearchBundle;
    final surahs = values[1] as List<Surah>;
    final catalog = values[2] as List<QuranAudioCatalogReciter>;
    setState(() {
      _partialFailure = failed;
      _surahs = {
        for (final surah in [...remote.surahs, ...surahs])
          if (normalizeQuranQuery(
            '${surah.nameAr} ${surah.nameEn} ${surah.number}',
          ).contains(normalized))
            surah.number: surah,
      }.values.toList();
      _stations = remote.stations;
      _legacy = remote.reciters;
      _reciters = {
        for (final reciter in catalog)
          if (normalizeQuranQuery(
            '${reciter.nameAr} ${reciter.nameEn} ${reciter.riwayah ?? ''}',
          ).contains(normalized))
            reciter.identityKey: reciter,
      }.values.toList();
      _loading = false;
    });
  }

  Future<void> _openSurah(Surah surah) async {
    try {
      final passage = await ref
          .read(servicesProvider)
          .repository
          .quranPassage(QuranBrowseMode.surah, surah.number);
      if (!mounted || passage.verses.isEmpty) return;
      await Navigator.pushNamed(
        context,
        MobileRoutes.reader,
        arguments: passage.verses.first.pageNumber,
      );
    } catch (_) {
      _message('تعذر فتح السورة حاليًا');
    }
  }

  void _message(String message) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _play(Station station) async {
    if (_pending != null) return;
    setState(() => _pending = station.id);
    try {
      await ref.read(servicesProvider).playback.playStation(station);
    } catch (_) {
      _message('تعذر تشغيل المحطة حاليًا');
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    return AnimatedBuilder(
      animation: Listenable.merge([services.features, services.quranPlaylists]),
      builder: (context, _) {
        final normalized = normalizeQuranQuery(_controller.text);
        final rows = <Object>[];
        void section(String title, Iterable<Object> values) {
          if (values.isNotEmpty) {
            rows.add(title);
            rows.addAll(values);
          }
        }

        if (_filter == 0 || _filter == 1) section('السور', _surahs);
        if (_filter == 0 || _filter == 2) {
          section('القراء والمصاحف الصوتية', _reciters);
          section('القراء المفهرسون', _legacy);
        }
        if ((_filter == 0 || _filter == 3) &&
            services.features.enabled(TarteelFeature.radio))
          section('الإذاعات', _stations);
        if (_filter == 0 && normalized.isNotEmpty)
          section(
            'قوائم التشغيل',
            services.quranPlaylists.playlists.where(
              (p) => normalizeQuranQuery(p.name).contains(normalized),
            ),
          );
        return Scaffold(
          appBar: AppBar(title: const Text('البحث')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  autofocus: widget.initialQuery == null,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'سورة، قارئ، إذاعة، قائمة تشغيل',
                    suffixIcon: IconButton(
                      tooltip: 'مسح البحث',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _controller.clear();
                        _search('');
                      },
                    ),
                  ),
                  onSubmitted: _search,
                  onChanged: (value) {
                    ++_request;
                    _debounce?.cancel();
                    setState(() {
                      _surahs = [];
                      _stations = [];
                      _legacy = [];
                      _reciters = [];
                    });
                    _debounce = Timer(
                      const Duration(milliseconds: 300),
                      () => _search(value),
                    );
                  },
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (index, label) in [
                      'الكل',
                      'القرآن',
                      'القراء',
                      'الإذاعات',
                    ].indexed)
                      if (index != 3 ||
                          services.features.enabled(TarteelFeature.radio))
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _filter == index,
                            onSelected: (_) => setState(() => _filter = index),
                          ),
                        ),
                  ],
                ),
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_partialFailure)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'بعض المصادر غير متاحة حاليًا. نعرض النتائج المتاحة.',
                  ),
                ),
              Expanded(
                child: rows.isEmpty
                    ? EmptyPane(
                        message: normalized.isEmpty
                            ? 'ابحث عن سورة أو قارئ أو إذاعة'
                            : _loading
                            ? 'جارٍ البحث'
                            : 'لا توجد نتائج متاحة',
                      )
                    : ListView.builder(
                        key: ValueKey('search-$_filter'),
                        itemCount: rows.length,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          if (row is String) return SectionHeader(row);
                          if (row is Surah)
                            return ListTile(
                              key: ValueKey('surah-${row.number}'),
                              leading: CircleAvatar(
                                child: Text('${row.number}'),
                              ),
                              title: Text(row.nameAr),
                              subtitle: Text('${row.ayahCount} آية'),
                              onTap: () => _openSurah(row),
                            );
                          if (row is QuranAudioCatalogReciter)
                            return ListTile(
                              key: ValueKey(row.identityKey),
                              leading: const Icon(Icons.headphones),
                              title: Text(row.nameAr),
                              subtitle: Text(
                                [
                                  if (row.riwayah != null) row.riwayah!,
                                  row.provider.name,
                                ].join(' • '),
                              ),
                              onTap: () => Navigator.pushNamed(
                                context,
                                MobileRoutes.reciter,
                                arguments: row,
                              ),
                            );
                          if (row is Reciter)
                            return ListTile(
                              leading: Artwork(
                                url: row.imageUrl,
                                icon: Icons.person_outline,
                              ),
                              title: Text(row.nameAr),
                              subtitle: row.rewaya == null
                                  ? null
                                  : Text(row.rewaya!),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      ReciterDetailPage(reciter: row),
                                ),
                              ),
                            );
                          if (row is Station)
                            return ListTile(
                              key: ValueKey('station-${row.id}'),
                              leading: Artwork(url: row.logoUrl),
                              title: Text(row.nameAr),
                              trailing: IconButton(
                                tooltip: 'تشغيل المحطة',
                                icon: const Icon(Icons.play_arrow),
                                onPressed: _pending == null && row.isPlayable
                                    ? () => _play(row)
                                    : null,
                              ),
                            );
                          final playlist = row as QuranPlaylist;
                          return ListTile(
                            key: ValueKey(playlist.id),
                            leading: const Icon(Icons.queue_music),
                            title: Text(playlist.name),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => QuranPlaylistDetailPage(
                                  playlistId: playlist.id,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
