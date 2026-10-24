import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html;
import '../content_catalog.dart';

class QuranTranslationsPane extends StatefulWidget {
  const QuranTranslationsPane({super.key, required this.surah});
  final int surah;
  @override
  State<QuranTranslationsPane> createState() => _QuranTranslationsPaneState();
}

class _QuranTranslationsPaneState extends State<QuranTranslationsPane> {
  final _api = ContentCatalogApi();
  Future<List<Map<String, dynamic>>>? _catalog;
  Future<Map<String, dynamic>>? _translation;
  String? _key;
  @override
  void didUpdateWidget(covariant QuranTranslationsPane old) {
    super.didUpdateWidget(old);
    if (old.surah != widget.surah && _key != null)
      _translation = _api.translation(_key!, widget.surah);
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  String _text(Object? value) => html.parseFragment('$value').text ?? '';
  @override
  Widget build(BuildContext context) => ExpansionTile(
    maintainState: true,
    onExpansionChanged: (expanded) {
      if (expanded && _catalog == null)
        setState(() => _catalog = _api.translations());
    },
    title: const Text('ترجمات معاني القرآن — QuranEnc'),
    subtitle: const Text(
      'اختيارية عبر الإنترنت؛ القراءة والحفظ لا يتوقفان عند تعذرها',
    ),
    children: [
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _catalog,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('تعذر تحميل الترجمات؛ إعادة المحاولة'),
              onPressed: () => setState(() => _catalog = _api.translations()),
            );
          if (snapshot.connectionState != ConnectionState.done ||
              !snapshot.hasData)
            return const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            );
          return Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              initialValue: _key,
              isExpanded: true,
              itemHeight: null,
              decoration: const InputDecoration(labelText: 'الترجمة واللغة'),
              items: [
                for (final r in snapshot.data!)
                  DropdownMenuItem(
                    value: (r['metadata'] as Map)['key'] as String,
                    child: Text(
                      '${r['language_code']} — ${r['title_ar']}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null)
                  setState(() {
                    _key = value;
                    _translation = _api.translation(value, widget.surah);
                  });
              },
            ),
          );
        },
      ),
      if (_translation != null)
        FutureBuilder<Map<String, dynamic>>(
          future: _translation,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'تعذرت الترجمة أو تغيّر إصدارها؛ اخترها مجددًا لاحقًا. النص القرآني محفوظ دون تغيير.',
                ),
              );
            if (snapshot.connectionState != ConnectionState.done ||
                !snapshot.hasData)
              return const LinearProgressIndicator();
            final data = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_text(data['title'])}\n${data['source']} • الإصدار ${data['version']}',
                  ),
                  SelectableText(_text(data['description'] ?? '')),
                  SelectableText('${data['sourceUrl']}\n${data['termsUrl']}'),
                  for (final v in data['verses'] as List)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('آية ${v['aya']}'),
                            SelectableText(_text(v['translation'])),
                            if ('${v['footnotes'] ?? ''}'.isNotEmpty)
                              SelectableText(
                                _text(v['footnotes']),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
    ],
  );
}
