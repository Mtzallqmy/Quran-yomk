import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../l10n.dart';
import '../models.dart';
import '../offline_clip_service.dart';
import '../services.dart';
import '../transcription.dart';
import '../virtual_radio.dart';
import 'saved_clips.dart';

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
                      builder: (context, state) {
                        final playing = state.data?.playing == true;
                        final virtual = item.extras?['kind'] == 'virtual_radio';
                        return IconButton(
                          tooltip: playing
                              ? context.l10n.pause
                              : context.l10n.play,
                          onPressed: () => virtual
                              ? playing
                                    ? ref
                                          .read(virtualRadioProvider.notifier)
                                          .pause()
                                    : ref
                                          .read(virtualRadioProvider.notifier)
                                          .resume()
                              : playing
                              ? playback.pause()
                              : playback.play(),
                          icon: Icon(
                            playing
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                          ),
                        );
                      },
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
      if (item?.isLive == true && item?.extras?['kind'] == 'station') {
        unawaited(_refreshNowPlaying());
      }
    });
    _nowPlayingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_refreshNowPlaying()),
    );
  }

  Future<void> _refreshNowPlaying() async {
    final item = _latest;
    if (item?.extras?['kind'] != 'station') return;
    final slug = item?.extras?['slug'];
    if (item?.isLive != true || slug is! String || slug.isEmpty) return;
    try {
      final services = ref.read(servicesProvider);
      final value = await services.repository.nowPlaying(slug);
      await services.playback.updateLiveMetadata(value);
    } catch (_) {
      // Metadata freshness must never interrupt playback.
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
    final l10n = context.l10n;
    final services = ref.watch(servicesProvider);
    final playback = services.playback;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.player)),
      body: StreamBuilder<MediaItem?>(
        stream: playback.mediaItemStream,
        builder: (context, itemSnapshot) {
          final item = itemSnapshot.data;
          if (item == null) {
            return EmptyPane(message: l10n.noCurrentPlayback);
          }
          final live = item.isLive == true;
          final entityId = item.extras?['entity_id'] as String?;
          final kind = item.extras?['kind'] as String?;
          final virtual = kind == 'virtual_radio';
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
                    label: Text(l10n.live),
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
                  final processing = stateSnapshot.data?.processingState;
                  final buffering =
                      processing == AudioProcessingState.buffering ||
                      processing == AudioProcessingState.loading;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (!live)
                        IconButton(
                          iconSize: 40,
                          tooltip: l10n.previous,
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
                          tooltip: playing ? l10n.pause : l10n.play,
                          onPressed: () => virtual
                              ? playing
                                    ? ref
                                          .read(virtualRadioProvider.notifier)
                                          .pause()
                                    : ref
                                          .read(virtualRadioProvider.notifier)
                                          .resume()
                              : playing
                              ? playback.pause()
                              : playback.play(),
                          icon: Icon(
                            playing ? Icons.pause_circle : Icons.play_circle,
                          ),
                        ),
                      if (!live)
                        IconButton(
                          iconSize: 40,
                          tooltip: l10n.next,
                          onPressed: playback.skipToNext,
                          icon: const Icon(Icons.skip_next),
                        ),
                      if (live)
                        IconButton(
                          iconSize: 40,
                          tooltip: l10n.stopLive,
                          onPressed: virtual
                              ? ref.read(virtualRadioProvider.notifier).stop
                              : playback.stop,
                          icon: const Icon(Icons.stop_circle_outlined),
                        ),
                    ],
                  );
                },
              ),
              _VolumeControl(playback: playback),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (entityId != null &&
                      (kind == 'station' || kind == 'track'))
                    AnimatedBuilder(
                      animation: services.favorites,
                      builder: (context, _) {
                        final favorite = kind == 'station'
                            ? services.favorites.isStation(entityId)
                            : services.favorites.isTrack(entityId);
                        return IconButton.filledTonal(
                          tooltip: l10n.favorite,
                          onPressed: () => kind == 'station'
                              ? services.favorites.toggleStation(entityId)
                              : services.favorites.toggleTrack(entityId),
                          icon: Icon(
                            favorite ? Icons.favorite : Icons.favorite_border,
                          ),
                        );
                      },
                    ),
                  IconButton.filledTonal(
                    tooltip: l10n.sleepTimer,
                    onPressed: () => _showSleepTimer(context, playback, kind),
                    icon: const Icon(Icons.bedtime_outlined),
                  ),
                  if (kind == 'station') _OfflineClipAction(item: item),
                  if (services.offlineClips.supported)
                    IconButton.filledTonal(
                      tooltip: l10n.savedClips,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SavedClipsPage(),
                        ),
                      ),
                      icon: const Icon(Icons.offline_pin_outlined),
                    ),
                  if (!live)
                    PopupMenuButton<double>(
                      tooltip: l10n.defaultRecitationSpeed,
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
                  if (kind == 'track')
                    IconButton.filledTonal(
                      tooltip: l10n.repeatSurah,
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
              if (live) const _TranscriptionStatus(),
              StreamBuilder<Duration?>(
                stream: playback.sleepRemainingStream,
                builder: (context, snapshot) => snapshot.data == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Center(
                          child: Text(l10n.stopsAfter(_format(snapshot.data!))),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showSleepTimer(
    BuildContext context,
    dynamic playback,
    String? kind,
  ) async {
    final l10n = context.l10n;
    final choice = await showModalBottomSheet<_SleepChoice>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            ListTile(title: Text(l10n.sleepTimer)),
            for (final option in <(int, String)>[
              (10, l10n.minutes10),
              (20, l10n.minutes20),
              (30, l10n.minutes30),
              (45, l10n.minutes45),
              (60, l10n.minutes60),
            ])
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(option.$2),
                onTap: () => Navigator.pop(
                  context,
                  _SleepChoice.duration(Duration(minutes: option.$1)),
                ),
              ),
            if (kind == 'track')
              ListTile(
                leading: const Icon(Icons.skip_next_outlined),
                title: Text(l10n.endOfCurrentRecitation),
                onTap: () => Navigator.pop(context, const _SleepChoice.atEnd()),
              ),
            ListTile(
              leading: const Icon(Icons.timer_off_outlined),
              title: Text(l10n.cancelSleepTimer),
              onTap: () => Navigator.pop(context, const _SleepChoice.cancel()),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice.kind == _SleepChoiceKind.duration) {
      playback.setSleepTimer(choice.duration!);
      return;
    }
    if (choice.kind == _SleepChoiceKind.atEnd) {
      playback.setSleepTimerAtEnd();
      return;
    }
    playback.cancelSleepTimer();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.timerCancelled)));
    }
  }
}

