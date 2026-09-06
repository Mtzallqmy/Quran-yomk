import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/models.dart';
import 'package:tarteel/src/quran_audio.dart';
import 'package:tarteel/src/quran_download_contract.dart';
import 'package:tarteel/src/quran_download_service_io.dart' as io;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('quran-http-test');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => root.path);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
    await root.delete(recursive: true);
  });

  for (final mode in <String>[
    'stalled',
    'trickle',
    'headers',
    'redirect',
    'success',
  ]) {
    test('download HTTP $mode releases resources', () async {
      var cancelled = false;
      Timer? timer;
      late StreamController<List<int>> body;
      body = StreamController<List<int>>(
        onListen: () {
          if (mode == 'success') {
            body.add(List<int>.filled(4096, 1));
            unawaited(body.close());
          } else if (mode == 'trickle') {
            timer = Timer.periodic(const Duration(milliseconds: 5), (_) {
              body.add(<int>[1]);
            });
          }
        },
        onCancel: () {
          cancelled = true;
          timer?.cancel();
        },
      );
      addTearDown(() {
        timer?.cancel();
        unawaited(body.close());
      });
      final response = _Response(body.stream, mode == 'redirect' ? 302 : 200);
      final request = _Request(response, stall: mode == 'headers');
      final client = _Client(request);
      await HttpOverrides.runZoned(() async {
        final service = io.createQuranDownloadService(
          await SharedPreferences.getInstance(),
          inactivityTimeout: Duration(
            milliseconds: mode == 'stalled' ? 40 : 1000,
          ),
          downloadDeadline: Duration(
            milliseconds: mode == 'trickle' || mode == 'headers' ? 150 : 2000,
          ),
        );
        final finished = Completer<QuranDownloadTask>();
        service.addListener(() {
          final task = service.tasks.isEmpty ? null : service.tasks.first;
          if (task != null &&
              <QuranDownloadState>{
                QuranDownloadState.failed,
                QuranDownloadState.completed,
              }.contains(task.state) &&
              !finished.isCompleted) {
            finished.complete(task);
          }
        });
        await service.download(_media());
        final result = await finished.future.timeout(
          const Duration(seconds: 5),
        );
        expect(request.followRedirects, isFalse);
        expect(client.forcedClosed, isTrue);
        expect(client.requests, 1);
        expect(await File('${result.localPath}.part').exists(), isFalse);
        if (mode == 'success') {
          expect(result.state, QuranDownloadState.completed);
          expect(await File(result.localPath!).length(), 4096);
        } else {
          expect(result.state, QuranDownloadState.failed);
          expect(await File(result.localPath!).exists(), isFalse);
          if (mode != 'redirect') {
            expect(result.error, 'QURAN_DOWNLOAD_TIMEOUT');
          }
        }
        if (mode == 'stalled' || mode == 'trickle') {
          expect(cancelled, isTrue);
        }
        service.dispose();
      }, createHttpClient: (_) => client);
    });
  }
}

QuranAudioMedia _media() => QuranAudioMedia(
  id: 'track-1',
  provider: QuranAudioProviderKind.mp3Quran,
  reciter: const QuranAudioCatalogReciter(
    id: 'mp3quran:10:20',
    provider: QuranAudioProviderKind.mp3Quran,
    edition: '10-20',
    nameAr: 'قارئ',
    nameEn: 'Reciter',
    availableSurahs: <int>{1},
    bitrates: <int>{},
  ),
  surah: const Surah(
    id: 1,
    number: 1,
    nameAr: 'الفاتحة',
    nameEn: 'Al-Fatihah',
    ayahCount: 7,
  ),
  bitrateKbps: 0,
  playbackUri: Uri.parse('https://audio.example.test/001.mp3'),
  downloadUri: Uri.parse('https://audio.example.test/001.mp3'),
  rightsStatus: 'DOCUMENTED_DIRECT_EXTERNAL',
  rehostingAllowed: false,
);

class _Headers implements HttpHeaders {
  @override
  ContentType? get contentType => ContentType('audio', 'mpeg');
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.response, {required this.stall});
  final HttpClientResponse response;
  final bool stall;
  @override
  bool followRedirects = true;
  @override
  final HttpHeaders headers = _Headers();
  @override
  Future<HttpClientResponse> close() =>
      stall ? Completer<HttpClientResponse>().future : Future.value(response);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements HttpClient {
  _Client(this.request);
  final HttpClientRequest request;
  bool forcedClosed = false;
  int requests = 0;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests++;
    return request;
  }

  @override
  void close({bool force = false}) {
    forcedClosed = force;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.body, this.statusCode);
  final Stream<List<int>> body;
  @override
  final int statusCode;
  @override
  int get contentLength => -1;
  @override
  HttpHeaders get headers => _Headers();
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => body.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
