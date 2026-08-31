import 'package:shared_preferences/shared_preferences.dart';

import 'offline_clip_contract.dart';
import 'offline_clip_service_stub.dart'
    if (dart.library.io) 'offline_clip_service_io.dart' as platform;

export 'offline_clip_contract.dart';

OfflineClipService createOfflineClipService(SharedPreferences preferences) =>
    platform.createOfflineClipService(preferences);
