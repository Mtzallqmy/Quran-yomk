import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'services.dart';

class VirtualRadioProgram {
  const VirtualRadioProgram({
    required this.id,
    required this.titleAr,
    required this.category,
    this.titleEn,
    this.subtitleAr,
    this.startedAt,
    this.endsAt,
  });

  final String id;
  final String titleAr;
  final String? titleEn;
  final String? subtitleAr;
  final String category;
  final DateTime? startedAt;
  final DateTime? endsAt;

  factory VirtualRadioProgram.fromJson(JsonMap json) => VirtualRadioProgram(
        id: json['id'] is String ? json['id'] as String : '',
        titleAr: json['title_ar'] is String ? json['title_ar'] as String : 'بث مختار',
        titleEn: json['title_en'] is String ? json['title_en'] as String : null,
        subtitleAr: json['subtitle_ar'] is String ? json['subtitle_ar'] as String : null,
        category: json['category'] is String ? json['category'] as String : 'OTHER',
        startedAt: DateTime.tryParse(json['started_at']?.toString() ?? ''),
        endsAt: DateTime.tryParse(json['ends_at']?.toString() ?? ''),
      );
}

class VirtualRadioResolution {
  const VirtualRadioResolution({
    required this.channelId,
    required this.channelSlug,
    required this.channelNameAr,
    required this.timezone,
    required this.available,
    required this.serverTime,
    this.artworkUrl,
    this.program,
    this.station,
    this.nextChangeAt,
    this.nextProgramTitleAr,
    this.selectionTier,
  });

  final String channelId;
  final String channelSlug;
  final String channelNameAr;
  final String timezone;
  final bool available;
  final String? artworkUrl;
  final VirtualRadioProgram? program;
  final Station? station;
  final DateTime serverTime;
  final DateTime? nextChangeAt;
  final String? nextProgramTitleAr;
  final int? selectionTier;

  factory VirtualRadioResolution.fromJson(JsonMap json) {
    final channel = json['channel'] is Map
        ? Map<String, dynamic>.from(json['channel'] as Map)
        : <String, dynamic>{};
    final program = json['program'] is Map
        ? Map<String, dynamic>.from(json['program'] as Map)
        : null;
    final station = json['station'] is Map
        ? Map<String, dynamic>.from(json['station'] as Map)
        : null;
    final next = json['next_program'] is Map
        ? Map<String, dynamic>.from(json['next_program'] as Map)
        : null;
    final resolution = json['resolution'] is Map
        ? Map<String, dynamic>.from(json['resolution'] as Map)
        : <String, dynamic>{};
    return VirtualRadioResolution(
      channelId: channel['id']?.toString() ?? 'tarteel',
      channelSlug: channel['slug']?.toString() ?? 'tarteel',
      channelNameAr: channel['name_ar']?.toString() ?? 'إذاعة ترتيل',
      timezone: channel['timezone']?.toString() ?? 'Asia/Aden',
      artworkUrl: channel['artwork_url'] is String ? channel['artwork_url'] as String : null,
      available: json['available'] == true,
      program: program == null ? null : VirtualRadioProgram.fromJson(program),
      station: station == null ? null : Station.fromJson(station),
      serverTime: DateTime.tryParse(json['server_time']?.toString() ?? '') ?? DateTime.now().toUtc(),
      nextChangeAt: DateTime.tryParse(json['next_change_at']?.toString() ?? ''),
      nextProgramTitleAr: next?['title_ar']?.toString(),
      selectionTier: resolution['selection_tier'] is num
          ? (resolution['selection_tier'] as num).toInt()
          : null,
    );
  }
}

final virtualRadioProvider = AsyncNotifierProvider<VirtualRadioController, VirtualRadioResolution>(
  VirtualRadioController.new,
);

class VirtualRadioController extends AsyncNotifier<VirtualRadioResolution> {
  StreamSubscription<String>? _errorSubscription;
  Timer? _boundaryTimer;
  final Set<String> _failedStations = <String>{};
  bool _playing = false;
  bool _failoverBusy = false;
  int _recentPlaybackErrors = 0;

