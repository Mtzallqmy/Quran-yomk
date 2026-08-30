import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import 'models.dart';

abstract class PlaybackPort {
  Stream<MediaItem?> get mediaItemStream;
  Stream<PlaybackState> get playbackStateStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<Duration?> get sleepRemainingStream;
  bool get isLive;
  Future<void> playStation(Station station);
  Future<void> playTracks(
    List<ReciterTrack> tracks,
    int index,
    Reciter reciter,
  );
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> setSpeed(double speed);
  Future<void> setVolume(double volume);
  Future<void> setRepeatOne(bool enabled);
  Future<void> updateLiveMetadata(NowPlaying value);
  void setSleepTimer(Duration duration);
  void cancelSleepTimer();
}

class TarteelAudioHandler extends BaseAudioHandler
    with SeekHandler
    implements PlaybackPort {
  TarteelAudioHandler() {
    _player.playbackEventStream.listen((_) => _broadcastState());
    _player.playingStream.listen((playing) {
      if (playing) _reconnectAttempt = 0;
      _broadcastState();
    });
    _player.errorStream.listen((_) => _scheduleLiveReconnect());
  }

  final AudioPlayer _player = AudioPlayer();
  final StreamController<Duration?> _sleepRemaining =
      StreamController<Duration?>.broadcast();
  Timer? _sleepTimer;
  Timer? _reconnectTimer;
  DateTime? _sleepDeadline;
  Station? _liveStation;
  Reciter? _reciter;
  List<ReciterTrack> _tracks = const <ReciterTrack>[];
  int _trackIndex = 0;
  int _reconnectAttempt = 0;
  bool _shouldPlay = false;
  bool _resumeAfterInterruption = false;

  @override
  bool get isLive => _liveStation != null;
  @override
  Stream<MediaItem?> get mediaItemStream => mediaItem.stream;
  @override
  Stream<PlaybackState> get playbackStateStream => playbackState.stream;
  @override
  Stream<Duration> get positionStream => _player.positionStream;
  @override
  Stream<Duration?> get durationStream => _player.durationStream;
  @override
  Stream<Duration?> get sleepRemainingStream => _sleepRemaining.stream;

  Future<void> initialize() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    session.becomingNoisyEventStream.listen((_) => pause());
    session.interruptionEventStream.listen((event) async {
      if (event.begin) {
        _resumeAfterInterruption = _player.playing;
        if (event.type == AudioInterruptionType.pause ||
            event.type == AudioInterruptionType.unknown)
          await pause();
        if (event.type == AudioInterruptionType.duck)
          await _player.setVolume(0.35);
      } else {
        if (event.type == AudioInterruptionType.duck)
          await _player.setVolume(1.0);
        if (_resumeAfterInterruption &&
            event.type == AudioInterruptionType.pause)
          await play();
        _resumeAfterInterruption = false;
      }
    });
  }

  @override
  Future<void> playStation(Station station) async {
    if (!station.isPlayable) throw StateError('Station is not playable');
    _cancelReconnect();
    _liveStation = station;
    _reciter = null;
    _tracks = const <ReciterTrack>[];
    _trackIndex = 0;
    _shouldPlay = true;
    queue.add(const <MediaItem>[]);
    mediaItem.add(_stationItem(station));
    await _loadUrl(station.playbackUrl!);
    await _player.setSpeed(1.0);
    await _player.play();
  }

  MediaItem _stationItem(Station station, {String? title, String? subtitle}) =>
      MediaItem(
        id: 'station:${station.id}',
        title: title ?? station.nameAr,
        artist: subtitle ?? 'بث مباشر',
        artUri: station.logoUrl == null ? null : Uri.tryParse(station.logoUrl!),
        isLive: true,
        extras: <String, dynamic>{
          'kind': 'station',
          'entity_id': station.id,
          'slug': station.slug,
          'url': station.playbackUrl,
          'station_name': station.nameAr,
        },
      );

  @override
  Future<void> updateLiveMetadata(NowPlaying value) async {
    final station = _liveStation;
    if (station == null || station.id != value.stationId) return;
    mediaItem.add(
      _stationItem(
        station,
        title: value.title ?? station.nameAr,
        subtitle: value.subtitle ?? 'بث مباشر',
      ),
    );
  }

  @override
  Future<void> playTracks(
    List<ReciterTrack> tracks,
    int index,
    Reciter reciter,
  ) async {
    final playable = tracks
        .where((track) => track.isPlayable)
        .toList(growable: false);
    if (playable.isEmpty) throw StateError('No playable tracks');
    final selected = tracks[index];
    final mappedIndex = playable.indexWhere((track) => track.id == selected.id);
    _cancelReconnect();
    _liveStation = null;
    _reciter = reciter;
    _tracks = playable;
    _trackIndex = mappedIndex < 0 ? 0 : mappedIndex;
    _shouldPlay = true;
    queue.add(
      playable
          .map((track) => _trackItem(track, reciter))
          .toList(growable: false),
    );
    await _loadTrack(_trackIndex);
    await _player.play();
  }

  MediaItem _trackItem(ReciterTrack track, Reciter reciter) => MediaItem(
    id: 'track:${track.id}',
    title: track.surah.nameAr,
    artist: reciter.nameAr,
    duration: track.durationMs == null
        ? null
        : Duration(milliseconds: track.durationMs!),
    isLive: false,
    extras: <String, dynamic>{
      'kind': 'track',
      'entity_id': track.id,
      'url': track.playbackUrl,
      'surah_number': track.surah.number,
      'reciter_id': reciter.id,
    },
  );

  Future<void> _loadTrack(int index) async {
    final track = _tracks[index];
    final reciter = _reciter;
    if (reciter == null || track.playbackUrl == null) return;
    _trackIndex = index;
    mediaItem.add(_trackItem(track, reciter));
    await _loadUrl(track.playbackUrl!);
    _broadcastState();
  }

  Future<void> _loadUrl(String url) async {
    await _player.setUrl(url, preload: true);
  }

  @override
  Future<void> play() async {
    _shouldPlay = true;
    if (_player.processingState == ProcessingState.completed && !isLive)
      await seek(Duration.zero);
    await _player.play();
  }

  @override
  Future<void> pause() async {
    _shouldPlay = false;
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    _shouldPlay = false;
    _cancelReconnect();
    cancelSleepTimer();
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    if (isLive) return;
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (isLive || _tracks.isEmpty) return;
    final next = _trackIndex + 1;
    if (next >= _tracks.length) return;
    await _loadTrack(next);
    if (_shouldPlay) await _player.play();
  }

  @override
  Future<void> skipToPrevious() async {
    if (isLive || _tracks.isEmpty) return;
    if (_player.position > const Duration(seconds: 5)) {
      await _player.seek(Duration.zero);
      return;
    }
    final previous = _trackIndex - 1;
    if (previous < 0) return;
    await _loadTrack(previous);
    if (_shouldPlay) await _player.play();
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (isLive) return;
    await _player.setSpeed(speed.clamp(0.75, 2.0));
    _broadcastState();
  }

  @override
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0).toDouble());
  }

  @override
  Future<void> setRepeatOne(bool enabled) async {
    if (isLive) return;
    await _player.setLoopMode(enabled ? LoopMode.one : LoopMode.off);
    playbackState.add(
      playbackState.value.copyWith(
        repeatMode: enabled
            ? AudioServiceRepeatMode.one
            : AudioServiceRepeatMode.none,
      ),
    );
  }

  @override
  void setSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepDeadline = DateTime.now().add(duration);
    _sleepRemaining.add(duration);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final deadline = _sleepDeadline;
      if (deadline == null) return;
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        cancelSleepTimer();
        await pause();
      } else {
        _sleepRemaining.add(remaining);
      }
    });
  }

  @override
  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepDeadline = null;
    _sleepRemaining.add(null);
  }

  void _scheduleLiveReconnect() {
    final station = _liveStation;
    if (station == null ||
        !_shouldPlay ||
        station.playbackUrl == null ||
        _reconnectTimer != null)
      return;
    const backoff = <int>[2, 4, 8, 16, 30];
    if (_reconnectAttempt >= backoff.length) return;
    final delay = Duration(seconds: backoff[_reconnectAttempt++]);
    _reconnectTimer = Timer(delay, () async {
      _reconnectTimer = null;
      if (_liveStation?.id != station.id || !_shouldPlay) return;
      try {
        await _loadUrl(station.playbackUrl!);
        await _player.play();
      } catch (_) {
        _scheduleLiveReconnect();
      }
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
  }

  void _broadcastState() {
    final processing = switch (_player.processingState) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
    final controls = isLive
        ? <MediaControl>[
            MediaControl.stop,
            _player.playing ? MediaControl.pause : MediaControl.play,
          ]
        : <MediaControl>[
            MediaControl.skipToPrevious,
            _player.playing ? MediaControl.pause : MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ];
    playbackState.add(
      playbackState.value.copyWith(
        controls: controls,
        systemActions: isLive
            ? const <MediaAction>{}
            : const <MediaAction>{
                MediaAction.seek,
                MediaAction.seekForward,
                MediaAction.seekBackward,
              },
        androidCompactActionIndices: isLive
            ? const <int>[0, 1]
            : const <int>[0, 1, 2],
        processingState: processing,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: isLive ? null : _trackIndex,
      ),
    );
  }

  Future<void> disposeHandler() async {
    _cancelReconnect();
    cancelSleepTimer();
    await _sleepRemaining.close();
    await _player.dispose();
  }
}
