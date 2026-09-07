import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'local_notifications.dart';

enum MemorizationStatus { newItem, learning, needsReview, memorized, mastered }

extension MemorizationStatusAr on MemorizationStatus {
  String get label => switch (this) {
    MemorizationStatus.newItem => 'جديد',
    MemorizationStatus.learning => 'قيد الحفظ',
    MemorizationStatus.needsReview => 'يحتاج مراجعة',
    MemorizationStatus.memorized => 'محفوظ',
    MemorizationStatus.mastered => 'متقن',
  };
}

enum MemorizationMode {
  listenAndRead,
  listenThenRepeat,
  gradualHide,
  nextAyah,
  blanks,
}

extension MemorizationModeAr on MemorizationMode {
  String get label => switch (this) {
    MemorizationMode.listenAndRead => 'استمع واقرأ',
    MemorizationMode.listenThenRepeat => 'استمع ثم ردد',
    MemorizationMode.gradualHide => 'الإخفاء التدريجي',
    MemorizationMode.nextAyah => 'اختبار الآية التالية',
    MemorizationMode.blanks => 'اختبار الفراغات',
  };
}

enum MemorizationUnit { ayah, ayat, thematicSegment, page, halfPage }

extension MemorizationUnitAr on MemorizationUnit {
  String get label => switch (this) {
    MemorizationUnit.ayah => 'آية واحدة',
    MemorizationUnit.ayat => 'عدة آيات',
    MemorizationUnit.thematicSegment => 'مقطع موضوعي كامل',
    MemorizationUnit.page => 'صفحة',
    MemorizationUnit.halfPage => 'نصف صفحة',
  };
}

@immutable
class ThematicSegment {
  const ThematicSegment({
    required this.surah,
    required this.startAyah,
    required this.endAyah,
    required this.topicTitleAr,
    required this.topicSummaryAr,
    required this.colorToken,
    required this.source,
    required this.reviewStatus,
  });

  final int surah;
  final int startAyah;
  final int endAyah;
  final String topicTitleAr;
  final String topicSummaryAr;
  final String colorToken;
  final String source;
  final String reviewStatus;

  String get id => '$surah:$startAyah-$endAyah';

  factory ThematicSegment.fromJson(Map<String, dynamic> json) =>
      ThematicSegment(
        surah: (json['surah'] as num).toInt(),
        startAyah: (json['startAyah'] as num).toInt(),
        endAyah: (json['endAyah'] as num).toInt(),
        topicTitleAr: json['topicTitleAr'] as String,
        topicSummaryAr: json['topicSummaryAr'] as String,
        colorToken: json['colorToken'] as String,
        source: json['source'] as String,
        reviewStatus: json['reviewStatus'] as String,
      );
}

@immutable
class AdhkarEntry {
  const AdhkarEntry({
    required this.id,
    required this.category,
    required this.text,
    required this.count,
    required this.source,
    required this.reference,
    required this.authenticity,
  });

  final String id;
  final String category;
  final String text;
  final int count;
  final String source;
  final String reference;
  final String authenticity;

  factory AdhkarEntry.fromJson(Map<String, dynamic> json) => AdhkarEntry(
    id: json['id'] as String,
    category: json['category'] as String,
    text: json['text'] as String,
    count: (json['count'] as num).toInt(),
    source: json['source'] as String,
    reference: json['reference'] as String,
    authenticity: json['authenticity'] as String,
  );
}

class EducationalContent {
  const EducationalContent({required this.segments, required this.adhkar});

  final List<ThematicSegment> segments;
  final List<AdhkarEntry> adhkar;

