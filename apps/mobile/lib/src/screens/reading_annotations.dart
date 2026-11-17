import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../canonical_quran.dart';
import '../navigation.dart';
import '../quran_models.dart';
import '../reading_annotations.dart';
import '../services.dart';

class AyahAnnotationTile extends StatelessWidget {
  const AyahAnnotationTile({
    super.key,
    required this.verse,
    required this.annotations,
  });
  final QuranVerse verse;
  final ReadingAnnotations annotations;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: annotations,
    builder: (context, _) {
      final current = annotations[verse.canonicalId];
      return ListTile(
        leading: const Icon(Icons.edit_note_outlined),
        title: Text(
          current == null
              ? 'أضف ملاحظة أو اسمًا للموضع'
              : 'تعديل الملاحظة والموضع',
        ),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _AnnotationDialog(
            annotations: annotations,
            verse: verse,
            initial: current,
          ),
        ),
      );
    },
  );
}

class ReadingAnnotationsPage extends ConsumerStatefulWidget {
  const ReadingAnnotationsPage({super.key});

  @override
  ConsumerState<ReadingAnnotationsPage> createState() =>
      _ReadingAnnotationsPageState();
}

class _ReadingAnnotationsPageState
    extends ConsumerState<ReadingAnnotationsPage> {
  Future<TarteelCanonicalQuran> _quran = TarteelCanonicalQuran.load();

  @override
  Widget build(BuildContext context) {
    final annotations = ref.watch(servicesProvider).mushaf.annotations;
    return Scaffold(
      appBar: AppBar(title: const Text('مواضعي وملاحظاتي')),
      body: FutureBuilder<TarteelCanonicalQuran>(
        future: _quran,
        builder: (context, snapshot) {
          final quran = snapshot.data;
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: () =>
                    setState(() => _quran = TarteelCanonicalQuran.load()),
                child: const Text('تعذر فتح المواضع. أعد المحاولة'),
              ),
            );
          }
          if (quran == null)
            return const Center(child: CircularProgressIndicator());
          return ListenableBuilder(
            listenable: annotations,
            builder: (context, _) {
              final records = annotations.records;
              final verses = records.keys.map(quran.ayah).nonNulls.toList()
                ..sort((a, b) => a.globalNumber.compareTo(b.globalNumber));
              if (verses.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'اختر آية في المصحف لإضافة ملاحظة أو تسمية موضع.',
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: verses.length,
                itemBuilder: (context, index) {
                  final verse = verses[index];
                  final record = records[verse.canonicalId]!;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.bookmark_outline),
                      title: Text(
                        record.title.isEmpty ? verse.surahNameAr : record.title,
                      ),
                      subtitle: Text(
                        'سورة ${verse.surahNameAr} · الآية ${verse.ayahNumber}'
                        '${record.note.isEmpty ? '' : '\\n${record.note}'}',
                      ),
                      onTap: () => Navigator.pushNamed(
                        context,
                        MobileRoutes.reader,
                        arguments: ReaderTarget(
                          page: verse.pageNumber,
                          verseKey: verse.verseKey,
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'تعديل الملاحظة',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => _AnnotationDialog(
                            annotations: annotations,
                            verse: verse,
                            initial: record,
                          ),
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

class _AnnotationDialog extends StatefulWidget {
  const _AnnotationDialog({
    required this.annotations,
    required this.verse,
    this.initial,
  });
  final ReadingAnnotations annotations;
  final QuranVerse verse;
  final ReadingAnnotation? initial;

  @override
  State<_AnnotationDialog> createState() => _AnnotationDialogState();
}

class _AnnotationDialogState extends State<_AnnotationDialog> {
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _note = TextEditingController(text: widget.initial?.note);
  bool _saving = false;
  bool _failed = false;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(ReadingAnnotation? value) async {
    setState(() => _saving = true);
    final ok = await widget.annotations.save(widget.verse.canonicalId, value);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(
      'سورة ${widget.verse.surahNameAr} · الآية ${widget.verse.ayahNumber}',
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _title,
          enabled: !_saving,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'اسم الموضع'),
        ),
        TextField(
          controller: _note,
          enabled: !_saving,
          maxLength: 1000,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'ملاحظة شخصية'),
        ),
        if (_failed) const Text('تعذر حفظ الملاحظة. حاول مرة أخرى.'),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      if (widget.initial != null)
        TextButton(
          onPressed: _saving ? null : () => _save(null),
          child: const Text('حذف'),
        ),
      FilledButton(
        onPressed: _saving
            ? null
            : () => _save(
                ReadingAnnotation(
                  title: _title.text.trim(),
                  note: _note.text.trim(),
                ),
              ),
        child: const Text('حفظ'),
      ),
    ],
  );
}
