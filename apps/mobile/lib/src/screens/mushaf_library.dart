import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mushaf_library.dart';
import '../mushaf_pages.dart';
import '../mushaf_store.dart';
import '../navigation.dart';
import '../quran_models.dart';
import '../services.dart';
import '../content_catalog.dart';

class MushafLibraryPage extends ConsumerStatefulWidget {
  const MushafLibraryPage({super.key});
  @override
  ConsumerState<MushafLibraryPage> createState() => _MushafLibraryPageState();
}

class _MushafLibraryPageState extends ConsumerState<MushafLibraryPage> {
  late Future<Map<MushafPageEdition, bool>> _installed;
  bool _busy = false;
  Future<Map<String, dynamic>>? _cloudStatus;

  Future<Map<String, dynamic>> _checkCloud() async {
    final api = ContentCatalogApi();
    try {
      return await api.mushafLibrary();
    } finally {
      api.dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    _installed = _status();
    _cloudStatus = _checkCloud();
  }

  Future<Map<MushafPageEdition, bool>> _status() async {
    final repository = ref.read(servicesProvider).mushafPages;
    return {
      for (final edition in MushafPageEdition.values)
        edition: await repository.isOfflinePackAvailable(edition),
    };
  }

  Future<void> _read(MushafPageEdition edition) async {
    final store = ref.read(servicesProvider).mushaf;
    await store.backupBeforeLibraryUpgrade();
    await store.setPageEdition(edition.name);
    await store.setPresentation(MushafReaderPresentation.page);
    if (!mounted) return;
    await Navigator.pushNamed(
      context,
      MobileRoutes.reader,
      arguments: store.lastPosition?.pageNumber ?? 1,
    );
  }

  Future<void> _manage(MushafPageEdition edition, bool installed) async {
    final repository = ref.read(servicesProvider).mushafPages;
    if (installed) {
      final remove = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('حذف الصفحات المحملة؟'),
          content: const Text('تبقى العلامات المرجعية وآخر موضع قراءة محفوظة.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف الملفات'),
            ),
          ],
        ),
      );
      if (remove != true) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      if (installed) {
        await repository.removeOfflinePack(edition);
      } else {
        await repository.downloadOfflinePack(edition);
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر إكمال العملية. يمكن إعادة المحاولة واستئناف التنزيل.',
            ),
          ),
        );
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _installed = _status();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(servicesProvider).mushafPages;
    return Scaffold(
      appBar: AppBar(title: const Text('مكتبة المصاحف')),
      body: AnimatedBuilder(
        animation: repository,
        builder: (context, _) => FutureBuilder<Map<MushafPageEdition, bool>>(
          future: _installed,
          builder: (context, snapshot) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'قراءة واحدة، وطرق متعددة للتدبر',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'تستخدم الأنماط علامات القراءة نفسها. حزم الصفحات اختيارية، وفهرس الموضوعات متاح دون إنترنت.',
              ),
              if (_cloudStatus != null)
                FutureBuilder<Map<String, dynamic>>(
                  future: _cloudStatus,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'تعذر فهرس Neon مؤقتًا؛ القراءة عبر المصدر الحالي لا تزال متاحة.',
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(),
                      );
                    }
                    final editions = snapshot.data!['editions'] as List? ?? [];
                    final packages = snapshot.data!['packages'] as List? ?? [];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('فهرس المصاحف عبر Neon',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('المصاحف المعتمدة: ${editions.length} • حزم التنزيل الاختيارية: ${packages.length}'),
                            const Text(
                              'اختر قراءة المصحف الآن عبر الإنترنت دون تنزيل كامل، '
                              'أو نزّل الحزمة لاحقًا للعمل دون إنترنت. '
                              'تُحمّل الصفحة المطلوبة فقط أثناء القراءة.',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),
              for (final edition in MushafPageEdition.values)
                _LibraryCard(
                  title: edition.labelAr,
                  icon: edition == MushafPageEdition.madinahHafsSvg
                      ? Icons.auto_stories
                      : Icons.palette_outlined,
                  description: edition == MushafPageEdition.madinahHafsSvg
                      ? 'حفص عن عاصم • 604 صفحات • رسم مجمع الملك فهد، تحويل SVG مثبت الإصدار. لم تُثبت مطابقة طبعة 1440هـ.'
                      : 'حفص • صفحات QCF V4 الملونة الحالية. حقوق إعادة توزيع هذا المورد غير موضحة في QUL؛ تبقى النسخة الحالية متاحة ولا نعتمد حزمة جديدة أو شروحًا آلية.',
                  status: snapshot.data?[edition] == true
                      ? 'محفوظ دون إنترنت؛ يمكن القراءة فورًا'
                      : 'القراءة عبر الإنترنت دون تحميل المصحف كاملًا',
                  size: edition == MushafPageEdition.madinahHafsSvg
                      ? '121,620,792 بايت (~116 MiB)'
                      : '153,090,668 بايت (~146 MiB)',
                  onRead: () => _read(edition),
                  onManage: _busy || !snapshot.hasData
                      ? null
                      : () => _manage(edition, snapshot.data![edition]!),
                  manageLabel: edition == MushafPageEdition.madinahTajweedQcfV4
                      ? null
                      : snapshot.data?[edition] == true
                      ? 'إدارة الملفات'
                      : 'تنزيل كامل',
                ),
              _LibraryCard(
                title: 'المصحف الموضوعي',
                icon: Icons.account_tree_outlined,
                description:
                    'فهرس الموسوعة القرآنية • 6100 موضوع. موضوعات متداخلة تغطي 3673 آية، وليست تقسيمًا شاملًا متفقًا عليه لكل القرآن.',
                status:
                    'الفهرس مدمج • نسخة 2026-10-24 • النص والصفحات مشتركة مع مصحف المدينة',
                size: '163,306 بايت؛ لا تنزيل إضافي للفهرس',
                onRead: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const MushafTopicsPage(),
                  ),
                ),
              ),
              if (repository.offlineProgress case final progress?
                  when _busy) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress.progress),
                Text(
                  '${progress.completedPages} / 604 • ${(progress.receivedBytes / 1048576).toStringAsFixed(1)} MiB',
                ),
                TextButton(
                  onPressed: repository.cancelOfflinePack,
                  child: const Text('إيقاف مؤقت'),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() => _cloudStatus = _checkCloud()),
                icon: const Icon(Icons.cloud_sync_outlined),
                label: const Text('التحقق من فهرس المكتبة المحدث'),
              ),
              if (_cloudStatus != null)
                FutureBuilder<Map<String, dynamic>>(
                  future: _cloudStatus,
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return const Text(
                        'تعذر الاتصال بفهرس المكتبة. تبقى القراءة والموضوعات المحلية متاحة.',
                      );
                    if (!snapshot.hasData)
                      return const LinearProgressIndicator();
                    final status = snapshot.data!['status'] as Map?;
                    return Text(
                      'الفهرس متصل • ${status?['canonical_ayahs'] ?? 0} آية مرجعية • ${status?['topics'] ?? 0} موضوع • ${status?['topic_version'] ?? ''}',
                    );
                  },
                ),
              const SelectableText(
                'المصادر: qurancomplex.gov.sa/quran-dev/ • github.com/quranpedia/quran-svg • qul.tarteel.ai/resources/font/240 • quranpedia.net/dumps\nلا ننسخ أصول تطبيق سورة أو محفظ الوحيين. القارئ السابق وبياناته محفوظان.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.title,
    required this.icon,
    required this.description,
    required this.status,
    required this.size,
    required this.onRead,
    this.onManage,
    this.manageLabel,
  });
  final String title, description, status, size;
  final IconData icon;
  final VoidCallback onRead;
  final VoidCallback? onManage;
  final String? manageLabel;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    margin: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xff243b6b), Color(0xff162746)],
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 40, color: const Color(0xffc77955)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xfff8f6f1),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(description),
              const SizedBox(height: 10),
              Text(status),
              const SizedBox(height: 6),
              Text(size),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: ValueKey(title),
                    onPressed: onRead,
                    icon: const Icon(Icons.menu_book),
                    label: const Text('قراءة'),
                  ),
                  if (manageLabel != null)
                    OutlinedButton.icon(
                      onPressed: onManage,
                      icon: const Icon(Icons.download_outlined),
                      label: Text(manageLabel!),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class MushafTopicsPage extends ConsumerStatefulWidget {
  const MushafTopicsPage({super.key, this.parentId});
  final int? parentId;
  @override
  ConsumerState<MushafTopicsPage> createState() => _MushafTopicsPageState();
}

class _MushafTopicsPageState extends ConsumerState<MushafTopicsPage> {
  late final Future<MushafTopicIndex> _index = MushafTopicIndex.load();
  String _query = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('فهرس الموضوعات القرآنية')),
    body: FutureBuilder<MushafTopicIndex>(
      future: _index,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text('تعذر التحقق من فهرس الموضوعات'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final index = snapshot.data!;
        final values = index.search(_query, parentId: widget.parentId);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'ابحث في جميع الموضوعات',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'إعداد الموسوعة القرآنية • 2026-10-24\nالفهرس لا يغيّر النص أو ترتيب الآيات، وحدود الموضوعات اجتهادية.',
              ),
            ),
            if (widget.parentId != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(index.byId[widget.parentId]?.title ?? ''),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: values.length,
                itemBuilder: (context, i) {
                  final topic = values[i];
                  final children = index.topics.any(
                    (t) => t.parentId == topic.id,
                  );
                  return ListTile(
                    title: Text(topic.title),
                    subtitle: Text(
                      '${topic.verseKeys.length} آية${_query.isEmpty ? '' : '\n${index.ancestry(topic)}'}',
                    ),
                    trailing: children
                        ? IconButton(
                            tooltip: 'الموضوعات الفرعية',
                            icon: const Icon(Icons.account_tree_outlined),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    MushafTopicsPage(parentId: topic.id),
                              ),
                            ),
                          )
                        : null,
                    onTap: topic.verseKeys.isEmpty
                        ? (children
                              ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        MushafTopicsPage(parentId: topic.id),
                                  ),
                                )
                              : null)
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => _TopicVersesPage(
                                topic: topic,
                                ancestry: index.ancestry(topic),
                              ),
                            ),
                          ),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _TopicVersesPage extends ConsumerStatefulWidget {
  const _TopicVersesPage({required this.topic, required this.ancestry});
  final MushafTopic topic;
  final String ancestry;
  @override
  ConsumerState<_TopicVersesPage> createState() => _TopicVersesPageState();
}

