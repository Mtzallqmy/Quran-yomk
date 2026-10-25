import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'surah_content.dart';
import 'mushaf_store.dart';

final surahContentProvider = Provider<SurahApiClient>((ref) {
  final api = SurahApiClient();
  ref.onDispose(api.close);
  return api;
});

class SurahReaderPanel extends ConsumerStatefulWidget {
  const SurahReaderPanel({
    super.key,
    required this.surah,
    required this.ayah,
    required this.page,
    this.preferences,
  });
  final int surah, ayah, page;
  final MushafStore? preferences;
  @override
  ConsumerState<SurahReaderPanel> createState() => _SurahReaderPanelState();
}

class _SurahReaderPanelState extends ConsumerState<SurahReaderPanel> {
  late final Future<List<SurahProject>> _projects;
  String? _tafsir;
  Future<List<SurahContentEntry>>? _reading;
  Future<List<SurahContentEntry>>? _words;
  Future<List<SurahContentEntry>>? _benefits;
  SurahContentEntry? _word;
  int _wordStart = 1;
  @override
  void initState() {
    super.initState();
    _projects = ref.read(surahContentProvider).projects();
  }

  Widget _entries(Future<List<SurahContentEntry>>? future) {
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<List<SurahContentEntry>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          );
        if (snapshot.hasError)
          return const Text(
            'تعذر جلب المحتوى. تحقق من الاتصال أو حاول لاحقًا. القراءة والتلاوة متاحتان.',
          );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in snapshot.data ?? <SurahContentEntry>[])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SelectableText(
                  entry.text,
                  textDirection: TextDirection.rtl,
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<SurahProject>>(
    future: _projects,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return const ListTile(
          leading: Icon(Icons.cloud_off_outlined),
          title: Text('المحتوى التعليمي يحتاج اتصالًا'),
          subtitle: Text(
            'تعذر الاتصال بمصدر التفسير. تبقى الآيات والتلاوة متاحة.',
          ),
        );
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final api = ref.read(surahContentProvider);
      final projects = snapshot.data!;
      final tafsirs = projects
          .where(
            (p) => p.scope == SurahScope.aya && p.slug.startsWith('tafsir-'),
          )
          .toList();
      if (_tafsir == null && tafsirs.isNotEmpty) {
        _tafsir =
            tafsirs
                .where(
                  (p) =>
                      p.slug ==
                      (widget.preferences?.educationProject ??
                          'tafsir-mokhtasar'),
                )
                .firstOrNull
                ?.slug ??
            tafsirs.first.slug;
        _reading = api.read(_tafsir!, [widget.surah, widget.ayah]);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (tafsirs.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _tafsir,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'اختيار التفسير'),
              items: [
                for (final p in tafsirs)
                  DropdownMenuItem(
                    value: p.slug,
                    child: Text(
                      p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null)
                  setState(() {
                    _tafsir = value;
                    widget.preferences?.setEducationProject(value);
                    _reading = api.read(value, [widget.surah, widget.ayah]);
                  });
              },
            ),
          _entries(_reading),
          ExpansionTile(
            title: const Text('الكلمات والإعراب'),
            onExpansionChanged: (open) {
              if (open &&
                  _words == null &&
                  projects.any((p) => p.slug == 'eerab-word'))
                setState(() {
                  _words = api.read('eerab-word', [
                    widget.surah,
                    widget.ayah,
                    _wordStart,
                  ], end: _wordStart + 31);
                });
            },
            children: [
              if (_words != null)
                FutureBuilder<List<SurahContentEntry>>(
                  future: _words,
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return const Text('الكلمات غير متاحة حاليًا لهذا الموضع');
                    if (!snapshot.hasData)
                      return const LinearProgressIndicator();
                    return Wrap(
                      spacing: 8,
                      children: [
                        for (final entry in snapshot.data!)
                          ActionChip(
                            label: Text(
                              entry.word.isEmpty
                                  ? 'الكلمة ${entry.wordNumber}'
                                  : entry.word,
                            ),
                            onPressed: () {
                              setState(() {
                                _word = entry;
                              });
                            },
                          ),
                      ],
                    );
                  },
                ),
              if (_word != null) SelectableText(_word!.text),
              if (_word != null)
                Wrap(
                  children: [
                    for (final slug in ['word-qeraat', 'word-tasreef'])
                      if (projects.any((p) => p.slug == slug))
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _reading = api.read(slug, [
                                widget.surah,
                                widget.ayah,
                                _word!.wordNumber!,
                              ]);
                            });
                          },
                          child: Text(
                            projects.firstWhere((p) => p.slug == slug).title,
                          ),
                        ),
                  ],
                ),
              TextButton(
                onPressed: _wordStart >= 161
                    ? null
                    : () {
                        setState(() {
                          _wordStart += 32;
                          _words = api.read('eerab-word', [
                            widget.surah,
                            widget.ayah,
                            _wordStart,
                          ], end: _wordStart + 31);
                          _word = null;
                        });
                      },
                child: const Text('الكلمات التالية'),
              ),
            ],
          ),
          if (projects.any((p) => p.slug == 'fawaed-page'))
            ExpansionTile(
              title: const Text('فوائد الصفحة'),
              onExpansionChanged: (open) {
                if (open && _benefits == null)
                  setState(() {
                    _benefits = api.read('fawaed-page', [widget.page]);
                  });
              },
              children: [_entries(_benefits)],
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'المحتوى التعليمي يُستدعى عند الطلب. التنزيل الدائم غير متاح حتى التحقق من حقوق كل مشروع.',
            ),
          ),
        ],
      );
    },
  );
}

class SurahContentSource extends ConsumerWidget {
  const SurahContentSource({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ExpansionTile(
    leading: const Icon(Icons.source_outlined),
    title: const Text(SurahRightsRegistry.attribution),
    subtitle: const Text('التفسير والإعراب والفوائد — استدعاء مباشر'),
    children: [
      const ListTile(
        title: SelectableText(SurahRightsRegistry.website),
        subtitle: SelectableText(SurahRightsRegistry.documentation),
      ),
      const ListTile(
        title: Text(
          'لا تُنسخ النصوص أو الصور إلى Neon أو التخزين الدائم لعدم تحقق تصريح إعادة التوزيع. النص القرآني الحالي ومحرك الصفحات مستقلان عن هذا المصدر.',
        ),
      ),
      FutureBuilder<List<SurahProject>>(
        future: ref.read(surahContentProvider).projects(),
        builder: (context, snapshot) => Column(
          children: [
            for (final p in snapshot.data ?? <SurahProject>[])
              ListTile(
                title: Text(p.title),
                subtitle: Text('${p.slug} • ${p.scope.name}'),
              ),
          ],
        ),
      ),
    ],
  );
}
