import 'package:flutter/material.dart';
import 'mushaf_store.dart';

class ContinueReadingCard extends StatelessWidget {
  const ContinueReadingCard({
    super.key,
    required this.position,
    required this.onOpen,
  });
  final MushafPosition? position;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final last = position;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'وردك من القرآن',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (last == null)
              const Text('ابدأ القراءة واحفظ موضعك للعودة إليه.')
            else ...[
              if (last.surahNameAr != null || last.surahNumber != null)
                Text(last.surahNameAr ?? 'السورة ${last.surahNumber}'),
              Text(
                [
                  if (last.pageNumber != null) 'الصفحة ${last.pageNumber}',
                  if (last.ayahNumber != null) 'الآية ${last.ayahNumber}',
                  if (last.juzNumber != null) 'الجزء ${last.juzNumber}',
                ].join(' • '),
              ),
              if (last.readAt != null)
                Text(
                  'آخر قراءة: ${last.readAt!.toLocal().day}/${last.readAt!.toLocal().month}/${last.readAt!.toLocal().year}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.menu_book),
              onPressed: onOpen,
              label: Text(last == null ? 'افتح المصحف' : 'متابعة القراءة'),
            ),
          ],
        ),
      ),
    );
  }
}
