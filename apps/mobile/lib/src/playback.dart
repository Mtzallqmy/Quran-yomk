import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'models.dart';
import 'virtual_radio.dart';

abstract class PlaybackPort {
  Stream<MediaItem?> get mediaItemStream;
  Stream<PlaybackState> get playbackStateStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<Duration?> get sleepRemainingStream;
  Stream<double> get volumeStream;
  Stream<String> get errorStream;
  bool get isLive;
  Future<void> playStation(Station station);
  Future<void> playVirtualRadio(VirtualRadioResolution resolution);
  Future<void> updateVirtualMetadata(VirtualRadioResolution resolution);
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
    _player.errorStream.listen((error) {
      _errors.add(error.message ?? 'تعذر تشغيل البث الصوتي');
      _scheduleLiveReconnect();
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final StreamController<Duration?> _sleepRemaining =
      StreamController<Duration?>.broadcast();
  final StreamController<String> _errors = StreamController<String>.broadcast();
  Timer? _sleepTimer;
  Timer? _reconnectTimer;
  DateTime? _sleepDeadline;
  Station? _liveStation;
  VirtualRadioResolution? _virtualRadio;
  Reciter? _reciter;
  List<ReciterTrack> _tracks = const <ReciterTrack>[];
  int _trackIndex = 0;
  int _reconnectAttempt = 0;
  bool _shouldPlay = false;
  bool _resumeAfterInterruption = false;
  double _volumeBeforeDuck = 1.0;

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
  @override
  Stream<double> get volumeStream => _player.volumeStream;
  @override
  Stream<String> get errorStream => _errors.stream;

  Future<void> initialize() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    if (kIsWeb) await _player.setWebCrossOrigin(WebCrossOrigin.anonymous);
    session.becomingNoisyEventStream.listen((_) => pause());
    session.interruptionEventStream.listen((event) async {
      if (event.begin) {
        _resumeAfterInterruption = _player.playing;
        if (event.type == AudioInterruptionType.pause ||
            event.type == AudioInterruptionType.unknown) {
          await pause();
        }
        if (event.type == AudioInterruptionType.duck) {
          _volumeBeforeDuck = _player.volume;
          await _player.setVolume((_volumeBeforeDuck * 0.35).clamp(0.0, 1.0));
        }
      } else {
        if (event.type == AudioInterruptionType.duck) {
          await _player.setVolume(_volumeBeforeDuck);
        }
        if (_resumeAfterInterruption &&
            event.type == AudioInterruptionType.pause) {
          await play();
        }
        _resumeAfterInterruption = false;
      }
    });
  }

  bool _secureUrl(String? url) =>
      url != null && Uri.tryParse(url)?.scheme == 'https';

  @override
  Future<void> playStation(Station station) async {
    if (!station.isPlayable) throw StateError('STATION_UNAVAILABLE');
    if (!_secureUrl(station.playbackUrl)) throw StateError('STREAM_INSECURE');
    _cancelReconnect();
    _virtualRadio = null;
    _liveStation = station;
    _reciter = null;
    _tracks = const <ReciterTrack>[];
    _trackIndex = 0;
    _shouldPlay = true;
    queue.add(const <MediaItem>[]);
    mediaItem.add(_stationItem(station));
    await _loadUrl(station.playbackUrl!);
    await _player.setSpeed(1.0);
    unawaited(_player.play());
    _broadcastState();
  }

  @override
  Future<void> playVirtualRadio(VirtualRadioResolution resolution) async {
    final station = resolution.station;
    if (!resolution.available || station == null || !station.isPlayable) {
      throw StateError('NO_VIRTUAL_SOURCE_AVAILABLE');
    }
    if (!_secureUrl(station.playbackUrl)) throw StateError('STREAM_INSECURE');
    _cancelReconnect();
    _virtualRadio = resolution;
    _liveStation = station;
    _reciter = null;
    _tracks = const <ReciterTrack>[];
    _trackIndex = 0;
    _shouldPlay = true;
    queue.add(const <MediaItem>[]);
    mediaItem.add(_virtualItem(resolution));
    await _loadUrl(station.playbackUrl!);
    await _player.setSpeed(1.0);
    unawaited(_player.play());
    _broadcastState();
  }

  @override
  Future<void> updateVirtualMetadata(VirtualRadioResolution resolution) async {
    if (_virtualRadio == null ||
        resolution.channelId != _virtualRadio!.channelId) {
      return;
    }
    _virtualRadio = resolution;
    mediaItem.add(_virtualItem(resolution));
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
          'provider': station.provider,
        },
      );

  MediaItem _virtualItem(VirtualRadioResolution resolution) {
    final source = resolution.station;
    return MediaItem(
      id: 'virtual:${resolution.channelId}',
      title: resolution.channelNameAr,
      artist: resolution.program?.titleAr ?? 'بث مختار',
      artUri: resolution.artworkUrl == null
          ? null
          : Uri.tryParse(resolution.artworkUrl!),
      isLive: true,
      extras: <String, dynamic>{
        'kind': 'virtual_radio',
        'entity_id': resolution.channelId,
        'slug': resolution.channelSlug,
        'url': source?.playbackUrl,
        'source_station_id': source?.id,
        'source_station_name': source?.nameAr,
        'provider': source?.provider,
        'program_title': resolution.program?.titleAr,
        'next_change_at': resolution.nextChangeAt?.toIso8601String(),
      },
    );
  }

  @override
  Future<void> updateLiveMetadata(NowPlaying value) async {
    if (_virtualRadio != null) return;
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
    _virtualRadio = null;
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
    unawaited(_player.play());
    _broadcastState();
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

  Future<void> _loadUrl(String url) => _player.setUrl(url, preload: true);

  @override
  Future<void> play() async {
    _shouldPlay = true;
    if (_player.processingState == ProcessingState.completed && !isLive) {
      await seek(Duration.zero);
    }
    unawaited(_player.play());
    _broadcastState();
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
    if (!isLive) await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (isLive || _tracks.isEmpty) return;
    final next = _trackIndex + 1;
    if (next >= _tracks.length) return;
    await _loadTrack(next);
    if (_shouldPlay) unawaited(_player.play());
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
    if (_shouldPlay) unawaited(_player.play());
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (isLive) return;
    await _player.setSpeed(speed.clamp(0.75, 2.0));
    _broadcastState();
  }

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0.0, 1.0));

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
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
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
        _reconnectTimer != null) {
      return;
    }
    const backoff = <int>[2, 4, 8];
    if (_reconnectAttempt >= backoff.length) return;
    final delay = Duration(seconds: backoff[_reconnectAttempt++]);
    _reconnectTimer = Timer(delay, () async {
      _reconnectTimer = null;
      if (_liveStation?.id != station.id || !_shouldPlay) return;
      try {
        await _loadUrl(station.playbackUrl!);
        unawaited(_player.play());
      } catch (_) {
        _errors.add('تعذر إعادة الاتصال بالبث');
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
    playbackState.add(
      PlaybackState(
        controls: <MediaControl>[
          if (!isLive) MediaControl.skipToPrevious,
          _player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
          if (!isLive) MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{MediaAction.seek},
        androidCompactActionIndices: isLive
            ? const <int>[0, 1]
            : const <int>[0, 1, 3],
        processingState: processing,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: isLive ? null : _trackIndex,
        repeatMode: _player.loopMode == LoopMode.one
            ? AudioServiceRepeatMode.one
            : AudioServiceRepeatMode.none,
      ),
    );
  }
}
