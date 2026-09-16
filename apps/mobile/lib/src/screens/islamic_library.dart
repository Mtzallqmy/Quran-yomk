import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../services.dart';
import '../trusted_islamic_library.dart';

class IslamicLibraryPage extends ConsumerStatefulWidget {
  const IslamicLibraryPage({super.key});

  @override
  ConsumerState<IslamicLibraryPage> createState() => _IslamicLibraryPageState();
}

class _IslamicLibraryPageState extends ConsumerState<IslamicLibraryPage> {
  late Future<List<TrustedIslamicCategory>> _categories;

  @override
  void initState() {
    super.initState();
    _categories = ref.read(servicesProvider).trustedIslamicLibrary.categories();
  }

  Future<void> _refresh() async {
    final repository = ref.read(servicesProvider).trustedIslamicLibrary;
    setState(() => _categories = repository.categories(refresh: true));
    await _categories;
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    final repository = services.trustedIslamicLibrary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('المكتبة الإسلامية الموثوقة'),
        actions: <Widget>[
          IconButton(
            tooltip: 'الصوتيات المرخصة',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const _LicensedAudioPage()),
            ),
            icon: const Icon(Icons.graphic_eq),
          ),
          IconButton(
            tooltip: 'التوقيتات',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const _SchedulePage()),
            ),
            icon: const Icon(Icons.schedule_outlined),
          ),
          IconButton(
            tooltip: 'المصادر والتراخيص',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const _SourcesPage()),
            ),
            icon: const Icon(Icons.verified_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<TrustedIslamicCategory>>(
          future: _categories,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const ListView(
                children: <Widget>[
                  SizedBox(height: 240),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }
            if (snapshot.hasError && !snapshot.hasData) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: <Widget>[
                  const SizedBox(height: 120),
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'تعذر تحميل المكتبة ولم توجد نسخة محلية بعد.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              );
            }
            final categories = snapshot.data ?? const <TrustedIslamicCategory>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          'محتوى موثّق • Offline-First • SHA-256',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'النصوص تُستدعى من API موحد فوق Supabase، وتُحفظ محليًا عند الاستخدام. '
                          'الصوتيات لا تظهر هنا إلا بعد اعتماد حق إعادة التوزيع لكل ملف على حدة.',
                        ),
                        if (repository.lastError != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            'تعمل النسخة المحلية حاليًا؛ تعذر تحديث الخادم.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                for (final category in categories)
                  Card(
                    child: ListTile(
                      leading: Icon(_categoryIcon(category.slug)),
                      title: Text(category.nameAr),
                      subtitle: Text('${category.itemCount} عنصر معتمد'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _CategoryPage(category: category),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  IconData _categoryIcon(String slug) => switch (slug) {
    'adhan' => Icons.campaign_outlined,
    'iqamah' => Icons.notifications_active_outlined,
    'adhkar_morning' => Icons.wb_sunny_outlined,
    'adhkar_evening' => Icons.nights_stay_outlined,
    'adhkar_sleep' => Icons.bedtime_outlined,
    'adhkar_prayer' => Icons.mosque_outlined,
    'dua' => Icons.volunteer_activism_outlined,
    'quran' => Icons.menu_book_outlined,
    _ => Icons.auto_stories_outlined,
  };
}

class _CategoryPage extends ConsumerStatefulWidget {
  const _CategoryPage({required this.category});
  final TrustedIslamicCategory category;

  @override
  ConsumerState<_CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends ConsumerState<_CategoryPage> {
  late Future<List<TrustedIslamicContentItem>> _future;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(servicesProvider)
        .trustedIslamicLibrary
        .content(widget.category.slug);
  }

  Future<void> _refresh() async {
    final repository = ref.read(servicesProvider).trustedIslamicLibrary;
    setState(() {
      _downloading = true;
      _future = repository.refreshCategory(widget.category.slug);
    });
    try {
      await _future;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث وحفظ المحتوى محليًا.')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.category.nameAr),
      actions: <Widget>[
        IconButton(
          tooltip: 'تنزيل/تحديث دون إنترنت',
          onPressed: _downloading ? null : _refresh,
          icon: _downloading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_for_offline_outlined),
        ),
      ],
    ),
    body: FutureBuilder<List<TrustedIslamicContentItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError && !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('تعذر تحميل هذا القسم ولا توجد نسخة محلية.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _refresh, child: const Text('إعادة المحاولة')),
                ],
              ),
            ),
          );
        }
        final items = snapshot.data ?? const <TrustedIslamicContentItem>[];
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 28),
          itemCount: items.length,
          itemBuilder: (context, index) => _ContentCard(item: items[index]),
        );
      },
    ),
  );
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.item});
  final TrustedIslamicContentItem item;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: SelectableText(
        item.titleAr,
        textDirection: TextDirection.rtl,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${item.sourceTitle} • التكرار ${item.repeatCount}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SelectableText(
          item.textAr,
          textDirection: TextDirection.rtl,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.8),
        ),
        if (item.reference?.trim().isNotEmpty == true) ...<Widget>[
          const SizedBox(height: 12),
          Text('المرجع: ${item.reference}'),
        ],
        const SizedBox(height: 10),
        Text('التصنيف: ${item.categoryNamesAr.join('، ')}'),
        Text('المصدر: ${item.sourceTitle} (${item.sourceSlug})'),
        Text('حالة المراجعة: ${item.reviewStatus}'),
        Text('الترخيص: ${item.licenseName}'),
        SelectableText('SHA256: ${item.sha256}'),
        if (item.sourceFileSha256 != null)
          SelectableText('Source SHA256: ${item.sourceFileSha256}'),
        if (item.sourceRevision != null) Text('إصدار المصدر: ${item.sourceRevision}'),
        const SizedBox(height: 8),
        SelectableText('رابط الترخيص: ${item.licenseUrl}'),
        SelectableText('المصدر الأصلي: ${item.originalSourceUrl}'),
      ],
    ),
  );
}

