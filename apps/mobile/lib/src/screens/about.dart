import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../branding.dart';
import '../common.dart';
import '../models.dart';
import '../services.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('حول التطبيق')),
      body: ListView(
        children: <Widget>[
          const SizedBox(height: 18),
          const Center(child: TarteelBrandMark(size: 88)),
          const SizedBox(height: 12),
          Text(
            'ترتيل — Tarteel',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text(
            'الإصدار 0.1.0 (1)',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.source_outlined),
            title: const Text('مصادر المحتوى وحقوق النشر'),
            subtitle: const Text('المصادر الخارجية، الإسناد، والشروط المرتبطة بها'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ContentSourcesRightsPage(),
              ),
            ),
          ),
          FutureBuilder<JsonMap>(
            future: services.repository.appConfig(),
            builder: (context, snapshot) {
              final config = snapshot.data ?? const <String, dynamic>{};
              return Column(
                children: <Widget>[
                  _LegalTile(title: 'سياسة الخصوصية', value: config['privacy_url']),
                  _LegalTile(title: 'الشروط', value: config['terms_url']),
                  _LegalTile(title: 'الدعم', value: config['support_url']),
                ],
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'ترتيل لا يدّعي ملكية الإذاعات أو التلاوات أو العلامات الخاصة بالمصادر الخارجية. عند تشغيل محطة خارجية قد يتصل جهازك مباشرةً ببنية مقدم البث.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class ContentSourcesRightsPage extends ConsumerWidget {
  const ContentSourcesRightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('مصادر المحتوى وحقوق النشر')),
      body: FutureBuilder<List<ContentSource>>(
        future: services.repository.api.contentSources(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
            return const LoadingPane();
          }
          if (snapshot.hasError) {
            return ErrorPane(
              error: snapshot.error!,
              onRetry: () => (context as Element).markNeedsBuild(),
            );
          }
          final sources = snapshot.data ?? const <ContentSource>[];
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'يتيح ترتيل الوصول إلى بعض الإذاعات والمصادر الصوتية الخارجية من خلال خدمات مقدميها. تبقى حقوق المحتوى والعلامات الخاصة بكل مصدر لأصحابها، ولا يعني إدراج المصدر وجود تأييد أو ملكية من ترتيل.',
                ),
              ),
              if (sources.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لا توجد مصادر موثقة متاحة حاليًا.'),
                )
              else
                for (final source in sources)
                  ExpansionTile(
                    leading: const Icon(Icons.source_outlined),
                    title: Text(source.providerName),
                    subtitle: source.attribution == null
                        ? null
                        : Text(source.attribution!),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: <Widget>[
                      _SourceRow(label: 'أساس التكامل', value: source.integrationBasis),
                      _SourceRow(label: 'نوع الإذن/الترخيص', value: source.licenseType),
                      _SourceRow(label: 'الاستخدام التجاري', value: source.commercialUseStatus),
                      _SourceRow(label: 'طريقة التوزيع', value: source.redistributionMode),
                      _SourceRow(label: 'المصدر', value: source.providerUrl),
                      _SourceRow(label: 'الشروط/المرجع', value: source.termsUrl),
                    ],
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(value!)),
        ],
      ),
    );
  }
}

class _LegalTile extends StatelessWidget {
  const _LegalTile({required this.title, required this.value});

  final String title;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    final url = value is String && (value as String).isNotEmpty ? value as String : null;
    return ListTile(
      leading: const Icon(Icons.description_outlined),
      title: Text(title),
      subtitle: Text(url ?? 'غير متوفر حاليًا'),
      enabled: false,
    );
  }
}
