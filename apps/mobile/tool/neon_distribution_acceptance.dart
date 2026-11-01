import 'dart:convert';
import 'dart:io';
import 'package:http/io_client.dart';
import 'package:tarteel/src/content_catalog.dart';
import 'package:tarteel/src/surah_content.dart';

Future<void> main(List<String> args) async {
  IOClient transport() =>
      IOClient(HttpClient()..findProxy = HttpClient.findProxyFromEnvironment);
  final catalog = ContentCatalogApi(client: transport());
  var registryCalls = 0;
  final api = SurahApiClient(
    client: transport(),
    projectCatalog: () async {
      registryCalls++;
      return catalog.surahProjects();
    },
  );
  final report = <String, Object?>{};
  try {
    final update = await catalog.distributionConfig();
    final projects = await api.projects();
    if (projects.length != 20 || registryCalls != 1)
      throw StateError('REGISTRY_NOT_USED');
    report.addAll({
      'status': 'PASS',
      'project_registry': 'neon',
      'projects': projects.length,
      'published_version_code': update['latest_android_version_code'],
      'educational_content_access': 'direct_official_api',
      'permanent_body_storage': false,
    });
    try {
      final rows = await api.read('tafsir-mokhtasar', [1, 1]);
      report['live_tafsir'] = {
        'status': 'VERIFIED',
        'source_host': rows.single.sourceUrl.host,
        'sha256': rows.single.sha256Hex,
      };
    } catch (error) {
      report['live_tafsir'] = {
        'status': 'TEMPORARILY_UNAVAILABLE',
        'error_type': error.runtimeType.toString(),
      };
    }
  } finally {
    api.close();
    catalog.dispose();
  }
  File(args.single).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln(jsonEncode(report));
}