class _TopicVersesPageState extends ConsumerState<_TopicVersesPage> {
  final Map<int, Future<QuranPassage>> _surahs = {};
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.topic.title)),
    body: ListView.builder(
      itemCount: widget.topic.verseKeys.length + 1,
      itemBuilder: (context, i) {
        if (i == 0)
          return Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              '${widget.ancestry}\nالمصدر: الموسوعة القرآنية quranpedia.net • 2026-10-24\nاضغط على الآية لفتح صفحتها والتفسير والتلاوة.',
            ),
          );
        final key = widget.topic.verseKeys[i - 1];
        final surah = int.parse(key.split(':').first);
        final future = _surahs.putIfAbsent(
          surah,
          () => ref
              .read(servicesProvider)
              .repository
              .quranPassage(QuranBrowseMode.surah, surah),
        );
        return FutureBuilder<QuranPassage>(
          future: future,
          builder: (context, snapshot) {
            final verse = snapshot.data?.verses
                .where((v) => v.verseKey == key)
                .firstOrNull;
            return Card(
              child: ListTile(
                title: Text(
                  verse?.textUthmani ?? key,
                  textDirection: TextDirection.rtl,
                ),
                subtitle: Text(
                  verse == null
                      ? (snapshot.hasError
                            ? 'تعذر تحميل الآية؛ أعد فتح الموضوع عند توفر الاتصال'
                            : 'جارٍ تحميل النص الحالي…')
                      : '${verse.surahNameAr} • $key • صفحة ${verse.pageNumber} • جزء ${verse.juzNumber}',
                ),
                onTap: verse == null
                    ? null
                    : () async {
                        final pages = await MushafVisualPages.load();
                        if (!context.mounted) return;
                        await Navigator.pushNamed(
                          context,
                          MobileRoutes.reader,
                          arguments: pages[key] ?? verse.pageNumber,
                        );
                      },
              ),
            );
          },
        );
      },
    ),
  );
}
