import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../services.dart';

class ContentSourcesPage extends ConsumerWidget {
  const ContentSourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('مصادر المحتوى وحقوق النشر')),
      body: FutureBuilder<List<ContentSource>>(
        future: services.repository.api.contentSources(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const LoadingPane();
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return ErrorPane(
              error: snapshot.error!,
              onRetry: () =>
                  services.repository.api.contentSources(),
            );
          }

          final sources = snapshot.data ?? const <ContentSource>[];
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'يتيح ترتيل الوصول إلى بعض الإذاعات والمصادر الصوتية الخارجية من خلال خدمات ومصادر البث الخاصة بمقدميها. تبقى حقوق المحتوى والعلامات والمصادر الصوتية لأصحابها. لا يدّعي ترتيل ملكية محتوى الطرف الثالث أو اعتماده من الجهات المشغلة.',
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'عند تشغيل محطة خارجية قد يتصل جهازك مباشرة ببنية مزود البث. تحفظ بيانات المصدر والترخيص وحالة الحقوق داخليًا لأغراض التدقيق والامتثال.',
                ),
              ),
              if (sources.isEmpty)
                const EmptyPane(message: 'لا توجد مصادر مسجلة حاليًا')
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
                        title: 'أساس التكامل',
                        value: source.integrationBasis,
                      ),
                      _InfoTile(
                        title: 'نوع الترخيص أو الإذن',
                        value: source.licenseType,
                      ),
                      _InfoTile(
                        title: 'حالة الاستخدام التجاري',
                        value: source.commercialUseStatus,
                      ),
                      _InfoTile(
                        title: 'طريقة التوزيع',
                        value: source.redistributionMode,
                      ),
                      _InfoTile(
                        title: 'المصدر',
                        value: source.providerUrl ?? source.sourceUrl,
                      ),
                      _InfoTile(
                        title: 'مرجع الشروط',
                        value: source.termsUrl,
                      ),
                      _InfoTile(
                        title: 'مرجع الترخيص',
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
