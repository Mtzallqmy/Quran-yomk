import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../adhan_library.dart';
import '../islamic_content.dart';
import '../l10n.dart';
import '../models.dart';
import '../services.dart';

class ContentSourcesPage extends ConsumerWidget {
  const ContentSourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final services = ref.watch(servicesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.thirdPartyRights)),
      body: FutureBuilder<List<ContentSource>>(
        future: services.repository.api.contentSources(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return ListView(
              children: const [
                BundledAudioSources(),
                SizedBox(height: 80, child: LoadingPane()),
              ],
            );
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: <Widget>[
                const BundledAudioSources(),
                const _IslamicLibrarySource(),
                ErrorPane(
                  error: snapshot.error!,
                  onRetry: () => services.repository.api.contentSources(),
                ),
              ],
            );
          }

          final sources = snapshot.data ?? const <ContentSource>[];
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(l10n.externalSourceDisclaimer),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(l10n.thirdPartyOwnershipNotice),
              ),
              const BundledAudioSources(),
              const _IslamicLibrarySource(),
              if (sources.isEmpty)
                EmptyPane(message: l10n.contentSourceUnavailable)
              else
                for (final source in sources)
                  ExpansionTile(
                    leading: const Icon(Icons.source_outlined),
                    title: Text(source.providerName),
                    subtitle: source.attribution == null
                        ? null
                        : Text(source.attribution!),
                    children: <Widget>[
                      _InfoTile(
                        title: _label(context, 'integration'),
                        value: source.integrationBasis,
                      ),
                      _InfoTile(
                        title: _label(context, 'license'),
                        value: source.licenseType,
                      ),
                      _InfoTile(
                        title: _label(context, 'commercial'),
                        value: source.commercialUseStatus,
                      ),
                      _InfoTile(
                        title: _label(context, 'distribution'),
                        value: source.redistributionMode,
                      ),
                      _InfoTile(
                        title: _label(context, 'source'),
                        value: source.providerUrl ?? source.sourceUrl,
                      ),
                      _InfoTile(
                        title: _label(context, 'terms'),
                        value: source.termsUrl,
                      ),
                      _InfoTile(
                        title: _label(context, 'licenseRef'),
                        value: source.licenseUrl,
                      ),
                    ],
                  ),
            ],
          );
        },
      ),
    );
  }

  String _label(BuildContext context, String key) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    return switch (key) {
      'integration' => english ? 'Integration basis' : 'أساس التكامل',
      'license' => english ? 'License / permission' : 'نوع الترخيص أو الإذن',
      'commercial' => english ? 'Commercial use' : 'حالة الاستخدام التجاري',
      'distribution' => english ? 'Distribution mode' : 'طريقة التوزيع',
      'source' => english ? 'Source' : 'المصدر',
      'terms' => english ? 'Terms reference' : 'مرجع الشروط',
      _ => english ? 'License reference' : 'مرجع الترخيص',
    };
  }
}

class _IslamicLibrarySource extends StatelessWidget {
  const _IslamicLibrarySource();

  @override
  Widget build(BuildContext context) => const ExpansionTile(
    initiallyExpanded: true,
    leading: Icon(Icons.local_library_outlined),
    title: Text('Islamic Library Data — Open Source Islamic Dataset'),
    subtitle: Text('المصدر الرئيسي لطبقة المحتوى الإسلامي المحلية'),
    children: <Widget>[
      _InfoTile(title: 'المصدر', value: islamicLibraryRepositoryUrl),
      _InfoTile(title: 'إصدار البيانات المثبت', value: islamicLibraryRevision),
      _InfoTile(
        title: 'طريقة التوزيع',
        value: 'CDN مباشر → تخزين الجهاز؛ لا إعادة استضافة عامة عبر Supabase',
      ),
      _InfoTile(
        title: 'الترخيص والإسناد',
        value:
            'يُحتفظ بترخيص وإسناد كل نص أو ترجمة أو خط أو ملف صوتي على حدة. لا يُعامل توفر الملف في المستودع كترخيص موحد.',
      ),
    ],
  );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.title, required this.value});

  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return ListTile(
      dense: true,
      title: Text(title),
      subtitle: SelectableText(value!),
    );
  }
}

class BundledAudioSources extends StatelessWidget {
  const BundledAudioSources({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'مصادر الأصوات والخلفيات المرفقة — متاحة دون إنترنت. ذكر المؤلف لا يعني تأييده للتطبيق.',
        ),
      ),
      for (final sound in builtInAdhanSounds)
        ExpansionTile(
          leading: const Icon(Icons.library_music_outlined),
          title: Text(sound.nameAr),
          subtitle: Text(sound.descriptionAr),
          children: [
            _InfoTile(title: 'صاحب التسجيل أو المؤلف', value: sound.author),
            _InfoTile(title: 'المصدر الأصلي', value: sound.sourceUrl),
            if (sound.id.startsWith('user-'))
              const _InfoTile(
                title: 'إذن الاستخدام',
                value:
                    'ملف قدمه صاحب المشروع مع تصريح بالسماح باستخدامه في ترتيل. المصدر حسب الملف المرفق: PrayTimes. حقوق التسجيل لأصحابه؛ لا ينسب إلى ترخيص Creative Commons.',
              ),
            _InfoTile(title: 'رابط الترخيص', value: sound.licenseUrl),
            if (sound.id == 'built-in-makkah' ||
                sound.id == 'built-in-madinah' ||
                sound.id == 'built-in-kazakhstan' ||
                sound.id == 'built-in-sweden-fajr')
              const _InfoTile(
                title: 'التعديلات على الصوت',
                value:
                    'استخراج الصوت وتحويله إلى Ogg Vorbis أحادي القناة 44.1 kHz وضبط جهارته إلى ‎-18 LUFS. لم تُحذف عبارات عمدًا. النسخة المعدلة موزعة بترخيص التسجيل الموضح أعلاه.',
              ),
          ],
        ),
      const ExpansionTile(
        leading: Icon(Icons.radio_outlined),
        title: Text('فهرس الإذاعات الإضافية'),
        children: [
          _InfoTile(title: 'المصدر', value: 'https://www.mp3quran.net/eng/api'),
          _InfoTile(
            title: 'طريقة الاستخدام',
            value:
                'روابط البث من API العام؛ حقوق المحطات والأصوات لأصحابها. يحفظ Neon بيانات الفهرس فقط، ولا يعيد استضافة البث ولا يمنح إذن تسجيله.',
          ),
        ],
      ),
      const ListTile(
        leading: Icon(Icons.palette_outlined),
        title: Text('خلفيات المشغّل والإذاعات'),
        subtitle: Text(
          'رسوم هندسية ومتجهية أصلية داخل مشروع ترتيل؛ تعمل محليًا دون تحميل صور.',
        ),
      ),
    ],
  );
}
