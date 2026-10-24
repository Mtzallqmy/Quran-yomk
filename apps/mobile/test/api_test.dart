import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tarteel/src/api.dart';

void main() {
  test('malformed JSON becomes a bounded API error', () async {
    for (final status in <int>[200, 503]) {
      for (final body in <String>['{broken', '', '[1,2]']) {
        final api = TarteelApiClient(
          client: MockClient(
            (_) async => http.Response(
              body,
              status,
              headers: <String, String>{'x-request-id': 'server-request'},
            ),
          ),
          baseUrl: 'https://example.test',
        );
        await expectLater(
          api.appConfig(),
          throwsA(
            isA<ApiException>()
                .having((e) => e.code, 'code', 'INVALID_RESPONSE')
                .having((e) => e.statusCode, 'status', status)
                .having((e) => e.requestId, 'request ID', 'server-request'),
          ),
        );
        api.close();
      }
    }
  });

  test('network failures never fabricate request IDs', () async {
    for (final error in <Exception>[
      http.ClientException('private-network-detail'),
      TimeoutException('private-timeout-detail'),
    ]) {
      var attempts = 0;
      final api = TarteelApiClient(
        client: MockClient((_) async {
          attempts++;
          throw error;
        }),
        baseUrl: 'https://example.test',
      );
      await expectLater(
        api.appConfig(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'NETWORK_UNAVAILABLE')
              .having((e) => e.requestId, 'request ID', isNull)
              .having((e) => e.message, 'message', isNot(contains('private'))),
        ),
      );
      expect(attempts, 2);
      api.close();
    }
  });

  test('surah contract requires exactly 114 ordered surahs', () async {
    final client = MockClient((request) async {
      final rows = List<Map<String, dynamic>>.generate(
        114,
        (index) => <String, dynamic>{
          'id': index + 1,
          'number': index + 1,
          'name_ar': 'سورة ${index + 1}',
          'name_en': 'Surah ${index + 1}',
          'ayah_count': 1,
        },
      );
      return http.Response(
        jsonEncode(<String, dynamic>{'data': rows}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final api = TarteelApiClient(
      client: client,
      baseUrl: 'https://example.test/api/v1',
    );
    final result = await api.surahs();
    expect(result, hasLength(114));
    expect(result.last.number, 114);
  });

  test('backend error shape becomes safe ApiException', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode(<String, dynamic>{
          'error': <String, dynamic>{
            'code': 'NOT_FOUND',
            'message': 'Missing',
            'request_id': '00000000-0000-4000-8000-000000000000',
          },
        }),
        404,
      ),
    );
    final api = TarteelApiClient(
      client: client,
      baseUrl: 'https://example.test/api/v1',
    );
    expect(() => api.station('missing'), throwsA(isA<ApiException>()));
  });
}
