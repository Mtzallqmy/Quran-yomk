import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../learning.dart';
import '../models.dart';
import '../quran_audio.dart';
import '../quran_models.dart';
import '../services.dart';

class LearningCenterPage extends ConsumerWidget {
  const LearningCenterPage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(servicesProvider).learning;
    return Scaffold(
      appBar: AppBar(title: const Text('الحفظ والمراجعة')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final due = store.dueReviews(DateTime.now()).length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _ProgressCard(records: store.records, due: due),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.play_circle_outline,
                title: 'ابدأ الحفظ',
                subtitle: 'اختر مقطعًا موضوعيًا وابدأ جلسة عملية',
                onTap: () => _open(context, const ThematicMushafPage()),
              ),
              _ActionCard(
                icon: Icons.history,
                title: 'متابعة الحفظ',
                subtitle: store.records.isEmpty
                    ? 'لم تبدأ مقطعًا بعد'
                    : 'لديك ${store.records.length} مقاطع محفوظة محليًا',
                onTap: () => _open(context, const ReviewPage()),
              ),
              _ActionCard(
                icon: Icons.replay_circle_filled_outlined,
                title: 'مراجعة اليوم',
                subtitle: '$due عناصر مستحقة الآن',
                onTap: () => _open(context, const ReviewPage()),
              ),
              _ActionCard(
                icon: Icons.auto_stories_outlined,
                title: 'المصحف الموضوعي',
                subtitle: 'ربط الآيات بوحدات المعنى دون تغيير النص',
                onTap: () => _open(context, const ThematicMushafPage()),
              ),
              _ActionCard(
                icon: Icons.quiz_outlined,
                title: 'الاختبارات',
                subtitle: 'الآية التالية والفراغات والتقييم الذاتي',
                onTap: () => _open(context, const LearningTestsPage()),
              ),
              _ActionCard(
                icon: Icons.calendar_month_outlined,
                title: 'خطة الحفظ',
                subtitle: store.plan == null
                    ? 'أنشئ هدفك اليومي'
                    : '${store.plan!.ayahsPerDay} آيات يوميًا',
                onTap: () => _open(context, const MemorizationPlanPage()),
              ),
              _ActionCard(
                icon: Icons.self_improvement_outlined,
                title: 'الأذكار',
                subtitle: 'أذكار موثقة وعداد يومي يعمل دون إنترنت',
                onTap: () => _open(context, const AdhkarPage()),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.records, required this.due});
  final List<MemorizationRecord> records;
  final int due;

  @override
  Widget build(BuildContext context) {
    final mastered = records
        .where((value) => value.status == MemorizationStatus.mastered)
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            CircleAvatar(radius: 28, child: Text('$mastered')),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'تقدمك محفوظ على هذا الجهاز',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text('${records.length} مقاطع • $due للمراجعة اليوم'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      minVerticalPadding: 14,
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_left),
      onTap: onTap,
    ),
  );
}

class ThematicMushafPage extends ConsumerStatefulWidget {
  const ThematicMushafPage({super.key});

  @override
  ConsumerState<ThematicMushafPage> createState() => _ThematicMushafPageState();
}

class _ThematicMushafPageState extends ConsumerState<ThematicMushafPage> {
  late Future<EducationalContent> _content;
  int _index = 0;
  bool _showDivision = true;
  bool _showTitles = true;

  @override
  void initState() {
    super.initState();
    _content = EducationalContent.load();
  }

