import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../branding.dart';
import '../models.dart';
import '../services.dart';
import 'content_sources.dart';

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
          const Text('الإصدار 0.1.0 (1)', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.source_outlined),
            title: const Text('مصادر المحتوى وحقوق النشر'),
            subtitle: const Text(
              'المصادر الخارجية، نسب المحتوى، والشروط المرتبطة بها',
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ContentSourcesPage(),
              ),
            ),
          ),
          FutureBuilder<JsonMap>(
            future: services.repository.appConfig(),
            builder: (context, snapshot) {
              final config = snapshot.data ?? const <String, dynamic>{};
              return Column(
                children: <Widget>[
                  _LegalTile(
                    title: 'سياسة الخصوصية',
                    value: config['privacy_url'],
                  ),
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

class _LegalTile extends StatelessWidget {
  const _LegalTile({required this.title, required this.value});

  final String title;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    final url = value is String && (value as String).isNotEmpty
        ? value as String
        : null;
    return ListTile(
      leading: const Icon(Icons.description_outlined),
      title: Text(title),
      subtitle: Text(url ?? 'غير متوفر حاليًا'),
      enabled: false,
    );
  }
}
