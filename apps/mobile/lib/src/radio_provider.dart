import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playback.dart';
import 'radio_service.dart';
import 'services.dart';

class QuranRadioState {
  const QuranRadioState({
    required this.stations,
    this.current,
    this.isPlaying = false,
    this.isBuffering = false,
    this.volume = 1.0,
    this.errorMessage,
  });

  final List<QuranRadioStation> stations;
  final QuranRadioStation? current;
  final bool isPlaying;
  final bool isBuffering;
  final double volume;
  final String? errorMessage;

  QuranRadioState copyWith({
    List<QuranRadioStation>? stations,
    QuranRadioStation? current,
    bool clearCurrent = false,
    bool? isPlaying,
    bool? isBuffering,
    double? volume,
    String? errorMessage,
    bool clearError = false,
  }) => QuranRadioState(
    stations: stations ?? this.stations,
    current: clearCurrent ? null : current ?? this.current,
    isPlaying: isPlaying ?? this.isPlaying,
    isBuffering: isBuffering ?? this.isBuffering,
    volume: volume ?? this.volume,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}

final radioServiceProvider = Provider<RadioService>((ref) {
  final service = IslamicRadioApiService();
  ref.onDispose(service.close);
  return service;
});

/// Kept separate from [servicesProvider] so widget tests and future platforms
/// can replace only the audio backend without rebuilding the whole app graph.
final radioPlaybackProvider = Provider<PlaybackPort>(
  (ref) => ref.watch(servicesProvider).playback,
);

final radioProvider = AsyncNotifierProvider<RadioController, QuranRadioState>(
  RadioController.new,
);

class RadioController extends AsyncNotifier<QuranRadioState> {
  StreamSubscription<PlaybackState>? _playbackSubscription;
  StreamSubscription<dynamic>? _mediaSubscription;

  @override
  Future<QuranRadioState> build() async {
    final service = ref.watch(radioServiceProvider);
    final playback = ref.watch(radioPlaybackProvider);
    final stations = await service.fetchStations();

    _playbackSubscription = playback.playbackStateStream.listen(
      _handlePlaybackState,
      onError: (Object error, StackTrace stackTrace) {
        _setPlaybackError(error);
      },
    );
    _mediaSubscription = playback.mediaItemStream.listen((item) {
      final current = state.value;
      if (current == null) return;
      final activeId = item?.extras?['entity_id'];
      if (activeId != current.current?.playbackId && current.current != null) {
        state = AsyncData(
          current.copyWith(isPlaying: false, isBuffering: false),
        );
      }
    });

    ref.onDispose(() {
      _playbackSubscription?.cancel();
      _mediaSubscription?.cancel();
    });

    return QuranRadioState(stations: stations);
  }

