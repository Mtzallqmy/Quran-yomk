import 'package:flutter_test/flutter_test.dart';
import 'package:tarteel/src/offline_clip_contract.dart';

void main() {
  test('offline clip policy accepts rights-gated probed radio stream', () {
    final policy = OfflineClipPolicy.fromJson(<String, dynamic>{
      'station_id': 'station-1',
      'allowed': true,
      'supported_stream': true,
      'stream_type': 'SHOUTCAST',
      'verified_at': '2026-08-31T03:03:18Z',
    });

    expect(policy.stationId, 'station-1');
    expect(policy.allowed, isTrue);
    expect(policy.supportedStream, isTrue);
    expect(policy.streamType, 'SHOUTCAST');
    expect(policy.verifiedAt, isNotNull);
  });

  test('saved clip metadata round-trips duration size and partial state', () {
    final clip = OfflineClip(
      id: 'clip-1',
      stationId: 'station-1',
      stationNameAr: 'إذاعة القرآن',
      artworkUrl: 'https://example.test/art.png',
      filePath: '/tmp/clip-1.mp3',
      createdAt: DateTime.utc(2026, 8, 31, 3, 0),
      duration: const Duration(minutes: 5, seconds: 3),
      sizeBytes: 123456,
      format: 'mp3',
      partial: true,
    );

    final restored = OfflineClip.fromJson(clip.toJson());
    expect(restored.id, clip.id);
    expect(restored.stationId, clip.stationId);
    expect(restored.stationNameAr, clip.stationNameAr);
    expect(restored.duration, clip.duration);
    expect(restored.sizeBytes, clip.sizeBytes);
    expect(restored.format, 'mp3');
    expect(restored.partial, isTrue);
  });
}
