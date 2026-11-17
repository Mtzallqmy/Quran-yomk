import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bundled documents remain available without runtime configuration or a network.
class LegalPage extends StatefulWidget {
  const LegalPage({super.key, required this.documentId});
  final String documentId;

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  late Future<Map<String, dynamic>> _document = _load();

  Future<Map<String, dynamic>> _load() async {
    final source = await rootBundle.loadString('assets/legal/documents.json');
    return (jsonDecode(source) as List).cast<Map<String, dynamic>>().firstWhere(
      (document) => document['id'] == widget.documentId,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الخصوصية والشروط')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _document,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _document = _load()),
              child: const Text('تعذر فتح الوثيقة. إعادة المحاولة'),
            ),
          );
        }
        final document = snapshot.data;
        if (document == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SelectionArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          widget.documentId == 'privacy'
                              ? Icons.shield_outlined
                              : Icons.description_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          document['title'] as String,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text('آخر تحديث: ${document['updated']}'),
                        const Divider(height: 32),
                        for (final section in document['sections'] as List) ...[
                          Semantics(
                            header: true,
                            child: Text(
                              section['title'] as String,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(section['body'] as String),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
