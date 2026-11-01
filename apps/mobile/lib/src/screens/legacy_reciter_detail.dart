import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../services.dart';

/// Compatibility entry point for home/search/favorites cards backed by the
/// normalized Tarteel reciter catalog. The main Reciters tab uses the stricter
/// QuranAudioCatalogReciter flow for playback and downloads.
class ReciterDetailPage extends ConsumerStatefulWidget {
  const ReciterDetailPage({super.key, required this.reciter});

  final Reciter reciter;

  @override
  ConsumerState<ReciterDetailPage> createState() => _ReciterDetailPageState();
}

class _ReciterDetailPageState extends ConsumerState<ReciterDetailPage> {
  late Future<List<ReciterTrack>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(servicesProvider)
        .repository
        .reciterTracks(widget.reciter.id);
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
            builder: (context, _) => IconButton(
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
      body: FutureBuilder<List<ReciterTrack>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const LoadingPane();
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return ErrorPane(
              error: snapshot.error!,
              onRetry: () => setState(
                () => _future = services.repository.reciterTracks(
                  widget.reciter.id,
                ),
              ),
            );
          }
          final tracks = snapshot.data ?? const <ReciterTrack>[];
          if (tracks.isEmpty) {
            return const EmptyPane(
              message: 'لا توجد تلاوات متاحة لهذا القارئ حاليًا',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return ListTile(
                leading: CircleAvatar(child: Text('${track.surah.number}')),
                title: Text(track.surah.nameAr),
                subtitle: Text(
                  <String>[
                    if (track.rewaya != null) track.rewaya!,
                    if (track.quality != null) track.quality!,
                  ].join(' • '),
                ),
                trailing: IconButton(
                  onPressed: track.isPlayable
                      ? () => services.playback.playTracks(
                          tracks,
                          index,
                          widget.reciter,
                        )
                      : null,
                  icon: const Icon(Icons.play_circle_fill),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
