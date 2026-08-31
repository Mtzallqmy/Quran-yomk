import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'offline_clip_contract.dart';

OfflineClipService createOfflineClipService(SharedPreferences preferences) =>
    _UnsupportedOfflineClipService();

class _UnsupportedOfflineClipService extends OfflineClipService {
  @override
  bool get supported => false;
  @override
  List<OfflineClip> get clips => const <OfflineClip>[];
  @override
  String? get activeStationId => null;
  @override
  Duration get activeElapsed => Duration.zero;
  @override
  int get activeBytes => 0;
  @override
  String? get lastError => null;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> start({
    required Station station,
    required OfflineClipPolicy policy,
    Duration? maxDuration,
  }) async => throw UnsupportedError('OFFLINE_CLIPS_UNSUPPORTED');
  @override
  Future<OfflineClip?> stop() async => null;
  @override
  Future<void> delete(String clipId) async {}
  @override
  Future<bool> exists(OfflineClip clip) async => false;
}
