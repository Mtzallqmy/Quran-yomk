import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/adhan_library.dart';

void main() {
  test('catalog exposes only attributed public-domain recordings', () {
    expect(adhanRecordings, isNotEmpty);
    for (final recording in adhanRecordings) {
      expect(recording.sourceUrl, startsWith('https://'));
      expect(recording.licenseUrl, startsWith('https://'));
      expect(recording.licenseLabel, contains('ملكية عامة'));
    }
  });

  test('missing selected file is cleared on load', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'adhan:selected:v1': 'missing',
      'adhan:files:v1': '{"missing":"/tmp/adhan-does-not-exist.ogg"}',
    });
    final store = AdhanLibraryStore(await SharedPreferences.getInstance())..load();
    expect(store.selectedId, isNull);
    expect(store.selectedPath, isNull);
    expect(store.isDownloaded('missing'), isFalse);
    expect(File('/tmp/adhan-does-not-exist.ogg').existsSync(), isFalse);
  });
}
