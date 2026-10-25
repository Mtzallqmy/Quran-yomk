import 'package:flutter/material.dart';

import 'surah_api_client.dart';

/// Explicitly experimental, live-only viewer. Never persists third-party
/// content; publication requires a per-project rights review.
class SurahExperimentalSheet extends StatefulWidget {
  const SurahExperimentalSheet({
    super.key,
    required this.surahNumber,
    required this.ayahNumber,
  });

  final int surahNumber;
  final int ayahNumber;

  @override
  State<SurahExperimentalSheet> createState() => _SurahExperimentalSheetState();
}

class _SurahExperimentalSheetState extends State<SurahExperimentalSheet> {
  late final SurahApiClient _api;
  late Future<List<SurahProject>> _projects;
  Future<Object?>? _content;
  SurahProject? _selected;

  @override
  void initState() {
    super.initState();
    _api = SurahApiClient();
    _projects = _api.projects();
    _content = _api.aya('tafsir-mokhtasar', widget.surahNumber, widget.ayahNumber);
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  void _choose(SurahProject project) {
    setState(() {
      _selected = project;
      _content = _api.aya(
        project.slug,
        widget.surahNumber,
        widget.ayahNumber,
      );
    });
  }

  static String _humanText(Object? value, [int depth = 0]) {
    if (depth > 9 || value == null) return '';
    if (value is String) return value;
    if (value is List) {
      return value
          .map((item) => _humanText(item, depth + 1))
          .where((item) => item.isNotEmpty)
          .join('\n\n');
    }
    if (value is Map) {
      for (final field in const [
        'text',
        'text_ar',
        'content',
        'body',
        'tafsir',
        'value',
        'data',
      ]) {
        if (value.containsKey(field)) {
          final result = _humanText(value[field], depth + 1);
          if (result.isNotEmpty) return result;
        }
      }
      return '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.70,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('تفسير الآية — محتوى سورة',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'سورة — مركز تفسير للدراسات القرآنية\n'
              'بيانات تُعرض مباشرة من API، ولا تُحفظ أو تُوزع. '
              'المشروعات المتاحة وحقوق استخدامها تُراجع قبل الاعتماد.',
            ),
            const SizedBox(height: 12),
            Text('الآية ${widget.surahNumber}:${widget.ayahNumber}'),
            const SizedBox(height: 8),
            FutureBuilder<List<SurahProject>>(
              future: _projects,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Column(
                    children: [
                      const Text('تعذر الوصول إلى قائمة مشاريع سورة'),
                      TextButton(
                        onPressed: () => setState(() {
                          _projects = _api.projects();
                          _selected = null;
                          _content = null;
                        }),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  );
                }
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }
                final projects = snapshot.data!.where((p) => p.slug.startsWith('tafsir-')).toList();
                if (projects.isEmpty) {
                  return const Text('لم تُكتشف مشاريع متاحة حاليًا');
                }
                return DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selected?.slug,
                  decoration: const InputDecoration(
                    labelText: 'اختر مشروعًا موجودًا على API',
                  ),
                  items: [
                    for (final project in projects)
                      DropdownMenuItem(
                        value: project.slug,
                        child: Text(project.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (slug) {
                    if (slug == null) return;
                    for (final project in projects) {
                      if (project.slug == slug) {
                        _choose(project);
                        break;
                      }
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _content == null
                  ? const Center(
                      child: Text('اختر تفسيرًا أو أعد الاتصال'))
                  : FutureBuilder<Object?>(
                      future: _content,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                            child: Text(
                              'هذا المشروع لا يتيح محتوى الآية أو تعذر جلبه',
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final text = _humanText(snapshot.data);
                        return SingleChildScrollView(
                          child: SelectableText(
                            text.isEmpty
                                ? 'المحتوى غير متاح بهذا الشكل من المصدر'
                                : text,
                            textDirection: TextDirection.rtl,
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 4),
            const Text('المصدر: https://surahapp.com/'),
          ],
        ),
      ),
    ),
  );
}
