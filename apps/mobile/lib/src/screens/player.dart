import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../services.dart';

class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(servicesProvider).playback;
    return StreamBuilder<MediaItem?>(
      stream: playback.mediaItemStream,
      builder: (context, itemSnapshot) {
        final item = itemSnapshot.data;
        if (item == null) return const SizedBox.shrink();
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FullPlayerPage()),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 68,
                child: Row(
                  children: <Widget>[
                    const SizedBox(width: 12),
                    Artwork(url: item.artUri?.toString(), size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.artist != null)
                            Text(
                              item.artist!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    StreamBuilder<PlaybackState>(
                      stream: playback.playbackStateStream,
                      builder: (context, state) => IconButton(
                        tooltip: state.data?.playing == true ? 'Pause' : 'Play',
                        onPressed: state.data?.playing == true
                            ? playback.pause
                            : playback.play,
                        icon: Icon(
                          state.data?.playing == true
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class FullPlayerPage extends ConsumerStatefulWidget {
  const FullPlayerPage({super.key});
  @override
  ConsumerState<FullPlayerPage> createState() => _FullPlayerPageState();
}

class _FullPlayerPageState extends ConsumerState<FullPlayerPage> {
  StreamSubscription<MediaItem?>? _mediaSubscription;
  Timer? _nowPlayingTimer;
  MediaItem? _latest;
  bool _repeatOne = false;

  @override
  void initState() {
    super.initState();
    final playback = ref.read(servicesProvider).playback;
    _mediaSubscription = playback.mediaItemStream.listen((item) {
      _latest = item;
      if (item?.isLive == true) _refreshNowPlaying();
    });
    _nowPlayingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshNowPlaying(),
    );
  }

  Future<void> _refreshNowPlaying() async {
    final item = _latest;
    final slug = item?.extras?['slug'];
    if (item?.isLive != true || slug is! String || slug.isEmpty) return;
    try {
      final services = ref.read(servicesProvider);
      final value = await services.repository.nowPlaying(slug);
      await services.playback.updateLiveMetadata(value);
    } catch (_) {
      // Now Playing freshness must not interrupt audio playback.
    }
  }

  @override
  void dispose() {
    _mediaSubscription?.cancel();
    _nowPlayingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    final playback = services.playback;
    return Scaffold(
      appBar: AppBar(title: const Text('المشغل')),
      body: StreamBuilder<MediaItem?>(
        stream: playback.mediaItemStream,
        builder: (context, itemSnapshot) {
          final item = itemSnapshot.data;
          if (item == null)
            return const EmptyPane(message: 'لا يوجد تشغيل حالي');
          final live = item.isLive == true;
          final entityId = item.extras?['entity_id'] as String?;
          final kind = item.extras?['kind'] as String?;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              Center(
                child: Artwork(
                  url: item.artUri?.toString(),
                  size: 220,
                  icon: live ? Icons.radio : Icons.menu_book,
                ),
              ),
              const SizedBox(height: 20),
              if (live)
                Center(
                  child: Chip(
                    avatar: const Icon(Icons.circle, size: 12),
                    label: const Text('مباشر'),
                  ),
                ),
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (item.artist != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(item.artist!, textAlign: TextAlign.center),
                ),
              const SizedBox(height: 20),
              if (!live) _SeekBar(playback: playback),
              StreamBuilder<PlaybackState>(
                stream: playback.playbackStateStream,
                builder: (context, stateSnapshot) {
                  final playing = stateSnapshot.data?.playing == true;
                  final buffering =
                      stateSnapshot.data?.processingState ==
                          AudioProcessingState.buffering ||
                      stateSnapshot.data?.processingState ==
                          AudioProcessingState.loading;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (!live)
                        IconButton(
                          iconSize: 40,
                          tooltip: 'السابق',
                          onPressed: playback.skipToPrevious,
                          icon: const Icon(Icons.skip_previous),
                        ),
                      if (buffering)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        IconButton(
                          iconSize: 64,
                          tooltip: playing ? 'إيقاف مؤقت' : 'تشغيل',
                          onPressed: playing ? playback.pause : playback.play,
                          icon: Icon(
                            playing ? Icons.pause_circle : Icons.play_circle,
                          ),
                        ),
                      if (!live)
                        IconButton(
                          iconSize: 40,
                          tooltip: 'التالي',
                          onPressed: playback.skipToNext,
                          icon: const Icon(Icons.skip_next),
                        ),
                    ],
                  );
                },
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: <Widget>[
                  if (entityId != null)
                    AnimatedBuilder(
                      animation: services.favorites,
                      builder: (context, _) {
                        final favorite = kind == 'station'
                            ? services.favorites.isStation(entityId)
                            : services.favorites.isTrack(entityId);
                        return IconButton(
                          tooltip: 'المفضلة',
                          onPressed: () => kind == 'station'
                              ? services.favorites.toggleStation(entityId)
                              : services.favorites.toggleTrack(entityId),
                          icon: Icon(
                            favorite ? Icons.favorite : Icons.favorite_border,
                          ),
                        );
                      },
                    ),
                  IconButton(
                    tooltip: 'مؤقت النوم',
                    onPressed: () => _showSleepTimer(context, playback),
                    icon: const Icon(Icons.bedtime_outlined),
                  ),
                  if (!live)
                    PopupMenuButton<double>(
                      tooltip: 'سرعة التشغيل',
                      icon: const Icon(Icons.speed),
                      onSelected: (value) async {
                        await services.settings.setPlaybackSpeed(value);
                        await playback.setSpeed(value);
                      },
                      itemBuilder: (_) => const <PopupMenuEntry<double>>[
                        PopupMenuItem(value: 0.75, child: Text('0.75×')),
                        PopupMenuItem(value: 1.0, child: Text('1×')),
                        PopupMenuItem(value: 1.25, child: Text('1.25×')),
                        PopupMenuItem(value: 1.5, child: Text('1.5×')),
                        PopupMenuItem(value: 2.0, child: Text('2×')),
                      ],
                    ),
                  if (!live)
                    IconButton(
                      tooltip: 'تكرار السورة',
                      onPressed: () async {
                        setState(() => _repeatOne = !_repeatOne);
                        await playback.setRepeatOne(_repeatOne);
                      },
                      icon: Icon(
                        _repeatOne ? Icons.repeat_one_on : Icons.repeat_one,
                      ),
                    ),
                ],
              ),
              StreamBuilder<Duration?>(
                stream: playback.sleepRemainingStream,
                builder: (context, snapshot) => snapshot.data == null
                    ? const SizedBox.shrink()
                    : Center(
                        child: Text('يتوقف بعد ${_format(snapshot.data!)}'),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showSleepTimer(BuildContext context, dynamic playback) async {
    final value = await showModalBottomSheet<Duration?>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const ListTile(title: Text('مؤقت النوم')),
            for (final minutes in <int>[15, 30, 45, 60])
              ListTile(
                title: Text('$minutes دقيقة'),
                onTap: () => Navigator.pop(context, Duration(minutes: minutes)),
              ),
            ListTile(
              title: const Text('إلغاء المؤقت'),
              onTap: () {
                playback.cancelSleepTimer();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
    if (value != null) playback.setSleepTimer(value);
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.playback});
  final dynamic playback;
  @override
  Widget build(BuildContext context) => StreamBuilder<Duration?>(
    stream: playback.durationStream as Stream<Duration?>,
    builder: (context, durationSnapshot) {
      final duration = durationSnapshot.data ?? Duration.zero;
      return StreamBuilder<Duration>(
        stream: playback.positionStream as Stream<Duration>,
        builder: (context, positionSnapshot) {
          final position = positionSnapshot.data ?? Duration.zero;
          final max = duration.inMilliseconds <= 0
              ? 1.0
              : duration.inMilliseconds.toDouble();
          final value = position.inMilliseconds
              .clamp(0, max.toInt())
              .toDouble();
          return Column(
            children: <Widget>[
              Slider(
                value: value,
                max: max,
                onChanged: duration == Duration.zero
                    ? null
                    : (v) => playback.seek(Duration(milliseconds: v.round())),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(_format(position)),
                  Text(_format(duration)),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}

String _format(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
