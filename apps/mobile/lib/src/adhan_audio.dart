import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'playback.dart';

abstract class AdhanPlaybackGateway {
  Future<bool> isPlaying();
  Future<void> pause();
}

class PlaybackPortAdhanGateway implements AdhanPlaybackGateway {
  PlaybackPortAdhanGateway(this._playback);

  final PlaybackPort _playback;

  @override
  Future<bool> isPlaying() async {
    try {
      return (await _playback.playbackStateStream.first.timeout(
        const Duration(milliseconds: 250),
      )).playing;
    } on TimeoutException {
      return false;
    }
  }

  @override
  Future<void> pause() => _playback.pause();
}

abstract class AdhanPlayerGateway {
  Future<void> playAsset(String assetPath);
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioAdhanPlayerGateway implements AdhanPlayerGateway {
  JustAudioAdhanPlayerGateway({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> playAsset(String assetPath) async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    try {
      if (!await session.setActive(true)) {
        throw StateError('ADHAN_AUDIO_FOCUS_DENIED');
      }
      await _player.setAsset(assetPath);
      await _player.play();
    } finally {
      await _player.stop();
      await session.setActive(false);
      await session.configure(const AudioSessionConfiguration.music());
    }
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

class AdhanAudioService extends ChangeNotifier {
  AdhanAudioService({
    PlaybackPort? playback,
    AdhanPlaybackGateway? playbackGateway,
    AdhanPlayerGateway? player,
    this.assetPath = 'assets/audio/adhan.ogg',
  }) : assert(playback != null || playbackGateway != null),
       _playback = playbackGateway ?? PlaybackPortAdhanGateway(playback!),
       _player = player ?? JustAudioAdhanPlayerGateway();

  final AdhanPlaybackGateway _playback;
  final AdhanPlayerGateway _player;
  final String assetPath;
  Future<void>? _active;
  bool _isPlaying = false;
  String? _lastError;

  bool get isPlaying => _isPlaying;
  String? get lastError => _lastError;
  Future<void> get completion => _active ?? Future<void>.value();

  Future<bool> play() async {
    if (_active != null) return false;
    _lastError = null;
    _isPlaying = true;
    notifyListeners();
    final operation = _run();
    _active = operation;
    unawaited(operation);
    return true;
  }

  Future<void> _run() async {
    try {
      if (await _playback.isPlaying()) await _playback.pause();
      await _player.playAsset(assetPath);
    } catch (_) {
      _lastError = 'ADHAN_PLAYBACK_FAILED';
      debugPrint(_lastError);
    } finally {
      try {
        await _player.stop();
      } catch (_) {
        debugPrint('ADHAN_AUDIO_CLEANUP_FAILED');
      }
      _isPlaying = false;
      _active = null;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (_active == null) return;
    await _player.stop();
    await completion;
  }

  Future<void> close() async {
    await stop();
    await _player.dispose();
    dispose();
  }
}
