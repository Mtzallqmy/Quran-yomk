import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../branding.dart';
import '../l10n.dart';
import '../models.dart';
import '../services.dart';
import 'content_sources.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final services = ref.watch(servicesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: <Widget>[
          const SizedBox(height: 18),
          const Center(child: TarteelBrandMark(size: 88)),
          const SizedBox(height: 12),
          Text(
            l10n.appRightsLine1,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(l10n.versionLabel('0.3.0 (3)'), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.copyright_outlined),
                        const SizedBox(width: 10),
                        Text(
                          l10n.appRights,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SelectableText(l10n.appRightsLine1),
                    const SizedBox(height: 6),
                    SelectableText(l10n.appRightsLine2),
                    const SizedBox(height: 6),
                    SelectableText(l10n.appRightsLine3),
                    const SizedBox(height: 6),
                    SelectableText(l10n.appRightsLine4),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.source_outlined),
            title: Text(l10n.thirdPartyRights),
            subtitle: Text(l10n.contentSourcesSubtitle),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ContentSourcesPage(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              l10n.thirdPartyOwnershipNotice,
              textAlign: TextAlign.start,
            ),
          ),
          FutureBuilder<JsonMap>(
            future: services.repository.appConfig(),
            builder: (context, snapshot) {
              final config = snapshot.data ?? const <String, dynamic>{};
              return Column(
                children: <Widget>[
                  _LegalTile(
                    title: l10n.privacyPolicy,
                    value: config['privacy_url'],
                    unavailable: l10n.notAvailable,
                  ),
                  _LegalTile(
                    title: l10n.terms,
                    value: config['terms_url'],
                    unavailable: l10n.notAvailable,
                  ),
                  _LegalTile(
                    title: l10n.support,
                    value: config['support_url'],
                    unavailable: l10n.notAvailable,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LegalTile extends StatelessWidget {
  const _LegalTile({
    required this.title,
    required this.value,
    required this.unavailable,
  });

  final String title;
  final dynamic value;
  final String unavailable;

  @override
  Widget build(BuildContext context) {
    final url = value is String && (value as String).isNotEmpty
        ? value as String
        : null;
    return ListTile(
      leading: const Icon(Icons.description_outlined),
      title: Text(title),
      subtitle: Text(url ?? unavailable),
      enabled: false,
    );
  }
}