  Color _segmentColor(BuildContext context, String token) {
    final scheme = Theme.of(context).colorScheme;
    final base = switch (token) {
      'gold' => const Color(0xffd8b64c),
      'sage' => const Color(0xff71977f),
      'blue' => const Color(0xff698fa3),
      _ => scheme.primary,
    };
    return Color.alphaBlend(base.withValues(alpha: 0.12), scheme.surface);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المصحف الموضوعي')),
    body: FutureBuilder<EducationalContent>(
      future: _content,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final segments = snapshot.data!.segments;
        final segment = segments[_index];
        final passage = ref
            .read(servicesProvider)
            .repository
            .quranPassage(QuranBrowseMode.surah, segment.surah);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            SwitchListTile(
              value: _showDivision,
              onChanged: (value) => setState(() => _showDivision = value),
              title: const Text('إظهار التقسيم الموضوعي'),
            ),
            SwitchListTile(
              value: _showTitles,
              onChanged: _showDivision
                  ? (value) => setState(() => _showTitles = value)
                  : null,
              title: const Text('إظهار أسماء الموضوعات'),
            ),
            const SizedBox(height: 8),
            if (_showTitles)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  segment.topicTitleAr,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                subtitle: Text(
                  '${segment.startAyah}-${segment.endAyah} • ${segment.topicSummaryAr}\n${segment.source}',
                ),
              ),
            FutureBuilder<QuranPassage>(
              future: passage,
              builder: (context, versesSnapshot) {
                if (!versesSnapshot.hasData)
                  return const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  );
                final verses = versesSnapshot.data!.verses
                    .where(
                      (verse) =>
                          verse.ayahNumber >= segment.startAyah &&
                          verse.ayahNumber <= segment.endAyah,
                    )
                    .toList();
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _showDivision
                        ? _segmentColor(context, segment.colorToken)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: BorderDirectional(
                      start: BorderSide(
                        color: _showDivision
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 4,
                      ),
                    ),
                  ),
                  child: Text(
                    verses
                        .map(
                          (verse) =>
                              '${verse.textUthmani} ﴿${verse.ayahNumber}﴾',
                        )
                        .join(' '),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.justify,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      height: 2.1,
                      fontFamily: 'serif',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            MemorizationSessionPage(segment: segment),
                      ),
                    ),
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('احفظ هذا المقطع'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref
                          .read(servicesProvider)
                          .learning
                          .setLearning(segment.id);
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('أضيف إلى المراجعة')),
                        );
                    },
                    icon: const Icon(Icons.add_task),
                    label: const Text('أضف للمراجعة'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                IconButton.filledTonal(
                  onPressed: _index > 0 ? () => setState(() => _index--) : null,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'المقطع السابق',
                ),
                Text('${_index + 1} / ${segments.length}'),
                IconButton.filledTonal(
                  onPressed: _index + 1 < segments.length
                      ? () => setState(() => _index++)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'المقطع التالي',
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

class MemorizationSessionPage extends ConsumerStatefulWidget {
  const MemorizationSessionPage({required this.segment, super.key});
  final ThematicSegment segment;

  @override
  ConsumerState<MemorizationSessionPage> createState() =>
      _MemorizationSessionPageState();
}

class _MemorizationSessionPageState
    extends ConsumerState<MemorizationSessionPage> {
  MemorizationUnit _unit = MemorizationUnit.thematicSegment;
  MemorizationMode _mode = MemorizationMode.listenAndRead;
  int _repetitions = 3;
  int _segmentRepetitions = 1;
  int _pauseSeconds = 2;
  bool _autoNext = true;
  bool _busy = false;
  int _hideLevel = 1;
  StreamSubscription<dynamic>? _mediaSubscription;
  bool _seenFirstMedia = false;
  int _pauseGeneration = 0;

  @override
  void dispose() {
    _pauseGeneration++;
    unawaited(_mediaSubscription?.cancel());
    super.dispose();
  }

  Future<void> _pauseBetweenItems() async {
    final generation = ++_pauseGeneration;
    final playback = ref.read(servicesProvider).playback;
    await playback.pause();
    await Future<void>.delayed(Duration(seconds: _pauseSeconds));
    if (mounted && generation == _pauseGeneration) await playback.play();
  }

  Future<List<QuranVerse>> _verses() async {
    final passage = await ref
        .read(servicesProvider)
        .repository
        .quranPassage(QuranBrowseMode.surah, widget.segment.surah);
    return passage.verses
        .where(
          (verse) =>
              verse.ayahNumber >= widget.segment.startAyah &&
              verse.ayahNumber <= widget.segment.endAyah,
        )
        .toList();
  }

  Future<void> _play(List<QuranVerse> verses) async {
    if (_busy || verses.isEmpty) return;
    setState(() => _busy = true);
    try {
      final services = ref.read(servicesProvider);
      final surahs = await services.repository.surahs();
      final surah = surahs.firstWhere(
        (value) => value.number == widget.segment.surah,
      );
      final reciters = await services.quranAudio.reciters(
        surahNumber: surah.number,
      );
      final reciter = reciters.firstWhere((value) => value.supportsAyahAudio);
      final resolved = <QuranAudioMedia>[];
      final selected = _unit == MemorizationUnit.ayah || !_autoNext
          ? <QuranVerse>[verses.first]
          : verses;
      for (var round = 0; round < _segmentRepetitions; round++) {
        for (final verse in selected) {
          final media = await services.quranAudio.resolve(
            QuranAudioRequest(
              surah: surah,
              reciter: reciter,
              ayahGlobalNumber: verse.globalNumber,
              ayahInSurah: verse.ayahNumber,
            ),
          );
          for (var repeat = 0; repeat < _repetitions; repeat++)
            resolved.add(media);
        }
      }
      await _mediaSubscription?.cancel();
      _seenFirstMedia = false;
      if (_pauseSeconds > 0 && resolved.length > 1) {
        _mediaSubscription = services.playback.mediaItemStream.listen((_) {
          if (!_seenFirstMedia) {
            _seenFirstMedia = true;
            return;
          }
          unawaited(_pauseBetweenItems());
        });
      }
      await services.playback.playQuranAudio(resolved, 0);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تجهيز صوت المقطع حاليًا')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _displayText(String text) {
    if (_mode == MemorizationMode.blanks) return presentationBlank(text);
    if (_mode == MemorizationMode.gradualHide) {
      return presentationBlank(
        text,
        stride: (5 - _hideLevel).clamp(2, 4).toInt(),
      );
    }
    return text;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.segment.topicTitleAr)),
    body: FutureBuilder<List<QuranVerse>>(
      future: _verses(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final verses = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            DropdownButtonFormField<MemorizationUnit>(
              initialValue: _unit,
              decoration: const InputDecoration(labelText: 'وحدة الحفظ'),
              items: MemorizationUnit.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _unit = value!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MemorizationMode>(
              initialValue: _mode,
              decoration: const InputDecoration(labelText: 'طريقة الحفظ'),
              items: MemorizationMode.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _mode = value!),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: <int>[1, 3, 5, 10]
                  .map(
                    (value) => ChoiceChip(
                      label: Text('$value'),
                      selected: _repetitions == value,
                      onSelected: (_) => setState(() => _repetitions = value),
                    ),
                  )
                  .toList(),
            ),
            Row(
              children: <Widget>[
                const Expanded(child: Text('تكرار المقطع كاملًا')),
                DropdownButton<int>(
                  value: _segmentRepetitions,
                  items: <int>[1, 2, 3, 5]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _segmentRepetitions = value!),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                const Expanded(child: Text('مهلة الترديد')),
                DropdownButton<int>(
                  value: _pauseSeconds,
                  items: <int>[0, 2, 5, 10]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value ث'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _pauseSeconds = value!),
                ),
              ],
            ),
            SwitchListTile(
              value: _autoNext,
              onChanged: (value) => setState(() => _autoNext = value),
              title: const Text('تشغيل الآية التالية تلقائيًا'),
            ),
            if (_mode == MemorizationMode.gradualHide)
              Slider(
                value: _hideLevel.toDouble(),
                min: 1,
                max: 3,
                divisions: 2,
                label: 'مستوى الإخفاء $_hideLevel',
                onChanged: (value) =>
                    setState(() => _hideLevel = value.round()),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  verses
                      .map(
                        (verse) =>
                            '${_displayText(verse.textUthmani)} ﴿${verse.ayahNumber}﴾',
                      )
                      .join('\n'),
                  textDirection: TextDirection.rtl,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(height: 2),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : () => _play(verses),
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: const Text('ابدأ التكرار'),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ReviewOutcome>(
              segments: const <ButtonSegment<ReviewOutcome>>[
                ButtonSegment(
                  value: ReviewOutcome.correct,
                  label: Text('أجبت صحيح'),
                ),
                ButtonSegment(
                  value: ReviewOutcome.helped,
                  label: Text('احتجت مساعدة'),
                ),
                ButtonSegment(
                  value: ReviewOutcome.incorrect,
                  label: Text('أخطأت'),
                ),
              ],
              emptySelectionAllowed: true,
              selected: const <ReviewOutcome>{},
              onSelectionChanged: (value) async {
                await ref
                    .read(servicesProvider)
                    .learning
                    .recordReview(widget.segment.id, value.first);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        );
      },
    ),
  );
}

class ReviewPage extends ConsumerWidget {
  const ReviewPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(servicesProvider).learning;
    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة اليوم')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final due = store.dueReviews(DateTime.now());
          if (due.isEmpty)
            return const Center(child: Text('لا توجد مراجعات مستحقة الآن'));
          return FutureBuilder<EducationalContent>(
            future: EducationalContent.load(),
            builder: (context, snapshot) {
              final segments =
                  snapshot.data?.segments ?? const <ThematicSegment>[];
              return ListView.builder(
                itemCount: due.length,
                itemBuilder: (context, index) {
                  final record = due[index];
                  final matches = segments.where(
                    (value) => value.id == record.key,
                  );
                  final segment = matches.isEmpty ? null : matches.first;
                  return Card(
                    child: ListTile(
                      title: Text(segment?.topicTitleAr ?? record.key),
                      subtitle: Text(
                        '${record.status.label} • أخطاء ${record.errors}',
                      ),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: segment == null
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    MemorizationSessionPage(segment: segment),
                              ),
                            ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class MemorizationPlanPage extends ConsumerStatefulWidget {
  const MemorizationPlanPage({super.key});
  @override
  ConsumerState<MemorizationPlanPage> createState() =>
      _MemorizationPlanPageState();
}

class _MemorizationPlanPageState extends ConsumerState<MemorizationPlanPage> {
  int _ayahs = 5;
  int _pages = 0;
  int _segments = 0;
  int _from = 1;
  int _to = 114;
  final Set<int> _days = <int>{1, 2, 3, 4, 5};
  DateTime _startDate = DateTime.now();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('خطة الحفظ')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        TextFormField(
          initialValue: '$_ayahs',
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'عدد الآيات يوميًا'),
          onChanged: (value) => _ayahs = int.tryParse(value) ?? 5,
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: '$_pages',
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'عدد الصفحات يوميًا (اختياري)',
          ),
          onChanged: (value) => _pages = int.tryParse(value) ?? 0,
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: '$_segments',
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'عدد المقاطع الموضوعية يوميًا (اختياري)',
          ),
          onChanged: (value) => _segments = int.tryParse(value) ?? 0,
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                initialValue: '$_from',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'من سورة'),
                onChanged: (value) => _from = int.tryParse(value) ?? 1,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: '$_to',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'إلى سورة'),
                onChanged: (value) => _to = int.tryParse(value) ?? 114,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('تاريخ البداية'),
          subtitle: Text(
            '${_startDate.year}/${_startDate.month}/${_startDate.day}',
          ),
          trailing: const Icon(Icons.date_range_outlined),
          onTap: () async {
            final value = await showDatePicker(
              context: context,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDate: _startDate,
            );
            if (value != null) setState(() => _startDate = value);
          },
        ),
        const Text('أيام الدراسة'),
        Wrap(
          spacing: 6,
          children: List<Widget>.generate(7, (index) {
            final day = index + 1;
            return FilterChip(
              label: Text(
                const <String>[
                  'اثنين',
                  'ثلاثاء',
                  'أربعاء',
                  'خميس',
                  'جمعة',
                  'سبت',
                  'أحد',
                ][index],
              ),
              selected: _days.contains(day),
              onSelected: (value) =>
                  setState(() => value ? _days.add(day) : _days.remove(day)),
            );
          }),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () async {
            await ref
                .read(servicesProvider)
                .learning
                .savePlan(
                  MemorizationPlan(
                    ayahsPerDay: _ayahs.clamp(1, 100).toInt(),
                    pagesPerDay: _pages.clamp(0, 20).toInt(),
                    thematicSegmentsPerDay: _segments.clamp(0, 20).toInt(),
                    fromSurah: _from.clamp(1, 114).toInt(),
                    toSurah: _to.clamp(1, 114).toInt(),
                    startDate: _startDate,
                    studyWeekdays: _days,
                  ),
                );
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('حفظ الخطة'),
        ),
      ],
    ),
  );
}

class LearningTestsPage extends ConsumerStatefulWidget {
  const LearningTestsPage({super.key});
  @override
  ConsumerState<LearningTestsPage> createState() => _LearningTestsPageState();
}

class _LearningTestsPageState extends ConsumerState<LearningTestsPage> {
  bool _revealed = false;
  bool _blanks = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('اختبارات الحفظ')),
    body: FutureBuilder<QuranPassage>(
      future: ref
          .read(servicesProvider)
          .repository
          .quranPassage(QuranBrowseMode.surah, 1),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final verses = snapshot.data!.verses;
        final current = verses.first;
        final answer = nextItem(verses, current);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              'ما الآية التالية؟',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  _blanks
                      ? presentationBlank(current.textUthmani)
                      : current.textUthmani,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(height: 2),
                ),
              ),
            ),
            CheckboxListTile(
              value: _blanks,
              onChanged: (value) => setState(() => _blanks = value ?? false),
              title: const Text('اختبار الفراغات'),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _revealed = !_revealed),
              icon: Icon(_revealed ? Icons.visibility_off : Icons.visibility),
              label: Text(_revealed ? 'إخفاء الإجابة' : 'إظهار الآية التالية'),
            ),
            if (_revealed && answer != null)
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    answer.textUthmani,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(height: 2),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SegmentedButton<ReviewOutcome>(
              segments: const <ButtonSegment<ReviewOutcome>>[
                ButtonSegment(
                  value: ReviewOutcome.correct,
                  label: Text('أجبت صحيح'),
                ),
                ButtonSegment(
                  value: ReviewOutcome.helped,
                  label: Text('احتجت مساعدة'),
                ),
                ButtonSegment(
                  value: ReviewOutcome.incorrect,
                  label: Text('أخطأت'),
                ),
              ],
              emptySelectionAllowed: true,
              selected: const <ReviewOutcome>{},
              onSelectionChanged: (value) async {
                await ref
                    .read(servicesProvider)
                    .learning
                    .recordReview('1:1-2', value.first);
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حفظ نتيجة المراجعة محليًا'),
                    ),
                  );
              },
            ),
          ],
        );
      },
    ),
  );
}