enum _SleepChoiceKind { duration, atEnd, cancel }

class _SleepChoice {
  const _SleepChoice.duration(this.duration) : kind = _SleepChoiceKind.duration;
  const _SleepChoice.atEnd() : kind = _SleepChoiceKind.atEnd, duration = null;
  const _SleepChoice.cancel() : kind = _SleepChoiceKind.cancel, duration = null;

  final _SleepChoiceKind kind;
  final Duration? duration;
}

class _OfflineClipAction extends ConsumerStatefulWidget {
  const _OfflineClipAction({required this.item});

  final MediaItem item;

  @override
  ConsumerState<_OfflineClipAction> createState() => _OfflineClipActionState();
}

class _OfflineClipActionState extends ConsumerState<_OfflineClipAction> {
  Future<_ClipAvailability>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _OfflineClipAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) _future = _load();
  }

  Future<_ClipAvailability> _load() async {
    final slug = widget.item.extras?['slug'];
    if (slug is! String || slug.isEmpty) {
      return const _ClipAvailability.unavailable();
    }
    final services = ref.read(servicesProvider);
    try {
      final station = await services.repository.api.station(slug);
      final policy = await services.repository.api.offlineClipPolicy(slug);
      return _ClipAvailability(station: station, policy: policy);
    } catch (_) {
      return const _ClipAvailability.unavailable();
    }
  }

  @override
  Widget build(BuildContext context) {
    final clips = ref.watch(servicesProvider).offlineClips;
    return FutureBuilder<_ClipAvailability>(
      future: _future,
      builder: (context, snapshot) {
        final value = snapshot.data;
        if (value == null ||
            value.station == null ||
            value.policy == null ||
            !value.policy!.allowed ||
            !value.policy!.supportedStream ||
            !clips.supported) {
          return const SizedBox.shrink();
        }
        final station = value.station!;
        return AnimatedBuilder(
          animation: clips,
          builder: (context, _) {
            if (clips.activeStationId == station.id) {
              return FilledButton.tonalIcon(
                onPressed: () => _stop(context, clips),
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(
                  '${context.l10n.stopSaving} • ${_format(clips.activeElapsed)}',
                ),
              );
            }
            if (clips.activeStationId != null) {
              return const SizedBox.shrink();
            }
            return FilledButton.tonalIcon(
              onPressed: () => _chooseDuration(context, value),
              icon: const Icon(Icons.download_for_offline_outlined),
              label: Text(context.l10n.saveOfflineClip),
            );
          },
        );
      },
    );
  }

  Future<void> _chooseDuration(
    BuildContext context,
    _ClipAvailability value,
  ) async {
    final l10n = context.l10n;
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            ListTile(title: Text(l10n.saveOfflineClip)),
            ListTile(
              title: Text(l10n.save5Minutes),
              onTap: () => Navigator.pop(context, 5),
            ),
            ListTile(
              title: Text(l10n.save10Minutes),
              onTap: () => Navigator.pop(context, 10),
            ),
            ListTile(
              title: Text(l10n.save30Minutes),
              onTap: () => Navigator.pop(context, 30),
            ),
            ListTile(
              title: Text(l10n.saveUntilStopped),
              onTap: () => Navigator.pop(context, 0),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final clips = ref.read(servicesProvider).offlineClips;
    try {
      await clips.start(
        station: value.station!,
        policy: value.policy!,
        maxDuration: choice == 0 ? null : Duration(minutes: choice),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.clipSavingStarted)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.clipSavingFailed)));
    }
  }

  Future<void> _stop(BuildContext context, OfflineClipService clips) async {
    final l10n = context.l10n;
    try {
      final saved = await clips.stop();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved == null ? l10n.clipSavingFailed : l10n.clipSavingStopped,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.clipSavingFailed)));
    }
  }
}

