import 'package:flutter_test/flutter_test.dart';
import 'package:tarteel/src/models.dart';

void main() {
  test('station parses listener-safe playback URL', () {
    final station = Station.fromJson(<String, dynamic>{
      'id': 'station-1', 'slug': 'tarteel-dev', 'name_ar': 'ترتيل', 'station_source': 'INTERNAL', 'stream_type': 'INTERNAL', 'playback_url': 'https://stream.example/tarteel.mp3',
    });
    expect(station.isInternal, isTrue);
    expect(station.isPlayable, isTrue);
    expect(station.playbackUrl, startsWith('https://'));
  });

  test('track keeps stable ID and authorized playback URL', () {
    final track = ReciterTrack.fromJson(<String, dynamic>{
      'surah': <String, dynamic>{'id': 1, 'number': 1, 'name_ar': 'الفاتحة', 'name_en': 'Al-Fatihah', 'ayah_count': 7},
      'track': <String, dynamic>{'id': 'track-1', 'playback_url': 'https://signed.example/audio.mp3', 'duration_ms': 60000},
    });
    expect(track.id, 'track-1');
    expect(track.surah.number, 1);
    expect(track.isPlayable, isTrue);
  });
}
