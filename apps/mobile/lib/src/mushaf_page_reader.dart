import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import 'islamic_content.dart';
import 'mushaf_pages.dart';
import 'mushaf_store.dart';
import 'quran_models.dart';

class MushafPageReader extends StatefulWidget {
  const MushafPageReader({
    super.key,
    required this.repository,
    required this.contentRepository,
    required this.store,
    required this.initialPage,
    required this.onPageChanged,
    required this.onPlayAyah,
    required this.onChooseReciter,
    required this.onPlaySurah,
    required this.onDownloadSurah,
    required this.onShowText,
    required this.onImmersiveChanged,
    required this.resolveVerse,
  });

  final MushafPageRepository repository;
  final IslamicContentRepository contentRepository;
  final MushafStore store;
  final int initialPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<QuranVerse> onPlayAyah;
  final VoidCallback onChooseReciter;
  final VoidCallback onPlaySurah;
  final VoidCallback onDownloadSurah;
  final VoidCallback onShowText;
  final ValueChanged<bool> onImmersiveChanged;
  final Future<QuranVerse?> Function(int page, String verseKey) resolveVerse;

  @override
  State<MushafPageReader> createState() => _MushafPageReaderState();
}

class _MushafPageReaderState extends State<MushafPageReader> {
  late final PageController _pages;
  late MushafPageEdition _edition;
  late int _page;
  bool _controlsVisible = true;
  MushafAyahRegion? _selected;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(1, mushafPageCount);
    _pages = PageController(initialPage: _page - 1);
    _edition = MushafPageEdition.values.firstWhere(
      (value) => value.name == widget.store.pageEdition,
      orElse: () => MushafPageEdition.madinahHafsSvg,
    );
    _scheduleControlsHide();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _pages.dispose();
    widget.onImmersiveChanged(false);
    super.dispose();
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _controlsVisible = false);
      widget.onImmersiveChanged(true);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    widget.onImmersiveChanged(!_controlsVisible);
    if (_controlsVisible) _scheduleControlsHide();
  }

  Future<void> _setEdition(MushafPageEdition edition) async {
    if (_edition == edition) return;
    setState(() {
      _edition = edition;
    });
    await widget.store.setPageEdition(edition.name);
    _scheduleControlsHide();
  }

  Future<void> _select(MushafAyahRegion region) async {
    setState(() {
      _selected = region;
      _controlsVisible = true;
    });
    widget.onImmersiveChanged(false);
    _scheduleControlsHide();
  }

  Future<void> _playSelected() async {
    final selected = _selected;
    if (selected == null) return;
    final verse = await widget.resolveVerse(_page, selected.verseKey);
    if (verse != null) widget.onPlayAyah(verse);
  }

  Future<void> _showSelectedActions() async {
    final selected = _selected;
    if (selected == null || !mounted) return;
    final verse = await widget.resolveVerse(_page, selected.verseKey);
    if (verse == null || !mounted) return;
    final content = await widget.contentRepository.ayahContent(
      selected.surahNumber,
      selected.ayahNumber,
    );
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'الآية ${selected.verseKey}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (content.theme != null) ...<Widget>[
              const SizedBox(height: 12),
              ListTile(
                tileColor: Color(content.theme!.colorValue),
                leading: const Icon(Icons.palette_outlined),
                title: Text(content.theme!.titleAr),
                subtitle: Text(content.theme!.descriptionAr),
              ),
            ],
            if (content.tafseer != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'التفسير الميسر',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              SelectableText(
                content.tafseer!,
                textDirection: TextDirection.rtl,
              ),
            ],
            const Divider(height: 28),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('تشغيل التلاوة'),
              onTap: () {
                Navigator.pop(context);
                widget.onPlayAyah(verse);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('نسخ الآية'),
              onTap: () async {
                await Clipboard.setData(
                  ClipboardData(text: content.arabic ?? verse.textUthmani),
                );
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('مشاركة'),
              onTap: () => SharePlus.instance.share(
                ShareParams(
                  text:
                      '${content.arabic ?? verse.textUthmani}\n'
                      '[${selected.verseKey}]',
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                widget.store.isBookmarked(verse.verseKey)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
              ),
              title: const Text('حفظ / إزالة الإشارة المرجعية'),
              onTap: () async {
                await widget.store.toggleBookmark(verse);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.color_lens_outlined),
              title: const Text('إظهار أحكام التجويد'),
              onTap: () {
                Navigator.pop(context);
                _setEdition(MushafPageEdition.madinahTajweedQcfV4);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _offlinePack() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _OfflinePackSheet(repository: widget.repository, edition: _edition),
    );
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xfffffaf2),
    child: Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Directionality(
          textDirection: TextDirection.rtl,
          child: PageView.builder(
            key: const ValueKey<String>('mushaf-page-view'),
            controller: _pages,
            itemCount: mushafPageCount,
            onPageChanged: (index) {
              setState(() {
                _page = index + 1;
                _selected = null;
              });
              widget.onPageChanged(_page);
              _scheduleControlsHide();
            },
            itemBuilder: (context, index) => _PageSurface(
              key: ValueKey<String>('${_edition.name}-${index + 1}'),
              page: index + 1,
              edition: _edition,
              repository: widget.repository,
              contentRepository: widget.contentRepository,
              showThemes: widget.store.showThemes,
              selectedVerseKey: _selected?.verseKey,
              onRegionTap: _select,
              onBackgroundTap: _toggleControls,
            ),
          ),
        ),
        IgnorePointer(
          ignoring: !_controlsVisible,
          child: AnimatedOpacity(
            opacity: _controlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                bottom: false,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Colors.black26, blurRadius: 12),
                    ],
                  ),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'عرض نصي',
                        onPressed: widget.onShowText,
                        icon: const Icon(Icons.text_fields),
                      ),
                      IconButton(
                        tooltip: widget.store.showThemes
                            ? 'إيقاف ألوان الموضوعات'
                            : 'تشغيل ألوان الموضوعات',
                        onPressed: () => widget.store.setShowThemes(
                          !widget.store.showThemes,
                        ),
                        icon: Icon(
                          widget.store.showThemes
                              ? Icons.palette
                              : Icons.palette_outlined,
                        ),
                      ),
                      Expanded(
                        child: SegmentedButton<MushafPageEdition>(
                          showSelectedIcon: false,
                          segments: MushafPageEdition.values
                              .map(
                                (edition) => ButtonSegment<MushafPageEdition>(
                                  value: edition,
                                  label: Text(
                                    edition == MushafPageEdition.madinahHafsSvg
                                        ? 'عادي'
                                        : 'تجويد',
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          selected: <MushafPageEdition>{_edition},
                          onSelectionChanged: (values) =>
                              _setEdition(values.first),
                        ),
                      ),
                      IconButton(
                        tooltip: 'الحزمة دون إنترنت',
                        onPressed: _offlinePack,
                        icon: const Icon(Icons.download_for_offline_outlined),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        IgnorePointer(
          ignoring: !_controlsVisible,
          child: AnimatedOpacity(
            opacity: _controlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Colors.black26, blurRadius: 12),
                    ],
                  ),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'اختيار القارئ',
                        onPressed: widget.onChooseReciter,
                        icon: const Icon(Icons.record_voice_over_outlined),
                      ),
                      IconButton(
                        tooltip: _selected == null
                            ? 'حدد آية من الصفحة'
                            : 'تشغيل ${_selected!.verseKey}',
                        onPressed: _selected == null ? null : _playSelected,
                        icon: const Icon(Icons.play_circle_fill),
                      ),
                      IconButton(
                        tooltip: 'إجراءات الآية',
                        onPressed: _selected == null
                            ? null
                            : _showSelectedActions,
                        icon: const Icon(Icons.more_horiz),
                      ),
                      IconButton(
                        tooltip: 'تشغيل السورة',
                        onPressed: widget.onPlaySurah,
                        icon: const Icon(Icons.queue_music),
                      ),
                      IconButton(
                        tooltip: 'تنزيل السورة',
                        onPressed: widget.onDownloadSurah,
                        icon: const Icon(Icons.download_outlined),
                      ),
                      Expanded(
                        child: Text(
                          _selected == null
                              ? _edition.labelAr
                              : 'الآية ${_selected!.verseKey}',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ),
                      Text('$_page / $mushafPageCount'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _PageSurface extends StatefulWidget {
  const _PageSurface({
    super.key,
    required this.page,
    required this.edition,
    required this.repository,
    required this.contentRepository,
    required this.showThemes,
    required this.selectedVerseKey,
    required this.onRegionTap,
    required this.onBackgroundTap,
  });

  final int page;
  final MushafPageEdition edition;
  final MushafPageRepository repository;
  final IslamicContentRepository contentRepository;
  final bool showThemes;
  final String? selectedVerseKey;
  final ValueChanged<MushafAyahRegion> onRegionTap;
  final VoidCallback onBackgroundTap;

  @override
  State<_PageSurface> createState() => _PageSurfaceState();
}

class _PageSurfaceState extends State<_PageSurface> {
  late Future<_MushafPageData> _future;
  final TransformationController _transform = TransformationController();
  Offset? _doubleTapPosition;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _PageSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page ||
        oldWidget.edition != widget.edition ||
        oldWidget.showThemes != widget.showThemes) {
      _transform.value = Matrix4.identity();
      _zoomed = false;
      _future = _load();
    }
  }

  Future<_MushafPageData> _load() async {
    final asset = await widget.repository.page(widget.page, widget.edition);
    final themes = widget.showThemes
        ? await widget.contentRepository.themesForVerseKeys(
            asset.regions.map((region) => region.verseKey),
          )
        : const <String, IslamicThemeSegment>{};
    return _MushafPageData(asset: asset, themes: themes);
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _doubleTap() {
    final position = _doubleTapPosition ?? Offset.zero;
    setState(() {
      if (_zoomed) {
        _transform.value = Matrix4.identity();
      } else {
        const scale = 2.4;
        _transform.value = Matrix4.identity()
          ..translateByDouble(
            -position.dx * (scale - 1),
            -position.dy * (scale - 1),
            0,
            1,
          )
          ..scaleByDouble(scale, scale, scale, 1);
      }
      _zoomed = !_zoomed;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_MushafPageData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.broken_image_outlined, size: 42),
              const SizedBox(height: 8),
              Text('تعذر تحميل صفحة المصحف ${widget.page}'),
              TextButton.icon(
                onPressed: () => setState(() {
                  _future = _load();
                }),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        );
      }
      final data = snapshot.data;
      if (data == null) {
        return const Center(child: CircularProgressIndicator());
      }
      final asset = data.asset;
      return LayoutBuilder(
        builder: (context, constraints) {
          final aspect = asset.width / asset.height;
          var width = constraints.maxWidth;
          var height = width / aspect;
          if (height > constraints.maxHeight) {
            height = constraints.maxHeight;
            width = height * aspect;
          }
          return Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onBackgroundTap,
              onDoubleTapDown: (details) =>
                  _doubleTapPosition = details.localPosition,
              onDoubleTap: _doubleTap,
              child: SizedBox(
                width: width,
                height: height,
                child: InteractiveViewer(
                  transformationController: _transform,
                  minScale: 1,
                  maxScale: 4,
                  panEnabled: _zoomed,
                  boundaryMargin: const EdgeInsets.all(120),
                  onInteractionEnd: (_) => setState(() {
                    _zoomed = _transform.value.getMaxScaleOnAxis() > 1.02;
                  }),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (details) {
                      final x = details.localPosition.dx / width * asset.width;
                      final y =
                          details.localPosition.dy / height * asset.height;
                      final region = asset.regions
                          .where((value) => value.contains(x, y))
                          .firstOrNull;
                      if (region == null) {
                        widget.onBackgroundTap();
                      } else {
                        widget.onRegionTap(region);
                      }
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        ColoredBox(
                          color: const Color(0xfffffaf2),
                          child:
                              widget.edition == MushafPageEdition.madinahHafsSvg
                              ? SvgPicture.file(
                                  asset.file,
                                  fit: BoxFit.fill,
                                  semanticsLabel:
                                      'صفحة مصحف المدينة ${widget.page}',
                                )
                              : Image.file(
                                  asset.file,
                                  fit: BoxFit.fill,
                                  filterQuality: FilterQuality.high,
                                  semanticLabel:
                                      'صفحة مصحف التجويد ${widget.page}',
                                ),
                        ),
                        CustomPaint(
                          painter: _RegionPainter(
                            regions: asset.regions,
                            selectedVerseKey: widget.selectedVerseKey,
                            nativeSize: Size(asset.width, asset.height),
                            themes: data.themes,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _RegionPainter extends CustomPainter {
  const _RegionPainter({
    required this.regions,
    required this.selectedVerseKey,
    required this.nativeSize,
    required this.themes,
  });

  final List<MushafAyahRegion> regions;
  final String? selectedVerseKey;
  final Size nativeSize;
  final Map<String, IslamicThemeSegment> themes;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / nativeSize.width;
    final scaleY = size.height / nativeSize.height;
    for (final region in regions) {
      final selected = region.verseKey == selectedVerseKey;
      final theme = themes[region.verseKey];
      if (!selected && theme == null) continue;
      final paint = Paint()
        ..color = selected
            ? const Color(0x5077a95c)
            : Color(theme!.colorValue).withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      for (final rect in region.rects) {
        canvas.drawRect(
          Rect.fromLTWH(
            rect.left * scaleX,
            rect.top * scaleY,
            rect.width * scaleX,
            rect.height * scaleY,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RegionPainter oldDelegate) =>
      oldDelegate.selectedVerseKey != selectedVerseKey ||
      oldDelegate.regions != regions ||
      oldDelegate.nativeSize != nativeSize ||
      oldDelegate.themes != themes;
}

class _MushafPageData {
  const _MushafPageData({required this.asset, required this.themes});

  final MushafPageAsset asset;
  final Map<String, IslamicThemeSegment> themes;
}

class _OfflinePackSheet extends StatefulWidget {
  const _OfflinePackSheet({required this.repository, required this.edition});

  final MushafPageRepository repository;
  final MushafPageEdition edition;

  @override
  State<_OfflinePackSheet> createState() => _OfflinePackSheetState();
}

class _OfflinePackSheetState extends State<_OfflinePackSheet> {
  bool _busy = false;

  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      await widget.repository.downloadOfflinePack(widget.edition);
    } catch (_) {
      // The repository exposes the concrete error in its progress state.
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
          final progress = widget.repository.offlineProgress;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'حزمة ${widget.edition.labelAr} دون إنترنت',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              const Text(
                'تُحفظ 604 صفحة مع حدود الآيات على الجهاز، وتُستخدم تلقائيًا قبل الشبكة.',
              ),
              if (progress != null) ...<Widget>[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: progress.progress),
                const SizedBox(height: 6),
                Text(
                  '${progress.completedPages} / ${progress.totalPages} صفحة'
                  ' • ${(progress.receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                ),
                if (progress.error != null)
                  Text(
                    'تعذر إكمال الحزمة: ${progress.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _download,
                      icon: const Icon(Icons.download),
                      label: Text(_busy ? 'جارٍ التنزيل…' : 'تنزيل / استكمال'),
                    ),
                  ),
                  if (_busy) ...<Widget>[
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'إيقاف مؤقت',
                      onPressed: widget.repository.cancelOfflinePack,
                      icon: const Icon(Icons.pause),
                    ),
                  ],
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'حذف الحزمة',
                    onPressed: _busy
                        ? null
                        : () => widget.repository.deleteOfflinePack(
                            widget.edition,
                          ),
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