class _LicensedAudioPage extends ConsumerStatefulWidget {
  const _LicensedAudioPage();

  @override
  ConsumerState<_LicensedAudioPage> createState() => _LicensedAudioPageState();
}

class _LicensedAudioPageState extends ConsumerState<_LicensedAudioPage> {
  final AudioPlayer _player = AudioPlayer();
  late Future<List<TrustedIslamicAudioAsset>> _future;
  String? _busySlug;

  @override
  void initState() {
    super.initState();
    _future = ref.read(servicesProvider).trustedIslamicLibrary.audio();
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _run(
    TrustedIslamicAudioAsset asset,
    Future<void> Function(String filePath) action,
  ) async {
    setState(() => _busySlug = asset.slug);
    try {
      final file = await ref
          .read(servicesProvider)
          .trustedIslamicLibrary
          .downloadAudio(asset);
      await action(file.path);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تجهيز الصوت: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busySlug = null);
    }
  }

  Future<void> _selectAdhan(TrustedIslamicAudioAsset asset) => _run(
    asset,
    (path) async {
      final services = ref.read(servicesProvider);
      await services.prayerSettings.setAdhanAudio(
        slug: asset.slug,
        sha256: asset.sha256,
        path: path,
      );
      await services.prayerReminders.reconcile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم اعتماد هذا الصوت للأذان.')),
        );
        setState(() {});
      }
    },
  );

  Future<void> _selectIqamah(TrustedIslamicAudioAsset asset) => _run(
    asset,
    (path) async {
      final services = ref.read(servicesProvider);
      await services.prayerSettings.setIqamahAudio(
        slug: asset.slug,
        sha256: asset.sha256,
        path: path,
      );
      if (mounted) setState(() {});
    },
  );

  Future<void> _preview(TrustedIslamicAudioAsset asset) => _run(
    asset,
    (path) async {
      await _player.stop();
      await _player.setFilePath(path);
      await _player.play();
    },
  );

  @override
  Widget build(BuildContext context) {
    final settingsStore = ref.watch(servicesProvider).prayerSettings;
    return Scaffold(
      appBar: AppBar(title: const Text('الصوتيات المرخصة')),
      body: AnimatedBuilder(
        animation: settingsStore,
        builder: (context, _) => FutureBuilder<List<TrustedIslamicAudioAsset>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError && !snapshot.hasData) {
              return Center(child: Text('تعذر تحميل الصوتيات: ${snapshot.error}'));
            }
            final assets = snapshot.data ?? const <TrustedIslamicAudioAsset>[];
            final prayer = settingsStore.value;
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          'لا تُستخدم إلا الملفات التي أعاد الخادم فحص ترخيصها وSHA-256 ثم حُفظت في Supabase Storage.',
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('تشغيل صوت الإقامة بعد الصلاة'),
                          subtitle: Text(
                            prayer.iqamahAudioSlug == null
                                ? 'اختر ملف إقامة أولًا.'
                                : 'بعد ${prayer.iqamahOffsetMinutes} دقائق — ${prayer.iqamahAudioSlug}',
                          ),
                          value: prayer.iqamahEnabled,
                          onChanged: prayer.iqamahAudioPath == null
                              ? null
                              : (value) async {
                                  await settingsStore.setIqamahEnabled(value);
                                  await ref.read(servicesProvider).prayerReminders.reconcile();
                                },
                        ),
                        if (prayer.iqamahAudioPath != null)
                          Row(
                            children: <Widget>[
                              const Text('تأخير الإقامة:'),
                              const SizedBox(width: 12),
                              DropdownButton<int>(
                                value: prayer.iqamahOffsetMinutes,
                                items: const <int>[5, 10, 15, 20, 30]
                                    .map(
                                      (value) => DropdownMenuItem<int>(
                                        value: value,
                                        child: Text('$value دقيقة'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) async {
                                  if (value == null) return;
                                  await settingsStore.setIqamahOffset(value);
                                  await ref.read(servicesProvider).prayerReminders.reconcile();
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                for (final asset in assets)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            asset.titleAr,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text('النوع: ${asset.kind}'),
                          if (asset.voiceName != null) Text('المؤذن/الرافع: ${asset.voiceName}'),
                          Text('الترخيص: ${asset.licenseName}'),
                          Text('حالة المراجعة: ${asset.reviewStatus}'),
                          SelectableText('SHA256: ${asset.sha256}'),
                          SelectableText('رابط الترخيص: ${asset.licenseUrl}'),
                          SelectableText('المصدر الأصلي: ${asset.originalSourceUrl}'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              OutlinedButton.icon(
                                onPressed: _busySlug == null ? () => _preview(asset) : null,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('تنزيل ومعاينة'),
                              ),
                              if (asset.kind == 'adhan')
                                FilledButton.icon(
                                  onPressed: _busySlug == null ? () => _selectAdhan(asset) : null,
                                  icon: Icon(
                                    prayer.adhanAudioSlug == asset.slug
                                        ? Icons.check_circle
                                        : Icons.campaign_outlined,
                                  ),
                                  label: const Text('استخدام للأذان'),
                                ),
                              if (asset.kind == 'iqamah')
                                FilledButton.icon(
                                  onPressed: _busySlug == null ? () => _selectIqamah(asset) : null,
                                  icon: Icon(
                                    prayer.iqamahAudioSlug == asset.slug
                                        ? Icons.check_circle
                                        : Icons.notifications_active_outlined,
                                  ),
                                  label: const Text('استخدام للإقامة'),
                                ),
                            ],
                          ),
                          if (_busySlug == asset.slug) ...<Widget>[
                            const SizedBox(height: 8),
                            const LinearProgressIndicator(),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SchedulePage extends ConsumerStatefulWidget {
  const _SchedulePage();

  @override
  ConsumerState<_SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<_SchedulePage> {
  late Future<List<TrustedIslamicScheduleTemplate>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(servicesProvider).trustedIslamicLibrary.schedules();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(servicesProvider).trustedIslamicSchedules;
    return Scaffold(
      appBar: AppBar(title: const Text('توقيت المحتوى')), 
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => FutureBuilder<List<TrustedIslamicScheduleTemplate>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError && !snapshot.hasData) {
              return Center(child: Text('تعذر تحميل التوقيتات: ${snapshot.error}'));
            }
            final templates = snapshot.data ?? const <TrustedIslamicScheduleTemplate>[];
            return ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.schedule_send_outlined),
                    title: const Text('جدولة محلية فعلية'),
                    subtitle: Text(
                      'تمت جدولة ${controller.scheduledCount} تنبيهًا للأيام القادمة. '
                      'تُعاد الحسابات عند تغيير الموقع أو طريقة مواقيت الصلاة.',
                    ),
                  ),
                ),
                for (final template in templates)
                  Card(
                    child: SwitchListTile(
                      title: Text(template.titleAr),
                      subtitle: Text(_triggerLabel(template)),
                      value: controller.enabledFor(template),
                      onChanged: controller.reconciling
                          ? null
                          : (value) async {
                              final ok = await controller.setEnabled(template, value);
                              if (!ok && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('يلزم السماح بالإشعارات لتفعيل التوقيت.'),
                                  ),
                                );
                              }
                            },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _triggerLabel(TrustedIslamicScheduleTemplate value) => switch (value.triggerKind) {
    'fixed_local_time' => 'وقت محلي ${value.fixedLocalTime ?? '--:--'}',
    'sunrise_relative' => 'بالنسبة للشروق: ${_offset(value.offsetMinutes)}',
    'sunset_relative' => 'بالنسبة للغروب: ${_offset(value.offsetMinutes)}',
    'prayer_relative' => 'بالنسبة لصلاة ${value.prayer ?? ''}: ${_offset(value.offsetMinutes)}',
    _ => value.triggerKind,
  };

  String _offset(int minutes) => minutes == 0
      ? 'في نفس الوقت'
      : minutes > 0
          ? 'بعد $minutes دقيقة'
          : 'قبل ${minutes.abs()} دقيقة';
}

class _SourcesPage extends ConsumerWidget {
  const _SourcesPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(servicesProvider).trustedIslamicLibrary;
    return Scaffold(
      appBar: AppBar(title: const Text('المصادر والتراخيص')),
      body: FutureBuilder<List<TrustedIslamicSource>>(
        future: repository.sources(),
        builder: (context, snapshot) {
          if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return Center(child: Text('تعذر تحميل المصادر: ${snapshot.error}'));
          }
          final sources = snapshot.data ?? const <TrustedIslamicSource>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            children: <Widget>[
              for (final source in sources)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          source.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text('نطاق الترخيص: ${source.licenseScope}'),
                        Text('الترخيص: ${source.licenseName}'),
                        Text(
                          'إعادة التوزيع: ${source.redistributionAllowed ? 'مسموحة ضمن النطاق المسجل' : 'غير مفترضة/تحتاج مراجعة مستقلة'}',
                        ),
                        if (source.notes != null) Text(source.notes!),
                        const SizedBox(height: 8),
                        SelectableText('المصدر: ${source.originalUrl}'),
                        SelectableText('الترخيص: ${source.licenseUrl}'),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