  static Future<EducationalContent> load({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    final thematic =
        jsonDecode(
              await assets.loadString('assets/learning/thematic_segments.json'),
            )
            as Map<String, dynamic>;
    final adhkar =
        jsonDecode(await assets.loadString('assets/learning/adhkar.json'))
            as Map<String, dynamic>;
    final segments = (thematic['segments'] as List<dynamic>)
        .map(
          (value) =>
              ThematicSegment.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(growable: false);
    validateThematicSegments(segments, const <int, int>{1: 7, 112: 4});
    return EducationalContent(
      segments: segments,
      adhkar: (adhkar['items'] as List<dynamic>)
          .map(
            (value) =>
                AdhkarEntry.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(growable: false),
    );
  }
}

void validateThematicSegments(
  List<ThematicSegment> segments,
  Map<int, int> completedSurahs,
) {
  for (final entry in completedSurahs.entries) {
    final values = segments.where((value) => value.surah == entry.key).toList()
      ..sort((a, b) => a.startAyah.compareTo(b.startAyah));
    var expected = 1;
    for (final value in values) {
      if (value.startAyah != expected || value.endAyah < value.startAyah) {
        throw FormatException(
          'Invalid thematic coverage for surah ${entry.key}',
        );
      }
      expected = value.endAyah + 1;
    }
    if (expected != entry.value + 1) {
      throw FormatException(
        'Incomplete thematic coverage for surah ${entry.key}',
      );
    }
  }
}

@immutable
class MemorizationRecord {
  const MemorizationRecord({
    required this.key,
    required this.status,
    required this.lastReviewedAt,
    required this.nextReviewAt,
    required this.successes,
    required this.errors,
    required this.intervalDays,
  });

  final String key;
  final MemorizationStatus status;
  final DateTime lastReviewedAt;
  final DateTime nextReviewAt;
  final int successes;
  final int errors;
  final int intervalDays;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key,
    'status': status.name,
    'lastReviewedAt': lastReviewedAt.toUtc().toIso8601String(),
    'nextReviewAt': nextReviewAt.toUtc().toIso8601String(),
    'successes': successes,
    'errors': errors,
    'intervalDays': intervalDays,
  };

  factory MemorizationRecord.fromJson(Map<String, dynamic> json) =>
      MemorizationRecord(
        key: json['key'] as String,
        status: MemorizationStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => MemorizationStatus.newItem,
        ),
        lastReviewedAt: DateTime.parse(json['lastReviewedAt'] as String),
        nextReviewAt: DateTime.parse(json['nextReviewAt'] as String),
        successes: (json['successes'] as num?)?.toInt() ?? 0,
        errors: (json['errors'] as num?)?.toInt() ?? 0,
        intervalDays: (json['intervalDays'] as num?)?.toInt() ?? 1,
      );
}

enum ReviewOutcome { correct, helped, incorrect }

@immutable
class MemorizationPlan {
  const MemorizationPlan({
    this.ayahsPerDay = 5,
    this.pagesPerDay = 0,
    this.thematicSegmentsPerDay = 0,
    this.fromSurah = 1,
    this.toSurah = 114,
    required this.startDate,
    this.studyWeekdays = const <int>{1, 2, 3, 4, 5},
  });

  final int ayahsPerDay;
  final int pagesPerDay;
  final int thematicSegmentsPerDay;
  final int fromSurah;
  final int toSurah;
  final DateTime startDate;
  final Set<int> studyWeekdays;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'ayahsPerDay': ayahsPerDay,
    'pagesPerDay': pagesPerDay,
    'thematicSegmentsPerDay': thematicSegmentsPerDay,
    'fromSurah': fromSurah,
    'toSurah': toSurah,
    'startDate': startDate.toIso8601String(),
    'studyWeekdays': studyWeekdays.toList(),
  };

  factory MemorizationPlan.fromJson(Map<String, dynamic> json) =>
      MemorizationPlan(
        ayahsPerDay: (json['ayahsPerDay'] as num?)?.toInt() ?? 5,
        pagesPerDay: (json['pagesPerDay'] as num?)?.toInt() ?? 0,
        thematicSegmentsPerDay:
            (json['thematicSegmentsPerDay'] as num?)?.toInt() ?? 0,
        fromSurah: (json['fromSurah'] as num?)?.toInt() ?? 1,
        toSurah: (json['toSurah'] as num?)?.toInt() ?? 114,
        startDate: DateTime.parse(json['startDate'] as String),
        studyWeekdays: Set<int>.from(
          (json['studyWeekdays'] as List<dynamic>? ??
                  const <int>[1, 2, 3, 4, 5])
              .cast<num>()
              .map((value) => value.toInt()),
        ),
      );
}

class LearningStore extends ChangeNotifier {
  LearningStore(this._preferences);

  static const _recordsKey = 'learning:records:v1';
  static const _planKey = 'learning:plan:v1';
  static const _adhkarDateKey = 'learning:adhkar:date';
  static const _adhkarCountsKey = 'learning:adhkar:counts';
  static const _reminderPrefix = 'learning:adhkar:reminder:';