  Future<void> reload() async {
    final current = state.value;
    state = const AsyncLoading<QuranRadioState>().copyWithPrevious(state);
    try {
      final stations = await ref.read(radioServiceProvider).fetchStations(
        refresh: true,
      );
      state = AsyncData(
        QuranRadioState(
          stations: stations,
          current: current?.current,
          isPlaying: current?.isPlaying ?? false,
          isBuffering: current?.isBuffering ?? false,
          volume: current?.volume ?? 1.0,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncError<QuranRadioState>(error, stackTrace).copyWithPrevious(
        state,
      );
    }
  }

  Future<void> play(QuranRadioStation station) async {
    final current = state.value;
    if (current == null) return;
    if (!station.isPlayable) {
      state = AsyncData(
        current.copyWith(
          current: station,
          isPlaying: false,
          isBuffering: false,
          errorMessage: station.usesHttps
              ? 'هذه المحطة غير متاحة حاليًا من المصدر.'
              : 'هذه المحطة تستخدم رابط HTTP غير آمن، وترتيل يمنع clear-text لحماية الاتصال.',
        ),
      );
      return;
    }

    state = AsyncData(
      current.copyWith(
        current: station,
        isPlaying: false,
        isBuffering: true,
        clearError: true,
      ),
    );

    try {
      final playback = ref.read(radioPlaybackProvider);
      await playback.setVolume(current.volume);
      await playback.playStation(station.toPlaybackStation());
    } catch (error) {
      final latest = state.value;
      if (latest == null) return;
      state = AsyncData(
        latest.copyWith(
          isPlaying: false,
          isBuffering: false,
          errorMessage: _friendlyPlaybackError(error),
        ),
      );
    }
  }

  Future<void> togglePlayPause() async {
    final current = state.value;
    if (current == null) return;
    final playback = ref.read(radioPlaybackProvider);
    try {
      if (current.current == null) {
        final first = current.stations.cast<QuranRadioStation?>().firstWhere(
          (station) => station?.isPlayable == true,
          orElse: () => null,
        );
        if (first != null) await play(first);
        return;
      }
      if (current.isPlaying) {
        await playback.pause();
      } else {
        await playback.play();
      }
    } catch (error) {
      _setPlaybackError(error);
    }
  }

  Future<void> stop() async {
    final current = state.value;
    if (current == null) return;
    try {
      await ref.read(radioPlaybackProvider).stop();
      state = AsyncData(
        current.copyWith(isPlaying: false, isBuffering: false),
      );
    } catch (error) {
      _setPlaybackError(error);
    }
  }

  Future<void> setVolume(double value) async {
    final current = state.value;
    if (current == null) return;
    final normalized = value.clamp(0.0, 1.0).toDouble();
    state = AsyncData(current.copyWith(volume: normalized));
    try {
      await ref.read(radioPlaybackProvider).setVolume(normalized);
    } catch (error) {
      _setPlaybackError(error);
    }
  }

  Future<void> next() async {
    final current = state.value;
    if (current == null || current.stations.isEmpty) return;
    final playable = current.stations
        .where((station) => station.isPlayable)
        .toList(growable: false);
    if (playable.isEmpty) return;
    final index = current.current == null
        ? -1
        : playable.indexWhere((station) => station.id == current.current!.id);
    await play(playable[(index + 1) % playable.length]);
  }

  Future<void> previous() async {
    final current = state.value;
    if (current == null || current.stations.isEmpty) return;
    final playable = current.stations
        .where((station) => station.isPlayable)
        .toList(growable: false);
    if (playable.isEmpty) return;
    final index = current.current == null
        ? 0
        : playable.indexWhere((station) => station.id == current.current!.id);
    final previous = index <= 0 ? playable.length - 1 : index - 1;
    await play(playable[previous]);
  }

  void clearError() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearError: true));
  }

  void _handlePlaybackState(PlaybackState playbackState) {
    final current = state.value;
    if (current == null || current.current == null) return;
    final loading =
        playbackState.processingState == AudioProcessingState.loading ||
        playbackState.processingState == AudioProcessingState.buffering;
    state = AsyncData(
      current.copyWith(
        isPlaying: playbackState.playing,
        isBuffering: loading,
        clearError: playbackState.playing,
      ),
    );
  }

  void _setPlaybackError(Object error) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        isPlaying: false,
        isBuffering: false,
        errorMessage: _friendlyPlaybackError(error),
      ),
    );
  }

  String _friendlyPlaybackError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('cors') || text.contains('cross-origin')) {
      return 'متصفح الويب منع هذا البث بسبب CORS. جرّب محطة أخرى؛ تطبيق الهاتف لا يخضع لقيود CORS نفسها.';
    }
    if (text.contains('cleartext') || text.contains('http://')) {
      return 'تعذر التشغيل لأن رابط البث غير مشفر (HTTP).';
    }
    if (text.contains('timeout')) {
      return 'استغرق خادم البث وقتًا طويلًا ولم يستجب. جرّب محطة أخرى أو أعد المحاولة.';
    }
    return 'تعذر تشغيل البث المباشر. قد يكون رابط المحطة متوقفًا مؤقتًا أو يرفض التشغيل على هذه المنصة.';
  }
}
