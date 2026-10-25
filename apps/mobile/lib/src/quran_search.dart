String normalizeQuranQuery(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ؤ', 'و')
    .replaceAll('ئ', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp('[\\u064B-\\u065F\\u0670\\u0640]'), '')
    .replaceAllMapped(
      RegExp('[٠-٩]'),
      (match) => '${'٠١٢٣٤٥٦٧٨٩'.indexOf(match[0]!)}',
    );
