import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TranscriptionState {
  disabled,
  unsupported,
  connecting,
  active,
  reconnecting,
  error,
  stopped,
}

abstract interface class TranscriptionService {
  TranscriptionState get state;
  Stream<TranscriptionState> get stateStream;
  Stream<String> get textStream;
  bool get supported;
  Future<void> start(String streamUrl);
  Future<void> stop();
}

/// Phase 11 deliberately keeps transcription independent from radio playback.
///
/// The repository currently ships Android/iOS listener targets. Native Flutter
/// cannot capture decoded third-party stream audio through the browser Web Audio
/// API, and Tarteel must not request microphone/system-audio permissions for this
/// purpose. A future Flutter Web target can provide a dedicated AudioWorklet
/// implementation behind this interface when a secure WSS Whisper relay exists.
class DisabledTranscriptionService implements TranscriptionService {
  DisabledTranscriptionService() {
    _state = _configured && kIsWeb
        ? TranscriptionState.unsupported
        : TranscriptionState.disabled;
  }

  static const bool _configured = bool.fromEnvironment(
    'TARTEEL_ENABLE_LIVE_TRANSCRIPTION',
    defaultValue: false,
  );
  static const String websocketUrl = String.fromEnvironment(
    'TARTEEL_TRANSCRIPTION_WS_URL',
    defaultValue: '',
  );

  late TranscriptionState _state;
  final StreamController<TranscriptionState> _states =
      StreamController<TranscriptionState>.broadcast();
  final StreamController<String> _text = StreamController<String>.broadcast();

  @override
  TranscriptionState get state => _state;

  @override
  Stream<TranscriptionState> get stateStream => _states.stream;

  @override
  Stream<String> get textStream => _text.stream;

  @override
  bool get supported => false;

  @override
  Future<void> start(String streamUrl) async {
    _state = _configured
        ? TranscriptionState.unsupported
        : TranscriptionState.disabled;
    _states.add(_state);
    throw UnsupportedError(
      _configured
          ? 'التفريغ المباشر غير مدعوم على منصة التشغيل الحالية.'
          : 'التفريغ المباشر غير مفعّل في هذا الإصدار.',
    );
  }

  @override
  Future<void> stop() async {
    _state = TranscriptionState.stopped;
    _states.add(_state);
  }
}

final transcriptionServiceProvider = Provider<TranscriptionService>(
  (_) => DisabledTranscriptionService(),
);
