import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation.dart';
import '../reading_journey.dart';
import '../services.dart';
import '../theme.dart';
import 'learning.dart';
import 'reading_annotations.dart';

class ReadingJourneyPage extends ConsumerWidget {
  const ReadingJourneyPage({super.key});

  Future<void> _editGoal(
    BuildContext context,
    ReadingJourneyStore journey,
  ) async {
    final goal = await showDialog<int>(
      context: context,
      builder: (_) => _DailyGoalDialog(initialGoal: journey.dailyGoal),
    );
    if (goal == null || !context.mounted) return;
    final saved = await journey.setDailyGoal(goal);
    if (!saved && context.mounted) {
      _showSaveError(context);
    }
  }

  void _showSaveError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر حفظ التقدم. حاول مرة أخرى.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final journey = services.mushaf.journey;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('رحلتي مع القرآن')),
      body: AnimatedBuilder(
        animation: journey,
        builder: (context, _) {
          final pagesToday = journey.pagesReadToday;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.all(TarteelTokens.spaceMd),
                children: [
                  Card(
                    color: scheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(TarteelTokens.spaceMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ورد اليوم',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: scheme.onPrimaryContainer),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$pagesToday من ${journey.dailyGoal} صفحة',
                            style: TextStyle(color: scheme.onPrimaryContainer),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: (pagesToday / journey.dailyGoal).clamp(
                              0.0,
                              1.0,
                            ),
                            semanticsLabel: 'تقدم ورد اليوم',
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () => _editGoal(context, journey),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('تعديل الهدف اليومي'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(TarteelTokens.spaceMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الختمة الحالية',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${journey.pagesRead} من ${ReadingJourneyStore.pageCount} صفحة',
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value:
                                journey.pagesRead /
                                ReadingJourneyStore.pageCount,
                            semanticsLabel: 'تقدم الختمة الحالية',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'الختمات المكتملة: ${journey.completedKhatmahs + (journey.khatmahComplete ? 1 : 0)}',
                          ),
                          const SizedBox(height: 12),
                          if (journey.khatmahComplete)
                            FilledButton.icon(
                              onPressed: () async {
                                final saved = await journey.startNextKhatmah();
                                if (!saved && context.mounted) {
                                  _showSaveError(context);
                                }
                              },
                              icon: const Icon(Icons.auto_stories_outlined),
                              label: const Text('ابدأ ختمة جديدة'),
                            )
                          else ...[
                            const Text(
                              'بعد قراءة صفحة، اختر «إتمام قراءة الصفحة» من خيارات المصحف.',
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                MobileRoutes.reader,
                                arguments: journey.firstUnreadPage,
                              ),
                              icon: const Icon(Icons.auto_stories_outlined),
                              label: const Text('افتح أول صفحة غير مكتملة'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.school_outlined),
                      title: const Text('الحفظ والمراجعة'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const LearningCenterPage(),
                        ),
                      ),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.bookmark_border),
                      title: const Text('العلامات المرجعية'),
                      onTap: () =>
                          Navigator.pushNamed(context, MobileRoutes.bookmarks),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.edit_note_outlined),
                      title: const Text('مواضعي وملاحظاتي'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ReadingAnnotationsPage(),
                        ),
                      ),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('سجل الاستماع'),
                      onTap: () =>
                          Navigator.pushNamed(context, MobileRoutes.history),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DailyGoalDialog extends StatefulWidget {
  const _DailyGoalDialog({required this.initialGoal});
  final int initialGoal;

  @override
  State<_DailyGoalDialog> createState() => _DailyGoalDialogState();
}

class _DailyGoalDialogState extends State<_DailyGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _goal = TextEditingController(text: '${widget.initialGoal}');

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(
    _goal.text.trim().replaceAllMapped(
      RegExp('[٠-٩۰-۹]'),
      (match) => ((match[0]!.codeUnitAt(0) & 0xf)).toString(),
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('الهدف اليومي'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _goal,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'عدد الصفحات'),
        validator: (_) {
          final goal = _value;
          return goal == null ||
                  goal < 1 ||
                  goal > ReadingJourneyStore.pageCount
              ? 'أدخل رقمًا من ١ إلى ٦٠٤'
              : null;
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) Navigator.pop(context, _value);
        },
        child: const Text('حفظ'),
      ),
    ],
  );
}