class _ClipAvailability {
  const _ClipAvailability({required this.station, required this.policy});
  const _ClipAvailability.unavailable() : station = null, policy = null;

  final Station? station;
  final OfflineClipPolicy? policy;
}

class _VolumeControl extends StatelessWidget {
  const _VolumeControl({required this.playback});

  final dynamic playback;

  @override
  Widget build(BuildContext context) => StreamBuilder<double>(
    stream: playback.volumeStream as Stream<double>,
    initialData: 1.0,
    builder: (context, snapshot) {
      final volume = (snapshot.data ?? 1.0).clamp(0.0, 1.0);
      return Row(
        children: <Widget>[
          Icon(volume == 0 ? Icons.volume_off : Icons.volume_up),
          Expanded(
            child: Slider(
              value: volume,
              min: 0,
              max: 1,
              divisions: 20,
              label: '${(volume * 100).round()}%',
              onChanged: (value) => playback.setVolume(value),
            ),
          ),
          SizedBox(width: 48, child: Text('${(volume * 100).round()}%')),
        ],
      );
    },
  );
}

class _TranscriptionStatus extends ConsumerWidget {
  const _TranscriptionStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(transcriptionServiceProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        onPressed: service.supported ? () {} : null,
        icon: const Icon(Icons.closed_caption_outlined),
        label: Text(
          service.supported
              ? context.l10n.liveTranscription
              : context.l10n.transcriptionUnavailable,
        ),
      ),
    );
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
