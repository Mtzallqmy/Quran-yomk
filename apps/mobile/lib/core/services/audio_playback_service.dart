import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PlaybackMode {
  radio,
  quranAudio,
  offlineFile,
}

class PlaybackState {
  final bool isPlaying;
  final PlaybackMode mode;
  final String currentTitle;
  final String currentSubtitle;
  final String currentUri;
  final Duration position;
  final Duration duration;
  final int bitrateKbps;
  final int? sleepTimerMinutes;
  final bool isMuted;

  const PlaybackState({
    this.isPlaying = true,
    this.mode = PlaybackMode.radio,
    this.currentTitle = 'إذاعة التلاوات الخاشعة',
    this.currentSubtitle = 'سورة مريم — الشيخ عبد الباسط عبد الصمد',
    this.currentUri = 'https://stream.quranyutla.app/live/khashia.mp3',
    this.position = Duration.zero,
    this.duration = const Duration(minutes: 30),
    this.bitrateKbps = 128,
    this.sleepTimerMinutes,
    this.isMuted = false,
  });

  PlaybackState copyWith({
    bool? isPlaying,
    PlaybackMode? mode,
    String? currentTitle,
    String? currentSubtitle,
    String? currentUri,
    Duration? position,
    Duration? duration,
    int? bitrateKbps,
    int? sleepTimerMinutes,
    bool? isMuted,
  }) {
    return PlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      mode: mode ?? this.mode,
      currentTitle: currentTitle ?? this.currentTitle,
      currentSubtitle: currentSubtitle ?? this.currentSubtitle,
      currentUri: currentUri ?? this.currentUri,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bitrateKbps: bitrateKbps ?? this.bitrateKbps,
      sleepTimerMinutes: sleepTimerMinutes ?? this.sleepTimerMinutes,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}

class QuranYutlaAudioNotifier extends StateNotifier<PlaybackState> {
  QuranYutlaAudioNotifier() : super(const PlaybackState());

  void playRadio(String stationName, String trackName, String streamUrl) {
    state = state.copyWith(
      isPlaying: true,
      mode: PlaybackMode.radio,
      currentTitle: stationName,
      currentSubtitle: trackName,
      currentUri: streamUrl,
      position: Duration.zero,
      duration: Duration.zero,
    );
  }

  void playQuranTrack(String surahName, String reciterName, String audioUrl, {Duration? duration}) {
    state = state.copyWith(
      isPlaying: true,
      mode: PlaybackMode.quranAudio,
      currentTitle: surahName,
      currentSubtitle: reciterName,
      currentUri: audioUrl,
      position: Duration.zero,
      duration: duration ?? const Duration(minutes: 20),
    );
  }

  void playOfflineTrack(String surahName, String reciterName, String localPath) {
    state = state.copyWith(
      isPlaying: true,
      mode: PlaybackMode.offlineFile,
      currentTitle: '$surahName (تنزيل محلي)',
      currentSubtitle: reciterName,
      currentUri: localPath,
      position: Duration.zero,
      duration: const Duration(minutes: 20),
    );
  }

  void togglePlayPause() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  void seek(Duration position) {
    state = state.copyWith(position: position);
  }

  void stop() {
    state = state.copyWith(isPlaying: false, position: Duration.zero);
  }

  void setSleepTimer(int? minutes) {
    state = state.copyWith(sleepTimerMinutes: minutes);
  }
}

final audioPlaybackProvider =
    StateNotifierProvider<QuranYutlaAudioNotifier, PlaybackState>((ref) {
  return QuranYutlaAudioNotifier();
});
