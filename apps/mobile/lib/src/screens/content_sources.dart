import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
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
            return const LoadingPane();
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return ErrorPane(
              error: snapshot.error!,
              onRetry: () => services.repository.api.contentSources(),
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
