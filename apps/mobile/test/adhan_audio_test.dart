import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tarteel/src/adhan_audio.dart';

void main() {
  test('adhan pauses active playback and prevents double playback', () async {
    final playback = _FakePlayback(playing: true);
    final player = _FakeAdhanPlayer();
    final service = AdhanAudioService(
      playbackGateway: playback,
      player: player,
    );

    expect(await service.play(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(service.isPlaying, isTrue);
    expect(playback.pauseCount, 1);
    expect(player.playCount, 1);
    expect(await service.play(), isFalse);
    expect(player.playCount, 1);

    player.finish();
    await service.completion;
    expect(service.isPlaying, isFalse);
    expect(player.stopCount, greaterThanOrEqualTo(1));
    expect(playback.resumeCount, 0);
  });

  test('stop releases the adhan player and preserves playback state', () async {
    final playback = _FakePlayback(playing: false);
    final player = _FakeAdhanPlayer();
    final service = AdhanAudioService(
      playbackGateway: playback,
      player: player,
    );

    await service.play();
    await Future<void>.delayed(Duration.zero);
    await service.stop();
    expect(service.isPlaying, isFalse);
    expect(playback.pauseCount, 0);
    expect(player.stopCount, greaterThanOrEqualTo(1));
  });

  test(
    'missing adhan asset fails closed without leaving audio active',
    () async {
      final player = _FakeAdhanPlayer(missingAsset: true);
      final service = AdhanAudioService(
        playbackGateway: _FakePlayback(playing: true),
        player: player,
      );

      expect(await service.play(), isTrue);
      await service.completion;
      expect(service.isPlaying, isFalse);
      expect(service.lastError, 'ADHAN_PLAYBACK_FAILED');
      expect(player.stopCount, greaterThanOrEqualTo(1));
    },
  );
}

class _FakePlayback implements AdhanPlaybackGateway {
  _FakePlayback({required this.playing});

  bool playing;
  int pauseCount = 0;
  int resumeCount = 0;

  @override
  Future<bool> isPlaying() async => playing;

  @override
  Future<void> pause() async {
    pauseCount += 1;
    playing = false;
  }
}

class _FakeAdhanPlayer implements AdhanPlayerGateway {
  _FakeAdhanPlayer({this.missingAsset = false});

  final bool missingAsset;
  Completer<void>? _playing;
  int playCount = 0;
  int stopCount = 0;

  @override
  Future<void> playAsset(String assetPath) async {
    playCount += 1;
    if (missingAsset) throw StateError('ASSET_MISSING');
    _playing = Completer<void>();
    await _playing!.future;
  }

  void finish() {
    final completer = _playing;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    finish();
  }

  @override
  Future<void> dispose() async {
    finish();
  }
}
