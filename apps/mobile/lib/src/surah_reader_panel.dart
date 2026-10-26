import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'surah_content.dart';
import 'mushaf_store.dart';
import 'content_catalog.dart';

final surahContentProvider = Provider<SurahApiClient>((ref) {
  final registry = ContentCatalogApi();
  final api = SurahApiClient(projectCatalog: registry.surahProjects);
  ref.onDispose(registry.dispose);
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
  late Future<List<SurahProject>> _projects;
  @override
  void initState() {
    super.initState();
    _projects = ref.read(surahContentProvider).projects();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<SurahProject>>(
    future: _projects,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: const Text('تعذر تحميل فهرس المحتوى'),
          subtitle: const Text('تبقى القراءة والتلاوة متاحة.'),
          trailing: IconButton(
            tooltip: 'إعادة المحاولة',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {
              _projects = ref.read(surahContentProvider).projects();
            }),
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
      final words = projects
          .where((p) => p.scope == SurahScope.word && p.slug != 'word-pic')
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (tafsirs.isNotEmpty)
            _SurahReadingSection(
              key: const ValueKey('surah-tafsir'),
              api: api,
              projects: tafsirs,
              location: [widget.surah, widget.ayah],
              title: 'اختيار التفسير',
              initiallyOpen: true,
              preferred:
                  widget.preferences?.educationProject ?? 'tafsir-mokhtasar',
              onProjectChanged: widget.preferences?.setEducationProject,
            ),
          if (words.isNotEmpty)
            _SurahReadingSection(
              key: const ValueKey('surah-words'),
              api: api,
              projects: words,
              location: [widget.surah, widget.ayah],
              title: 'الكلمات والإعراب',
              preferred: 'eerab-word',
              words: true,
            ),
          for (final project in projects.where(
            (p) => p.scope != SurahScope.word && !tafsirs.contains(p),
          ))
            _SurahReadingSection(
              key: ValueKey(project.slug),
              api: api,
              projects: [project],
              title: project.slug == 'fawaed-page'
                  ? 'فوائد الصفحة'
                  : project.title,
              location: switch (project.scope) {
                SurahScope.sura => [widget.surah],
                SurahScope.page => [widget.page],
                _ => [widget.surah, widget.ayah],
              },
            ),
        ],
      );
    },
  );
}

/// A section keeps project-specific word numbers and discards the previous
/// location's future before displaying new content. No permanent content cache.
class _SurahReadingSection extends StatefulWidget {
  const _SurahReadingSection({
    super.key,
    required this.api,
    required this.projects,
    required this.location,
    required this.title,
    this.preferred,
    this.initiallyOpen = false,
    this.words = false,
    this.onProjectChanged,
  });
  final SurahApiClient api;
  final List<SurahProject> projects;
  final List<int> location;
  final String title;
  final String? preferred;
  final bool initiallyOpen, words;
  final ValueChanged<String>? onProjectChanged;
  @override
  State<_SurahReadingSection> createState() => _SurahReadingSectionState();
}

class _SurahReadingSectionState extends State<_SurahReadingSection> {
  late String _project;
  late bool _open;
  int _start = 1;
  SurahContentEntry? _word;
  Future<List<SurahContentEntry>>? _future;
  @override
  void initState() {
    super.initState();
    _project =
        widget.projects
            .where((p) => p.slug == widget.preferred)
            .firstOrNull
            ?.slug ??
        widget.projects.first.slug;
    _open = widget.initiallyOpen;
    if (_open) _load();
  }

  void _load({bool refresh = false}) {
    _word = null;
    _future = widget.api.read(
      _project,
      [...widget.location, if (widget.words) _start],
      end: widget.words ? math.min(_start + 31, 200) : null,
      refresh: refresh,
    );
  }

  @override
  void didUpdateWidget(covariant _SurahReadingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.join(':') != widget.location.join(':') ||
        oldWidget.api != widget.api) {
      _start = 1;
      _word = null;
      _future = null;
      if (_open) _load();
    }
  }

  Widget _content() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.projects.length > 1 || widget.words || widget.initiallyOpen)
        DropdownButtonFormField<String>(
          key: widget.words
              ? const ValueKey('surah-word-project')
              : ValueKey('project-$_project'),
          initialValue: _project,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: widget.words ? 'مصدر الكلمات' : widget.title,
          ),
          items: [
            for (final p in widget.projects)
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
            if (value == null) return;
            setState(() {
              _project = value;
              _start = 1;
              _load();
            });
            widget.onProjectChanged?.call(value);
          },
        ),
      if (_future != null)
        FutureBuilder<List<SurahContentEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              );
            if (snapshot.hasError)
              return Column(
                children: [
                  const Text('تعذر جلب المحتوى. تبقى القراءة والتلاوة متاحة.'),
                  TextButton.icon(
                    onPressed: () => setState(() => _load(refresh: true)),
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              );
            final entries = snapshot.data ?? const <SurahContentEntry>[];
            if (entries.isEmpty)
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Text('لا يتوفر محتوى لهذا الموضع في المصدر المختار.'),
              );
            if (widget.words)
              return Wrap(
                spacing: 8,
                children: [
                  for (final entry in entries)
                    ActionChip(
                      label: Text(
                        entry.word.isEmpty
                            ? 'الكلمة ${entry.wordNumber}'
                            : entry.word,
                      ),
                      onPressed: () => setState(() => _word = entry),
                    ),
                ],
              );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in entries)
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
        ),
      if (_word != null)
        SelectableText(_word!.text, textDirection: TextDirection.rtl),
      if (widget.words)
        Wrap(
          children: [
            TextButton(
              onPressed: _start <= 1
                  ? null
                  : () => setState(() {
                      _start -= 32;
                      _load();
                    }),
              child: const Text('الكلمات السابقة'),
            ),
            TextButton(
              onPressed: _start >= 193
                  ? null
                  : () => setState(() {
                      _start += 32;
                      _load();
                    }),
              child: const Text('الكلمات التالية'),
            ),
          ],
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => widget.initiallyOpen
      ? _content()
      : ExpansionTile(
          title: Text(widget.title),
          onExpansionChanged: (value) => setState(() {
            _open = value;
            if (value && _future == null) _load();
          }),
          children: [_content()],
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