  final SharedPreferences _preferences;
  final Map<String, MemorizationRecord> _records =
      <String, MemorizationRecord>{};
  final Map<String, int> _adhkarCounts = <String, int>{};
  MemorizationPlan? plan;

  List<MemorizationRecord> get records => List.unmodifiable(_records.values);

  void load({DateTime? now}) {
    final raw = _preferences.getString(_recordsKey);
    if (raw != null) {
      try {
        for (final value in jsonDecode(raw) as List<dynamic>) {
          final record = MemorizationRecord.fromJson(
            Map<String, dynamic>.from(value as Map),
          );
          _records[record.key] = record;
        }
      } catch (_) {
        _records.clear();
      }
    }
    final rawPlan = _preferences.getString(_planKey);
    if (rawPlan != null) {
      try {
        plan = MemorizationPlan.fromJson(
          Map<String, dynamic>.from(jsonDecode(rawPlan) as Map),
        );
      } catch (_) {
        plan = null;
      }
    }
    _loadDailyAdhkar(now ?? DateTime.now());
  }

  MemorizationStatus statusFor(String key) =>
      _records[key]?.status ?? MemorizationStatus.newItem;

  Future<void> setLearning(String key, {DateTime? now}) =>
      recordReview(key, ReviewOutcome.helped, now: now);

  Future<void> recordReview(
    String key,
    ReviewOutcome outcome, {
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final previous = _records[key];
    final successes =
        (previous?.successes ?? 0) + (outcome == ReviewOutcome.correct ? 1 : 0);
    final errors =
        (previous?.errors ?? 0) + (outcome == ReviewOutcome.incorrect ? 1 : 0);
    final oldInterval = previous?.intervalDays ?? 1;
    final interval = switch (outcome) {
      ReviewOutcome.correct => (oldInterval * 2).clamp(2, 30).toInt(),
      ReviewOutcome.helped => 1,
      ReviewOutcome.incorrect => 1,
    };
    final status = switch (outcome) {
      ReviewOutcome.incorrect => MemorizationStatus.needsReview,
      ReviewOutcome.helped => MemorizationStatus.learning,
      ReviewOutcome.correct when successes >= 5 => MemorizationStatus.mastered,
      ReviewOutcome.correct when successes >= 2 => MemorizationStatus.memorized,
      _ => MemorizationStatus.learning,
    };
    _records[key] = MemorizationRecord(
      key: key,
      status: status,
      lastReviewedAt: at,
      nextReviewAt: at.add(Duration(days: interval)),
      successes: successes,
      errors: errors,
      intervalDays: interval,
    );
    await _persistRecords();
    notifyListeners();
  }

  List<MemorizationRecord> dueReviews(DateTime now) {
    final values = _records.values
        .where((value) => !value.nextReviewAt.isAfter(now))
        .toList();
    values.sort((a, b) {
      final errorOrder = b.errors.compareTo(a.errors);
      if (errorOrder != 0) return errorOrder;
      return a.nextReviewAt.compareTo(b.nextReviewAt);
    });
    return values;
  }

  Future<void> savePlan(MemorizationPlan value) async {
    plan = value;
    await _preferences.setString(_planKey, jsonEncode(value.toJson()));
    notifyListeners();
  }

  int adhkarCount(String id, {DateTime? now}) {
    _rollAdhkarDay(now ?? DateTime.now());
    return _adhkarCounts[id] ?? 0;
  }

  Future<void> incrementAdhkar(AdhkarEntry entry, {DateTime? now}) async {
    _rollAdhkarDay(now ?? DateTime.now());
    _adhkarCounts[entry.id] = ((_adhkarCounts[entry.id] ?? 0) + 1)
        .clamp(0, entry.count)
        .toInt();
    await _persistAdhkar();
    notifyListeners();
  }

  Future<void> resetAdhkar(String id) async {
    _adhkarCounts[id] = 0;
    await _persistAdhkar();
    notifyListeners();
  }

  double adhkarProgress(Iterable<AdhkarEntry> items) {
    var completed = 0;
    var total = 0;
    for (final item in items) {
      completed += adhkarCount(item.id).clamp(0, item.count).toInt();
      total += item.count;
    }
    return total == 0 ? 0 : completed / total;
  }

  bool reminderEnabled(String category) =>
      _preferences.getBool('$_reminderPrefix$category') ?? false;

  Future<void> setReminderEnabled(String category, bool enabled) async {
    await _preferences.setBool('$_reminderPrefix$category', enabled);
    notifyListeners();
  }

  void _loadDailyAdhkar(DateTime now) {
    _rollAdhkarDay(now);
    final raw = _preferences.getString(_adhkarCountsKey);
    if (raw == null) return;
    try {
      final values = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      _adhkarCounts.addAll(
        values.map((key, value) => MapEntry(key, (value as num).toInt())),
      );
    } catch (_) {
      _adhkarCounts.clear();
    }
  }

  void _rollAdhkarDay(DateTime now) {
    final today = '${now.year}-${now.month}-${now.day}';
    if (_preferences.getString(_adhkarDateKey) == today) return;
    _adhkarCounts.clear();
    _preferences.setString(_adhkarDateKey, today);
    _preferences.remove(_adhkarCountsKey);
  }

  Future<void> _persistRecords() => _preferences.setString(
    _recordsKey,
    jsonEncode(_records.values.map((value) => value.toJson()).toList()),
  );

  Future<void> _persistAdhkar() =>
      _preferences.setString(_adhkarCountsKey, jsonEncode(_adhkarCounts));
}

class AdhkarReminderController {
  AdhkarReminderController({required this.notifications, required this.store});

