import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android owns file picking, background task visibility and offline alarms.
/// MissingPluginException keeps desktop and unit-test implementations usable.
abstract final class NativeAudio {
  static const channel = MethodChannel('app.tarteel.tarteel/offline');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<T?> call<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (!supported) return null;
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    }
  }

  static Future<String?> pickAudio() => call<String>('pickAudio');
  static Future<void> task(
    String title, {
    double? progress,
    bool recording = false,
    String id = 'download',
  }) async {
    try {
      await call<void>('task', {
        'title': title,
        'progress': progress == null ? -1 : (progress * 100).round(),
        'recording': recording,
        'id': id,
      });
    } on PlatformException {
      /* Transfer remains resumable. */
    }
  }

  static Future<void> finishTask({
    bool recording = false,
    String id = 'download',
  }) async {
    try {
      await call<void>('finishTask', {'recording': recording, 'id': id});
    } on PlatformException {
      /* Already stopped. */
    }
  }
}
