import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Arabic app rights copy is present exactly', () async {
    final raw = await File('lib/l10n/app_ar.arb').readAsString();
    final json = jsonDecode(raw) as Map<String, dynamic>;

    expect(json['appRights'], 'حقوق التطبيق');
    expect(json['appRightsLine1'], 'ترتيل — Tarteel');
    expect(json['appRightsLine2'], 'تطوير وملكية: معتز العلقمي');
    expect(json['appRightsLine3'], 'تعز، اليمن');
    expect(
      json['appRightsLine4'],
      '© 2026 معتز العلقمي. جميع حقوق التطبيق محفوظة.',
    );
    expect(json['thirdPartyRights'], 'مصادر المحتوى وحقوق الجهات الخارجية');
  });

  test('sleep timer exposes all accepted choices', () async {
    final raw = await File('lib/l10n/app_ar.arb').readAsString();
    final json = jsonDecode(raw) as Map<String, dynamic>;

    expect(json['minutes10'], '10 دقائق');
    expect(json['minutes20'], '20 دقيقة');
    expect(json['minutes30'], '30 دقيقة');
    expect(json['minutes45'], '45 دقيقة');
    expect(json['minutes60'], '60 دقيقة');
    expect(json['endOfCurrentRecitation'], 'نهاية التلاوة الحالية');
    expect(json['cancelSleepTimer'], 'إلغاء مؤقت النوم');
  });
}
