import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class TranscriptionWord {
  const TranscriptionWord({
    required this.word,
    required this.start,
    required this.end,
  });

  final String word;
  final double start;
  final double end;

  factory TranscriptionWord.fromJson(Map<String, dynamic> json) =>
      TranscriptionWord(
        word: json['word']?.toString() ?? '',
        start: _double(json['start']),
        end: _double(json['end']),
      );
}

class TranscriptionResult {
  const TranscriptionResult({required this.text, this.words = const []});

  final String text;
  final List<TranscriptionWord> words;

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) =>
      TranscriptionResult(
        text: json['text']?.toString() ?? '',
        words: json['words'] is List
            ? (json['words'] as List)
                  .whereType<Map>()
                  .map(
                    (row) => TranscriptionWord.fromJson(
                      Map<String, dynamic>.from(row),
                    ),
                  )
                  .toList(growable: false)
            : const <TranscriptionWord>[],
      );
}

enum TranscriptionConnectionState {
  disabled,
  disconnected,
  connecting,
  connected,
  error,
}

class TranscriptionStatus {
  const TranscriptionStatus(this.state, {this.message});
  final TranscriptionConnectionState state;
  final String? message;
}

abstract class TranscriptionService {
  bool get configured;
  Uri? get endpoint;
  Stream<TranscriptionStatus> get statusStream;
  Stream<TranscriptionResult> get resultStream;

  Future<void> connect();

  /// Sends raw little-endian signed PCM mono 16-bit at 16 kHz.
  ///
  /// Audio capture/resampling is deliberately outside this service. This keeps
  /// Whisper transport independent from the radio player and allows a future
  /// native PCM tap or Flutter-Web Web Audio bridge to feed the same contract.
  void sendPcm16Mono16k(Uint8List bytes);

  Future<void> disconnect();
  Future<void> dispose();
}

class WebSocketTranscriptionService implements TranscriptionService {
  WebSocketTranscriptionService({Uri? endpoint}) : _endpoint = endpoint;

  factory WebSocketTranscriptionService.fromEnvironment() {
    const value = String.fromEnvironment(
      'TARTEEL_TRANSCRIPTION_WS_URL',
      defaultValue: '',
    );
    if (value.trim().isEmpty) {
      return WebSocketTranscriptionService();
    }
    final parsed = Uri.tryParse(value.trim());
    if (parsed == null || (parsed.scheme != 'ws' && parsed.scheme != 'wss')) {
      return WebSocketTranscriptionService();
    }
    return WebSocketTranscriptionService(endpoint: parsed);
  }

  final Uri? _endpoint;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final StreamController<TranscriptionStatus> _status =
      StreamController<TranscriptionStatus>.broadcast();
  final StreamController<TranscriptionResult> _results =
      StreamController<TranscriptionResult>.broadcast();

  @override
  bool get configured => _endpoint != null;

  @override
  Uri? get endpoint => _endpoint;

  @override
  Stream<TranscriptionStatus> get statusStream => _status.stream;

  @override
  Stream<TranscriptionResult> get resultStream => _results.stream;

  @override
  Future<void> connect() async {
    if (!configured) {
      _status.add(
        const TranscriptionStatus(
          TranscriptionConnectionState.disabled,
          message:
              'التفريغ غير مفعّل. اضبط TARTEEL_TRANSCRIPTION_WS_URL على خادم Whisper الخاص بترتيل.',
        ),
      );
      return;
    }
    await disconnect();
    _status.add(
      const TranscriptionStatus(TranscriptionConnectionState.connecting),
    );
    try {
      final channel = WebSocketChannel.connect(_endpoint!);
      await channel.ready.timeout(const Duration(seconds: 10));
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleMessage,
        onError: (Object error, StackTrace stackTrace) {
          _status.add(
            TranscriptionStatus(
              TranscriptionConnectionState.error,
              message: 'فشل اتصال التفريغ: $error',
            ),
          );
        },
        onDone: () {
          _channel = null;
          _status.add(
            const TranscriptionStatus(
              TranscriptionConnectionState.disconnected,
            ),
          );
        },
        cancelOnError: false,
      );
      _status.add(
        const TranscriptionStatus(TranscriptionConnectionState.connected),
      );
    } on TimeoutException catch (error) {
      _status.add(
        TranscriptionStatus(
          TranscriptionConnectionState.error,
          message: 'انتهت مهلة الاتصال بخادم التفريغ: $error',
        ),
      );
      rethrow;
    } catch (error) {
      _status.add(
        TranscriptionStatus(
          TranscriptionConnectionState.error,
          message: 'تعذر فتح WebSocket للتفريغ: $error',
        ),
      );
      rethrow;
    }
  }

  @override
  void sendPcm16Mono16k(Uint8List bytes) {
    if (bytes.isEmpty) return;
    final channel = _channel;
    if (channel == null) {
      throw StateError('Transcription WebSocket is not connected');
    }
    channel.sink.add(bytes);
  }

  void _handleMessage(dynamic event) {
    try {
      final decoded = switch (event) {
        String value => jsonDecode(value),
        List<int> value => jsonDecode(utf8.decode(value)),
        _ => null,
      };
      if (decoded is! Map) return;
      final json = Map<String, dynamic>.from(decoded);
      if (json['error'] != null) {
        _status.add(
          TranscriptionStatus(
            TranscriptionConnectionState.error,
            message: json['error'].toString(),
          ),
        );
        return;
      }
      _results.add(TranscriptionResult.fromJson(json));
    } catch (error) {
      _status.add(
        TranscriptionStatus(
          TranscriptionConnectionState.error,
          message: 'استجابة التفريغ غير صالحة: $error',
        ),
      );
    }
  }

  @override
  Future<void> disconnect() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await channel.sink.close();
    }
    if (configured) {
      _status.add(
        const TranscriptionStatus(
          TranscriptionConnectionState.disconnected,
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _status.close();
    await _results.close();
  }
}

final transcriptionServiceProvider = Provider<TranscriptionService>((ref) {
  final service = WebSocketTranscriptionService.fromEnvironment();
  ref.onDispose(service.dispose);
  return service;
});

double _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}
