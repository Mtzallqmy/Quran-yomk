import 'package:shared_preferences/shared_preferences.dart';

import 'quran_download_contract.dart';
import 'quran_download_service_stub.dart'
    if (dart.library.io) 'quran_download_service_io.dart'
    as platform;

export 'quran_download_contract.dart';

QuranDownloadService createQuranDownloadService(
  SharedPreferences preferences,
) => platform.createQuranDownloadService(preferences);