class AdhkarPage extends ConsumerStatefulWidget {
  const AdhkarPage({super.key});
  @override
  ConsumerState<AdhkarPage> createState() => _AdhkarPageState();
}

class _AdhkarPageState extends ConsumerState<AdhkarPage> {
  late Future<EducationalContent> _content;
  String _category = 'morning';
  int _index = 0;
  static const labels = <String, String>{
    'morning': 'أذكار الصباح',
    'evening': 'أذكار المساء',
    'after_prayer': 'بعد الصلاة',
    'sleep': 'النوم',
    'waking': 'الاستيقاظ',
    'general': 'أذكار عامة',
  };
  @override
  void initState() {
    super.initState();
    _content = EducationalContent.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الأذكار')),
    body: FutureBuilder<EducationalContent>(
      future: _content,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final all = snapshot.data!.adhkar;
        final items = all
            .where((value) => value.category == _category)
            .toList();
        final item = items[_index.clamp(0, items.length - 1).toInt()];
        final store = ref.watch(servicesProvider).learning;
        return AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            final current = store.adhkarCount(item.id);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'القسم'),
                  items: labels.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _category = value!;
                    _index = 0;
                  }),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: store.adhkarProgress(items)),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: <Widget>[
                        Text(
                          item.text,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(height: 1.8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${item.source} • ${item.reference} • ${item.authenticity}',
                        ),
                        const SizedBox(height: 20),
                        FilledButton.tonal(
                          onPressed: current >= item.count
                              ? null
                              : () => store.incrementAdhkar(item),
                          child: Text(
                            '$current / ${item.count}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => store.resetAdhkar(item.id),
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة العداد'),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    IconButton.filledTonal(
                      onPressed: _index > 0
                          ? () => setState(() => _index--)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'السابق',
                    ),
                    IconButton.filledTonal(
                      onPressed: _index + 1 < items.length
                          ? () => setState(() => _index++)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'التالي',
                    ),
                  ],
                ),
                if (const <String>{
                  'morning',
                  'evening',
                  'sleep',
                }.contains(_category))
                  SwitchListTile(
                    value: store.reminderEnabled(_category),
                    title: const Text('تذكير محلي'),
                    subtitle: const Text(
                      'يعمل فقط عند سماح Android بالإشعارات',
                    ),
                    onChanged: (enabled) async {
                      final controller = ref
                          .read(servicesProvider)
                          .adhkarReminders;
                      var applied = true;
                      if (enabled) {
                        applied = await controller.schedule(
                          _category,
                          hour: _category == 'morning'
                              ? 6
                              : _category == 'evening'
                              ? 18
                              : 22,
                          minute: 0,
                        );
                      } else {
                        await controller.cancel(_category);
                      }
                      await store.setReminderEnabled(
                        _category,
                        enabled && applied,
                      );
                      if (!applied && context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('فعّل إذن الإشعارات أولًا'),
                          ),
                        );
                    },
                  ),
              ],
            );
          },
        );
      },
    ),
  );
}
