import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/repositories/quran_yutla_repository.dart';

class LearningScreen extends ConsumerWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(quranRepositoryProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مركز الحفظ والأذكار'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'خطط الحفظ والمراجعة'),
              Tab(text: 'الأذكار اليومية'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Memorization Plans
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: repo.memorizationPlans.length,
              itemBuilder: (ctx, i) {
                final plan = repo.memorizationPlans[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(plan.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E9E9E).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${plan.completedPercent}% مكتمل',
                                style: const TextStyle(color: Color(0xFF2E9E9E), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'الموضع الحالي: ${plan.targetSurah} (آية ${plan.currentVerse} من ${plan.targetVerse})',
                          style: const TextStyle(color: Color(0xFF5B677A), fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: plan.completedPercent / 100.0,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          color: const Color(0xFF2E9E9E),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              plan.dueReviewDays == 0 ? 'مستحقة للمراجعة اليوم' : 'المراجعة بعد ${plan.dueReviewDays} يوم',
                              style: TextStyle(
                                color: plan.dueReviewDays == 0 ? const Color(0xFFC77955) : const Color(0xFF5B677A),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF243B6B),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('بدء جلسة التسميع'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Daily Adhkar
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: repo.adhkarList.length,
              itemBuilder: (ctx, i) {
                final d = repo.adhkarList[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(d.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC77955).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${d.currentCount} / ${d.targetCount}',
                                style: const TextStyle(color: Color(0xFFC77955), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          d.text,
                          style: const TextStyle(fontSize: 15, height: 1.8, color: Color(0xFF141C2B)),
                          textAlign: TextAlign.justify,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'الفضل: ${d.reward}',
                          style: const TextStyle(color: Color(0xFF2E9E9E), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