  static const ids = <String, int>{
    'morning': 730101,
    'evening': 730102,
    'sleep': 730103,
  };

  final LocalNotificationService notifications;
  final LearningStore store;

  Future<void> start() async {
    for (final entry in const <String, int>{
      'morning': 6,
      'evening': 18,
      'sleep': 22,
    }.entries) {
      if (store.reminderEnabled(entry.key)) {
        await schedule(entry.key, hour: entry.value, minute: 0);
      }
    }
  }

  Future<bool> schedule(
    String category, {
    required int hour,
    required int minute,
    DateTime? now,
  }) async {
    final id = ids[category];
    if (id == null || !await notifications.permissionGranted()) return false;
    final location = tz.getLocation('Asia/Aden');
    final current = tz.TZDateTime.from(now ?? DateTime.now(), location);
    var target = tz.TZDateTime(
      location,
      current.year,
      current.month,
      current.day,
      hour,
      minute,
    );
    if (!target.isAfter(current)) target = target.add(const Duration(days: 1));
    await notifications.schedule(
      LocalNotificationRequest(
        id: id,
        title: 'أذكار ترتيل',
        body: category == 'morning'
            ? 'حان وقت أذكار الصباح'
            : category == 'evening'
            ? 'حان وقت أذكار المساء'
            : 'لا تنس أذكار النوم',
        scheduledAt: target.toUtc(),
        timezone: 'Asia/Aden',
        payload: '/adhkar',
        channel: LocalNotificationChannel.prayerReminder,
        preferExact: false,
      ),
    );
    return true;
  }

  Future<void> cancel(String category) async {
    final id = ids[category];
    if (id != null) await notifications.cancel(id);
  }
}

String presentationBlank(String uthmaniText, {int stride = 3}) {
  final words = uthmaniText.split(RegExp(r'\s+'));
  return List<String>.generate(
    words.length,
    (index) => index % stride == stride - 1 ? 'ــــــ' : words[index],
  ).join(' ');
}

int reviewPriority(MemorizationRecord record, DateTime now) {
  final overdue = now
      .difference(record.nextReviewAt)
      .inDays
      .clamp(0, 365)
      .toInt();
  return record.errors * 10 + overdue * 2 - record.successes;
}

List<T> buildRepetitionSequence<T>(
  List<T> values, {
  required int repetitionsPerItem,
  required int segmentRepetitions,
}) {
  if (repetitionsPerItem < 1 || segmentRepetitions < 1) {
    throw ArgumentError('Repetition values must be positive');
  }
  return <T>[
    for (var segment = 0; segment < segmentRepetitions; segment++)
      for (final value in values)
        for (var repeat = 0; repeat < repetitionsPerItem; repeat++) value,
  ];
}

T? nextItem<T>(List<T> values, T current) {
  final index = values.indexOf(current);
  return index >= 0 && index + 1 < values.length ? values[index + 1] : null;
}
