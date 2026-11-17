import 'package:flutter/material.dart';

import 'mushaf_store.dart';
import 'theme.dart';

class ContinueReadingCard extends StatelessWidget {
  const ContinueReadingCard({
    super.key,
    required this.position,
    required this.onOpen,
    this.highlighted = false,
  });
  final MushafPosition? position;
  final VoidCallback onOpen;
  final bool highlighted;
  @override
  Widget build(BuildContext context) {
    final last = position;
    final theme = Theme.of(context);
    final content = Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              highlighted ? 'أكمل وردك' : 'وردك من القرآن',
              style: highlighted
                  ? Theme.of(context).textTheme.titleLarge
                  : Theme.of(context).textTheme.titleMedium,
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
    if (!highlighted) return Card(child: content);
    final hero = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: TarteelTheme.ivory,
        onPrimary: TarteelTheme.deepGreen,
        onSurface: TarteelTheme.ivory,
      ),
      textTheme: theme.textTheme.apply(
        bodyColor: TarteelTheme.ivory,
        displayColor: TarteelTheme.ivory,
      ),
    );
    return Card(
      color: TarteelTheme.deepGreen,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TarteelTokens.radiusCardLarge),
      ),
      child: CustomPaint(
        painter: const IslamicGeometryPainter(color: Color(0x16F8F6F1)),
        child: Theme(
          data: hero,
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: TarteelTheme.ivory),
            child: content,
          ),
        ),
      ),
    );
  }
}
