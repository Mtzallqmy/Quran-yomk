import 'dart:async';

import 'package:flutter/widgets.dart';

/// Optional disk and network work cannot hold the first frame or each other.
void initializeAfterFirstFrame(Map<String, Future<void> Function()> tasks) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    for (final task in tasks.entries) {
      unawaited(
        Future<void>.sync(task.value).catchError((Object error) {
          debugPrint('STARTUP_TASK_FAILED:${task.key}');
        }),
      );
    }
  });
}
