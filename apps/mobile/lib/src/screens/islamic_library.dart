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
  late Future<List<TrustedIslamicCategory>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(servicesProvider).trustedIslamicLibrary.categories();
  }

  Future<void> _refresh() async {
    final repository = ref.read(servicesProvider).trustedIslamicLibrary;
    final future = repository.categories(refresh: true);
    setState(() => _future = future);
    await future;
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
            icon: const Icon(Icons.graphic_eq),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const _LicensedAudioPage(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'التوقيتات',
            icon: const Icon(Icons.schedule_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const _SchedulePage()),
            ),
          ),
          IconButton(
            tooltip: 'المصادر والتراخيص',
            icon: const Icon(Icons.verified_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const _SourcesPage()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<TrustedIslamicCategory>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData &&
                snapshot.connectionState != ConnectionState.done) {
              return ListView(
                children: const <Widget>[
                  SizedBox(height: 240),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }
            if (snapshot.hasError && !snapshot.hasData) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: <Widget>[
                  const SizedBox(height: 110),
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
            final categories =
                snapshot.data ?? const <TrustedIslamicCategory>[];
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
                          'المحتوى يأتي من API موحد فوق Supabase ويُحفظ محليًا. '
                          'لا تظهر الصوتيات إلا بعد اعتماد حق إعادة التوزيع لكل ملف على حدة.',
                        ),
                        if (repository.lastError != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            'تعذر تحديث الخادم؛ يجري استخدام النسخة المحلية المتاحة.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
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
  bool _refreshing = false;

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
    setState(() => _refreshing = true);
    try {
      final future = repository.content(widget.category.slug, refresh: true);
      setState(() => _future = future);
      await future;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث وحفظ القسم محليًا.')),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.category.nameAr),
          actions: <Widget>[
            IconButton(
              tooltip: 'تنزيل/تحديث دون إنترنت',
              onPressed: _refreshing ? null : _refresh,
              icon: _refreshing
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
            if (!snapshot.hasData &&
                snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError && !snapshot.hasData) {
              return Center(
                child: FilledButton(
                  onPressed: _refresh,
                  child: const Text('إعادة المحاولة'),
                ),
              );
            }
            final items =
                snapshot.data ?? const <TrustedIslamicContentItem>[];
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    height: 1.8,
                  ),
            ),
            if (item.reference?.trim().isNotEmpty == true)
              Text('المرجع: ${item.reference}'),
            Text('التصنيف: ${item.categoryNamesAr.join('، ')}'),
            Text('المصدر: ${item.sourceTitle}'),
            Text('الترخيص: ${item.licenseName}'),
            Text('حالة المراجعة: ${item.reviewStatus}'),
            SelectableText('SHA256: ${item.sha256}'),
            if (item.sourceFileSha256 != null)
              SelectableText('Source SHA256: ${item.sourceFileSha256}'),
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

  Future<void> _withLocalFile(
    TrustedIslamicAudioAsset asset,
    Future<void> Function(String path) action,
  ) async {
    setState(() => _busySlug = asset.slug);
    try {
      final file = await ref
          .read(servicesProvider)
          .trustedIslamicLibrary
          .downloadAudio(asset);
      await action(file.path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تجهيز الصوت: $error')),
      );
    } finally {
      if (mounted) setState(() => _busySlug = null);
    }
  }

  Future<void> _preview(TrustedIslamicAudioAsset asset) =>
      _withLocalFile(asset, (path) async {
        await _player.stop();
        await _player.setFilePath(path);
        unawaited(_player.play());
      });

  Future<void> _selectAdhan(TrustedIslamicAudioAsset asset) =>
      _withLocalFile(asset, (path) async {
        final services = ref.read(servicesProvider);
        await services.prayerSettings.setAdhanAudio(
          slug: asset.slug,
          sha256: asset.sha256,
          path: path,
        );
        await services.prayerReminders.reconcile();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم اعتماد هذا الملف للأذان.')),
        );
      });

  Future<void> _selectIqamah(TrustedIslamicAudioAsset asset) =>
      _withLocalFile(asset, (path) async {
        final services = ref.read(servicesProvider);
        await services.prayerSettings.setIqamahAudio(
          slug: asset.slug,
          sha256: asset.sha256,
          path: path,
        );
        await services.prayerReminders.reconcile();
        if (mounted) setState(() {});
      });

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    final settings = services.prayerSettings;
    return Scaffold(
      appBar: AppBar(title: const Text('الصوتيات المرخصة')),
      body: AnimatedBuilder(
        animation: settings,
        builder: (context, _) => FutureBuilder<List<TrustedIslamicAudioAsset>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData &&
                snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError && !snapshot.hasData) {
              return Center(child: Text('تعذر تحميل الصوتيات: ${snapshot.error}'));
            }
            final prayer = settings.value;
            final assets = snapshot.data ?? const <TrustedIslamicAudioAsset>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
              children: <Widget>[
                Card(
                  child: Column(
                    children: <Widget>[
                      SwitchListTile(
                        title: const Text('تشغيل الإقامة بعد الصلاة'),
                        subtitle: Text(
                          prayer.iqamahAudioSlug == null
                              ? 'اختر ملف إقامة مرخصًا أولًا.'
                              : 'بعد ${prayer.iqamahOffsetMinutes} دقائق',
                        ),
                        value: prayer.iqamahEnabled,
                        onChanged: prayer.iqamahAudioPath == null
                            ? null
                            : (value) async {
                                await settings.setIqamahEnabled(value);
                                await services.prayerReminders.reconcile();
                              },
                      ),
                      ListTile(
                        title: const Text('تأخير الإقامة'),
                        subtitle: Text('${prayer.iqamahOffsetMinutes} دقيقة'),
                        trailing: DropdownButton<int>(
                          value: prayer.iqamahOffsetMinutes,
                          items: const <int>[5, 10, 15, 20, 25, 30]
                              .map(
                                (value) => DropdownMenuItem<int>(
                                  value: value,
                                  child: Text('$value د'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            if (value == null) return;
                            await settings.setIqamahOffset(value);
                            await services.prayerReminders.reconcile();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'كل ملف أدناه معتمد لإعادة التوزيع ومتحقق منه بـ SHA-256 قبل استخدامه محليًا.',
                  ),
                ),
                for (final asset in assets)
                  Card(
                    child: ListTile(
                      title: Text(asset.titleAr),
                      subtitle: Text(
                        '${asset.kind} • ${asset.voiceName ?? 'غير منسوب'}\n${asset.licenseName}',
                      ),
                      isThreeLine: true,
                      trailing: _busySlug == asset.slug
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : PopupMenuButton<String>(
                              onSelected: (action) {
                                if (action == 'preview') {
                                  unawaited(_preview(asset));
                                } else if (action == 'adhan') {
                                  unawaited(_selectAdhan(asset));
                                } else if (action == 'iqamah') {
                                  unawaited(_selectIqamah(asset));
                                }
                              },
                              itemBuilder: (_) => <PopupMenuEntry<String>>[
                                const PopupMenuItem(
                                  value: 'preview',
                                  child: Text('معاينة'),
                                ),
                                if (asset.kind == 'adhan')
                                  const PopupMenuItem(
                                    value: 'adhan',
                                    child: Text('استخدامه للأذان'),
                                  ),
                                if (asset.kind == 'iqamah')
                                  const PopupMenuItem(
                                    value: 'iqamah',
                                    child: Text('استخدامه للإقامة'),
                                  ),
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
    final services = ref.watch(servicesProvider);
    final controller = services.trustedIslamicSchedules;
    return Scaffold(
      appBar: AppBar(title: const Text('توقيتات الأذكار والأدعية')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => FutureBuilder<
            List<TrustedIslamicScheduleTemplate>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              if (snapshot.hasError) {
                return Center(child: Text('تعذر تحميل التوقيتات: ${snapshot.error}'));
              }
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
              children: <Widget>[
                if (controller.scheduledCount > 0)
                  ListTile(
                    leading: const Icon(Icons.alarm_on),
                    title: Text(
                      '${controller.scheduledCount} تذكيرًا محليًا مجدولًا',
                    ),
                  ),
                for (final template in snapshot.data!)
                  Card(
                    child: SwitchListTile(
                      title: Text(template.titleAr),
                      subtitle: Text(_scheduleDescription(template)),
                      value: controller.enabledFor(template),
                      onChanged: controller.reconciling
                          ? null
                          : (value) async {
                              final enabled = await controller.setEnabled(
                                template,
                                value,
                              );
                              if (!enabled && value && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('يلزم السماح بالإشعارات.'),
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

  String _scheduleDescription(TrustedIslamicScheduleTemplate template) {
    final offset = template.offsetMinutes;
    return switch (template.triggerKind) {
      'fixed_local_time' => 'يوميًا ${template.fixedLocalTime ?? ''}',
      'sunrise_relative' => 'بالنسبة للشروق ${_signed(offset)} دقيقة',
      'sunset_relative' => 'بالنسبة للمغرب ${_signed(offset)} دقيقة',
      'prayer_relative' =>
        'بالنسبة لصلاة ${template.prayer ?? ''} ${_signed(offset)} دقيقة',
      _ => template.triggerKind,
    };
  }

  String _signed(int value) => value >= 0 ? '+$value' : '$value';
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
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text('تعذر تحميل المصادر: ${snapshot.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            children: <Widget>[
              for (final source in snapshot.data!)
                Card(
                  child: ExpansionTile(
                    title: Text(source.title),
                    subtitle: Text(source.licenseName),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text('نطاق الترخيص: ${source.licenseScope}'),
                      Text(
                        'إعادة التوزيع: ${source.redistributionAllowed ? 'مسموحة' : 'غير مسموحة'}',
                      ),
                      if (source.notes?.isNotEmpty == true) Text(source.notes!),
                      SelectableText(source.licenseUrl),
                      SelectableText(source.originalUrl),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
