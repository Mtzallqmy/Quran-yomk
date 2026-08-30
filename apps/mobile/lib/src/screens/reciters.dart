import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../services.dart';

class RecitersPage extends ConsumerStatefulWidget {
  const RecitersPage({super.key});
  @override
  ConsumerState<RecitersPage> createState() => _RecitersPageState();
}

class _RecitersPageState extends ConsumerState<RecitersPage> {
  final controller = TextEditingController();
  Timer? debounce;
  List<Reciter> values = const <Reciter>[];
  bool loading = true;
  Object? error;
  int page = 1;
  int? nextPage;

  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  Future<void> load({bool reset = false}) async {
    if (reset) {
      page = 1;
      values = const <Reciter>[];
      nextPage = null;
    }
    setState(() { loading = true; error = null; });
    try {
      final query = controller.text.trim();
      if (query.isEmpty && page == 1) {
        final result = await ref.read(servicesProvider).repository.reciters(refresh: reset);
        values = result;
        nextPage = null;
      } else {
        final result = await ref.read(servicesProvider).repository.searchReciters(query, page: page);
        values = <Reciter>[...values, ...result.data];
        nextPage = result.nextPage;
      }
    } catch (e) {
      error = e;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null && values.isEmpty) return ErrorPane(error: error!, onRetry: () => load(reset: true));
    return Column(children: <Widget>[
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: controller,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث عن قارئ بالعربية أو الإنجليزية'),
          onChanged: (_) {
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 350), () => load(reset: true));
          },
        ),
      ),
      Expanded(
        child: loading && values.isEmpty
            ? const LoadingPane()
            : RefreshIndicator(
                onRefresh: () => load(reset: true),
                child: ListView.builder(
                  itemCount: values.length + (nextPage != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == values.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(child: OutlinedButton(onPressed: loading ? null : () { page = nextPage!; load(); }, child: loading ? const CircularProgressIndicator() : const Text('تحميل المزيد'))),
                      );
                    }
                    final reciter = values[index];
                    return Card(
                      child: ListTile(
                        leading: Artwork(url: reciter.imageUrl, icon: Icons.person_outline),
                        title: Text(reciter.nameAr),
                        subtitle: Text(<String>[if (reciter.nameEn != null) reciter.nameEn!, if (reciter.rewaya != null) reciter.rewaya!].join(' • ')),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReciterDetailPage(reciter: reciter))),
                      ),
                    );
                  },
                ),
              ),
      ),
    ]);
  }
}

class ReciterDetailPage extends ConsumerStatefulWidget {
  const ReciterDetailPage({super.key, required this.reciter});
  final Reciter reciter;
  @override
  ConsumerState<ReciterDetailPage> createState() => _ReciterDetailPageState();
}

class _ReciterDetailPageState extends ConsumerState<ReciterDetailPage> {
  late Future<List<ReciterTrack>> future;
  @override
  void initState() {
    super.initState();
    future = ref.read(servicesProvider).repository.reciterTracks(widget.reciter.id);
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reciter.nameAr),
        actions: <Widget>[
          AnimatedBuilder(
            animation: services.favorites,
            builder: (context, _) => IconButton(onPressed: () => services.favorites.toggleReciter(widget.reciter.id), icon: Icon(services.favorites.isReciter(widget.reciter.id) ? Icons.favorite : Icons.favorite_border)),
          ),
        ],
      ),
      body: FutureBuilder<List<ReciterTrack>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) return const LoadingPane();
          if (snapshot.hasError && !snapshot.hasData) return ErrorPane(error: snapshot.error!, onRetry: () => setState(() => future = services.repository.reciterTracks(widget.reciter.id)));
          final tracks = snapshot.data ?? const <ReciterTrack>[];
          if (tracks.isEmpty) return const EmptyPane(message: 'لا توجد تلاوات متاحة لهذا القارئ حاليًا');
          return ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return ListTile(
                leading: CircleAvatar(child: Text('${track.surah.number}')),
                title: Text(track.surah.nameAr),
                subtitle: Text(<String>[if (track.rewaya != null) track.rewaya!, if (track.quality != null) track.quality!].join(' • ')),
                trailing: AnimatedBuilder(
                  animation: services.favorites,
                  builder: (context, _) => Wrap(spacing: 2, children: <Widget>[
                    IconButton(onPressed: () => services.favorites.toggleTrack(track.id), icon: Icon(services.favorites.isTrack(track.id) ? Icons.favorite : Icons.favorite_border)),
                    IconButton(onPressed: track.isPlayable ? () => services.playback.playTracks(tracks, index, widget.reciter) : null, icon: const Icon(Icons.play_circle_fill)),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
