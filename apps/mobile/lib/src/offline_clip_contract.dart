import 'package:flutter/foundation.dart';

import 'models.dart';

class OfflineClipPolicy {
  const OfflineClipPolicy({
    required this.stationId,
    required this.allowed,
    required this.supportedStream,
    this.streamType,
    this.verifiedAt,
  });

  final String stationId;
  final bool allowed;
  final bool supportedStream;
  final String? streamType;
  final DateTime? verifiedAt;

  factory OfflineClipPolicy.fromJson(Map<String, dynamic> json) =>
      OfflineClipPolicy(
        stationId: json['station_id'] is String
            ? json['station_id'] as String
            : '',
        allowed: json['allowed'] == true,
        supportedStream: json['supported_stream'] == true,
        streamType: json['stream_type'] is String
            ? json['stream_type'] as String
            : null,
        verifiedAt: json['verified_at'] is String
            ? DateTime.tryParse(json['verified_at'] as String)
            : null,
      );
}

class OfflineClip {
  const OfflineClip({
    required this.id,
    required this.stationId,
    required this.stationNameAr,
    required this.filePath,
    required this.createdAt,
    required this.duration,
    required this.sizeBytes,
    required this.format,
    required this.partial,
    this.artworkUrl,
  });

  final String id;
  final String stationId;
  final String stationNameAr;
  final String? artworkUrl;
  final String filePath;
  final DateTime createdAt;
  final Duration duration;
  final int sizeBytes;
  final String format;
  final bool partial;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'station_id': stationId,
    'station_name_ar': stationNameAr,
    'artwork_url': artworkUrl,
    'file_path': filePath,
    'created_at': createdAt.toIso8601String(),
    'duration_ms': duration.inMilliseconds,
    'size_bytes': sizeBytes,
    'format': format,
    'partial': partial,
  };

  factory OfflineClip.fromJson(Map<String, dynamic> json) => OfflineClip(
    id: json['id'] as String,
    stationId: json['station_id'] as String,
    stationNameAr: json['station_name_ar'] as String,
    artworkUrl: json['artwork_url'] as String?,
    filePath: json['file_path'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    duration: Duration(milliseconds: (json['duration_ms'] as num).toInt()),
    sizeBytes: (json['size_bytes'] as num).toInt(),
    format: json['format'] as String,
    partial: json['partial'] == true,
  );
}

abstract class OfflineClipService extends ChangeNotifier {
  bool get supported;
  List<OfflineClip> get clips;
  String? get activeStationId;
  Duration get activeElapsed;
  int get activeBytes;
  String? get lastError;

  Future<void> initialize();
  Future<void> start({
    required Station station,
    required OfflineClipPolicy policy,
    Duration? maxDuration,
  });
  Future<OfflineClip?> stop();
  Future<void> delete(String clipId);
  Future<bool> exists(OfflineClip clip);
}
