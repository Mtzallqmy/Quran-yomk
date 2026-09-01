import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../islamic_content.dart';
import '../services.dart';

class IslamicLibraryPage extends ConsumerWidget {
  const IslamicLibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(servicesProvider).islamicContent;
    const sections = <_Dataset>[
      _Dataset('القرآن بالعربية', 'quran/chapters/ar/1.json', Icons.menu_book),
      _Dataset('English Quran', 'quran/chapters/en/1.json', Icons.translate),
      _Dataset(
        'أدعية القرآن',
        'quran/quran_duas.json',
        Icons.volunteer_activism,
      ),
      _Dataset('التفسير الميسر', 'tafseer/muyassar.json', Icons.auto_stories),
      _Dataset('صحيح البخاري', 'hadith/bukhari.json', Icons.library_books),
      _Dataset('صحيح مسلم', 'hadith/muslim.json', Icons.library_books),
      _Dataset('موطأ مالك', 'hadith/malik.json', Icons.library_books),
      _Dataset('مسند أحمد', 'hadith/ahmed.json', Icons.library_books),
      _Dataset('الأربعون النووية', 'forties/nawawi40.json', Icons.format_quote),
      _Dataset('الأحاديث القدسية', 'forties/qudsi40.json', Icons.format_quote),
      _Dataset(
        'أذكار الصباح',
        'azkar/azkar-sabah.json',
        Icons.wb_sunny_outlined,
      ),
      _Dataset(
        'أذكار المساء',
        'azkar/azkar-masaa.json',
        Icons.nights_stay_outlined,
      ),
      _Dataset(
        'الرقية الشرعية',
        'azkar/ruqyah-shariah.json',
        Icons.health_and_safety_outlined,
      ),
      _Dataset(
        'قصص الأنبياء واختباراتها',
        'prophet_stories/index.json',
        Icons.history_edu,
      ),
      _Dataset(
        'أسماء الله الحسنى',
        'names_of_allah/names_of_allah.json',
        Icons.star_outline,
      ),
      _Dataset(
        'المكتبة والكتب',
        'data/catalog.json',
        Icons.local_library_outlined,
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('المكتبة الإسلامية'),
        actions: <Widget>[
          IconButton(
            tooltip: 'إدارة المحتوى دون إنترنت',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _OfflineContentSheet(repository: repository),
            ),
            icon: const Icon(Icons.download_for_offline_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const <Widget>[
                  Text(
                    'Islamic Library Data — Open Source Islamic Dataset',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  SelectableText(islamicLibraryRepositoryUrl),
                  SizedBox(height: 6),
                  Text(
                    'تُقرأ النسخة المحلية الموثقة أولًا، ثم تُنزّل الملفات المطلوبة مباشرة من CDN وتصبح متاحة دون إنترنت.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final section in sections)
            Card(
              child: ListTile(
                leading: Icon(section.icon),
                title: Text(section.title),
                subtitle: const Text('تنزيل عند الطلب • حفظ محلي موثّق'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _IslamicDatasetPage(dataset: section),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IslamicDatasetPage extends ConsumerStatefulWidget {
  const _IslamicDatasetPage({required this.dataset});

  final _Dataset dataset;

  @override
  ConsumerState<_IslamicDatasetPage> createState() =>
      _IslamicDatasetPageState();
}

class _IslamicDatasetPageState extends ConsumerState<_IslamicDatasetPage> {
  late Future<dynamic> _future;

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(servicesProvider)
        .islamicContent
        .readJson(widget.dataset.path);
  }

  List<dynamic> _items(dynamic value) {
    if (value is List) return value;
    if (value is! Map) return <dynamic>[value];
    for (final key in const <String>[
      'verses',
      'hadiths',
      'books',
      'entries',
      'chapters',
      'names',
    ]) {
      final candidate = value[key];
      if (candidate is List) return candidate;
    }
    return <dynamic>[value];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.dataset.title)),
    body: FutureBuilder<dynamic>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('تعذر تحميل المحتوى: ${snapshot.error}'),
                TextButton(
                  onPressed: () => setState(() {
                    _future = ref
                        .read(servicesProvider)
                        .islamicContent
                        .readJson(widget.dataset.path, refresh: true);
                  }),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }
        final items = _items(snapshot.data);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 28),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final map = item is Map
                ? item
                : <dynamic, dynamic>{'text': '$item'};
            final title = _first(map, const <String>[
              'title_ar',
              'titleAr',
              'name',
              'name_ar',
              'arabic',
              'zekr',
              'text',
            ]);
            final body = _first(map, const <String>[
              'text_ar',
              'meaning_ar',
              'translation',
              'english',
              'bless',
              'summaryAr',
              'author_ar',
            ]);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SelectableText(
                      title.isEmpty ? 'العنصر ${index + 1}' : title,
                      textDirection: TextDirection.rtl,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (body.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      SelectableText(body, textDirection: TextDirection.rtl),
                    ],
                    if (map['repeat'] != null)
                      Text('التكرار: ${map['repeat']}'),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );

  String _first(Map<dynamic, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && '$value'.trim().isNotEmpty) return '$value';
    }
    return '';
  }
}

class _OfflineContentSheet extends StatefulWidget {
  const _OfflineContentSheet({required this.repository});

  final IslamicContentRepository repository;

  @override
  State<_OfflineContentSheet> createState() => _OfflineContentSheetState();
}

class _OfflineContentSheetState extends State<_OfflineContentSheet> {
  String _group = 'quran';
  bool _busy = false;

  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      await widget.repository.downloadOfflineGroup(_group);
    } catch (_) {
      // Concrete error is exposed by the repository progress object.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: AnimatedBuilder(
        animation: widget.repository,
        builder: (context, _) {
          final progress = widget.repository.progress;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'المحتوى دون إنترنت',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _group,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(
                    value: 'quran',
                    child: Text('القرآن والتفسير والتجويد'),
                  ),
                  DropdownMenuItem(
                    value: 'hadith',
                    child: Text('كتب الحديث الأساسية'),
                  ),
                  DropdownMenuItem(
                    value: 'azkar',
                    child: Text('الأذكار والأدعية'),
                  ),
                  DropdownMenuItem(
                    value: 'stories',
                    child: Text('قصص الأنبياء والاختبارات'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _group = value ?? _group),
              ),
              if (progress != null && progress.group == _group) ...<Widget>[
                const SizedBox(height: 14),
                LinearProgressIndicator(value: progress.fraction),
                Text(
                  '${progress.completed} / ${progress.total} • ${(progress.receivedBytes / 1048576).toStringAsFixed(1)} MB',
                ),
                if (progress.error != null)
                  Text(
                    'تعذر الاستكمال: ${progress.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _download,
                      icon: const Icon(Icons.download),
                      label: Text(_busy ? 'جارٍ التنزيل…' : 'تنزيل / استكمال'),
                    ),
                  ),
                  if (_busy)
                    IconButton(
                      tooltip: 'إيقاف مؤقت',
                      onPressed: widget.repository.pauseOfflineDownload,
                      icon: const Icon(Icons.pause),
                    ),
                  IconButton(
                    tooltip: 'حذف الحزمة',
                    onPressed: _busy
                        ? null
                        : () => widget.repository.deleteOfflineGroup(_group),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _Dataset {
  const _Dataset(this.title, this.path, this.icon);

  final String title;
  final String path;
  final IconData icon;
}