  @override
  Future<VirtualRadioResolution> build() async {
    _errorSubscription ??= ref.read(servicesProvider).playback.errorStream.listen((_) {
      if (!_playing || _failoverBusy) return;
      _recentPlaybackErrors += 1;
      if (_recentPlaybackErrors >= 2) unawaited(failover());
    });
    ref.onDispose(() {
      _boundaryTimer?.cancel();
      _errorSubscription?.cancel();
    });
    final value = await _resolve();
    _scheduleBoundary(value);
    return value;
  }

  Future<VirtualRadioResolution> _resolve() => ref
      .read(servicesProvider)
      .repository
      .virtualRadio(failedStationIds: _failedStations.toList(growable: false));

  Future<void> refresh() async {
    _failedStations.clear();
    state = const AsyncLoading<VirtualRadioResolution>();
    state = await AsyncValue.guard(() async {
      final value = await _resolve();
      _scheduleBoundary(value);
      return value;
    });
  }

  Future<void> play() async {
    var value = state.valueOrNull;
    value ??= await _resolve();
    if (!value.available || value.station == null || !value.station!.isPlayable) {
      throw StateError('NO_VIRTUAL_SOURCE_AVAILABLE');
    }
    _playing = true;
    _recentPlaybackErrors = 0;
    try {
      await ref.read(servicesProvider).playback.playVirtualRadio(value);
      state = AsyncData(value);
      _scheduleBoundary(value);
    } catch (_) {
      _failedStations.add(value.station!.id);
      await failover();
    }
  }

  Future<void> pause() async {
    _playing = false;
    await ref.read(servicesProvider).playback.pause();
  }

  Future<void> resume() async {
    final current = state.valueOrNull;
    if (current == null) {
      await play();
      return;
    }
    _playing = true;
    _recentPlaybackErrors = 0;
    await ref.read(servicesProvider).playback.play();
    _scheduleBoundary(current);
  }

  Future<void> failover() async {
    if (_failoverBusy) return;
    _failoverBusy = true;
    try {
      final current = state.valueOrNull;
      if (current?.station != null) _failedStations.add(current!.station!.id);
      if (_failedStations.length > 8) throw StateError('NO_VIRTUAL_SOURCE_AVAILABLE');
      final next = await _resolve();
      if (!next.available || next.station == null || !next.station!.isPlayable) {
        throw StateError('NO_VIRTUAL_SOURCE_AVAILABLE');
      }
      state = AsyncData(next);
      _recentPlaybackErrors = 0;
      if (_playing) await ref.read(servicesProvider).playback.playVirtualRadio(next);
      _scheduleBoundary(next);
    } catch (error, stackTrace) {
      _playing = false;
      state = AsyncError(error, stackTrace);
    } finally {
      _failoverBusy = false;
    }
  }

  Future<void> retry() async {
    final wasPlaying = _playing;
    _failedStations.clear();
    await refresh();
    if (wasPlaying) await play();
  }

  Future<void> stop() async {
    _playing = false;
    _recentPlaybackErrors = 0;
    await ref.read(servicesProvider).playback.stop();
  }

  void _scheduleBoundary(VirtualRadioResolution value) {
    _boundaryTimer?.cancel();
    final next = value.nextChangeAt;
    if (next == null) return;
    final delay = next.difference(DateTime.now().toUtc());
    _boundaryTimer = Timer(
      delay <= Duration.zero ? const Duration(seconds: 1) : delay + const Duration(seconds: 2),
      () => unawaited(_handleBoundary()),
    );
  }

  Future<void> _handleBoundary() async {
    try {
      _failedStations.clear();
      final previous = state.valueOrNull;
      final next = await _resolve();
      state = AsyncData(next);
      if (_playing && next.available && next.station != null) {
        if (previous?.station?.id == next.station!.id) {
          await ref.read(servicesProvider).playback.updateVirtualMetadata(next);
        } else {
          await ref.read(servicesProvider).playback.playVirtualRadio(next);
        }
      }
      _scheduleBoundary(next);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
