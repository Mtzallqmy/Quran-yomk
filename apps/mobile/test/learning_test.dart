import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/learning.dart';
import 'package:tarteel/src/local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  test(
    'canonical Quran snapshot checksum and verse count remain unchanged',
    () {
      final manifest =
          jsonDecode(
                File(
                  '../../data/quran/canonical/v1/manifest.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final dataset = File(
        '../../data/quran/canonical/v1/dataset.json',
      ).readAsBytesSync();
      expect(sha256.convert(dataset).toString(), manifest['sha256']);
      expect(manifest['verses'], 6236);
      expect(manifest['surahs'], 114);
      expect(manifest['approval_policy'], 'VERBATIM_SNAPSHOT_NO_TEXT_MUTATION');
    },
  );

  test(
    'bundled educational content is source-bounded and structurally valid',
    () async {
      final content = await EducationalContent.load();
      expect(content.segments, hasLength(4));
      expect(content.segments.map((value) => value.surah).toSet(), <int>{
        1,
        112,
      });
      expect(
        content.segments.every(
          (value) => value.reviewStatus == 'source_checked',
        ),
        isTrue,
      );
      expect(
        content.adhkar.map((value) => value.category).toSet(),
        containsAll(<String>{
          'morning',
          'evening',
          'after_prayer',
          'sleep',
          'waking',
          'general',
        }),
      );
      expect(
        () => validateThematicSegments(content.segments, const <int, int>{
          1: 7,
          112: 4,
        }),
        returnsNormally,
      );
    },
  );

  test('thematic validation rejects overlap and gaps', () {
    const invalid = <ThematicSegment>[
      ThematicSegment(
        surah: 1,
        startAyah: 1,
        endAyah: 2,
        topicTitleAr: 'أ',
        topicSummaryAr: '',
        colorToken: 'emerald',
        source: 'source',
        reviewStatus: 'source_checked',
      ),
      ThematicSegment(
        surah: 1,
        startAyah: 4,
        endAyah: 7,
        topicTitleAr: 'ب',
        topicSummaryAr: '',
        colorToken: 'gold',
        source: 'source',
        reviewStatus: 'source_checked',
      ),
    ];
    expect(
      () => validateThematicSegments(invalid, const <int, int>{1: 7}),
      throwsFormatException,
    );
  });

  test('blank exercise never mutates canonical Quran text', () {
    const uthmani = 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ';
    final shown = presentationBlank(uthmani);
    expect(shown, isNot(uthmani));
    expect(uthmani, 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ');
  });

  test('repetition and next-item order are deterministic', () {
    expect(
      buildRepetitionSequence(
        <int>[1, 2],
        repetitionsPerItem: 2,
        segmentRepetitions: 2,
      ),
      <int>[1, 1, 2, 2, 1, 1, 2, 2],
    );
    expect(nextItem(<int>[1, 2, 3], 2), 3);
    expect(nextItem(<int>[1, 2, 3], 3), isNull);
  });

  test(
    'progress, plan, review priority and daily adhkar persist locally',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final store = LearningStore(preferences)
        ..load(now: DateTime.utc(2026, 9, 7));
      await store.recordReview(
        '1:1-2',
        ReviewOutcome.incorrect,
        now: DateTime.utc(2026, 9, 1),
      );
      await store.recordReview(
        '112:1-4',
        ReviewOutcome.correct,
        now: DateTime.utc(2026, 9, 1),
      );
      await store.savePlan(
        MemorizationPlan(ayahsPerDay: 7, startDate: DateTime.utc(2026, 9, 1)),
      );
      const dhikr = AdhkarEntry(
        id: 'test',
        category: 'general',
        text: 'ذكر',
        count: 2,
        source: 'source',
        reference: '1',
        authenticity: 'صحيح',
      );
      await store.incrementAdhkar(dhikr, now: DateTime.utc(2026, 9, 7));

      final restored = LearningStore(preferences)
        ..load(now: DateTime.utc(2026, 9, 7));
      expect(restored.statusFor('1:1-2'), MemorizationStatus.needsReview);
      expect(restored.plan?.ayahsPerDay, 7);
      expect(restored.adhkarCount('test', now: DateTime.utc(2026, 9, 7)), 1);
      expect(restored.dueReviews(DateTime.utc(2026, 9, 7)).first.key, '1:1-2');
    },
  );

  test(
    'adhkar reminders require permission, schedule once, and cancel',
    () async {
      final gateway = _NotificationGateway();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = LearningStore(await SharedPreferences.getInstance())
        ..load();
      final controller = AdhkarReminderController(
        notifications: LocalNotificationService(gateway: gateway),
        store: store,
      );
      expect(
        await controller.schedule(
          'morning',
          hour: 6,
          minute: 0,
          now: DateTime.utc(2026, 9, 7),
        ),
        isFalse,
      );
      gateway.allowed = true;
      expect(
        await controller.schedule(
          'morning',
          hour: 6,
          minute: 0,
          now: DateTime.utc(2026, 9, 7),
        ),
        isTrue,
      );
      expect(gateway.pending.keys, <int>[
        AdhkarReminderController.ids['morning']!,
      ]);
      await controller.cancel('morning');
      expect(gateway.pending, isEmpty);
    },
  );
}

class _NotificationGateway implements LocalNotificationGateway {
  bool allowed = false;
  final Map<int, LocalNotificationRequest> pending =
      <int, LocalNotificationRequest>{};

  @override
  Future<void> cancel(int id) async => pending.remove(id);
  @override
  Future<bool> exactSchedulingAvailable() async => false;
  @override
  Future<String?> initialize(void Function(String payload) onTap) async => null;
  @override
  Future<bool> openSystemSettings() async => false;
  @override
  Future<bool> permissionGranted() async => allowed;
  @override
  Future<bool> requestPermission() async => allowed;
  @override
  Future<void> schedule(
    LocalNotificationRequest request, {
    required bool exact,
  }) async => pending[request.id] = request;
  @override
  Future<void> show(LocalNotificationRequest request) async {}
}
