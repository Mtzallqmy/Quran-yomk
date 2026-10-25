import 'dart:convert';
import 'dart:io';
import 'package:http/io_client.dart';
import 'package:tarteel/src/surah_content.dart';

Future<void> main(List<String> args) async {
  final transport = HttpClient()
    ..findProxy = HttpClient.findProxyFromEnvironment;
  final api = SurahApiClient(client: IOClient(transport));
  final report = <String, Object?>{};
  try {
    final projects = await api.projects();
    report['projects'] = projects.length;
    for (final item in <String, List<int>>{
      'tafsir-mokhtasar': [1, 1],
      'fawaed-page': [1],
      'eerab-word': [1, 1, 1],
      'asmaa-sowar': [91],
    }.entries) {
      try {
        final rows = await api.read(item.key, item.value);
        report[item.key] = {
          'status': 'VERIFIED',
          'rows': rows.length,
          'hashes': rows.map((e) => e.sha256Hex).toList(),
        };
      } catch (e) {
        report[item.key] = {
          'status': 'UNAVAILABLE',
          'error': e.runtimeType.toString(),
        };
      }
    }
  } catch (e) {
    report['catalog'] = 'UNAVAILABLE';
    report['error'] = e.runtimeType.toString();
  } finally {
    api.close();
  }
  File(args.single).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln(jsonEncode(report));
}
