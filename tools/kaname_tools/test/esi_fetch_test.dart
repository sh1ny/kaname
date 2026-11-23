import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kaname_tools/kaname_tools.dart';
import 'package:test/test.dart';

import 'support/esi_fixtures.dart';
import 'support/harness.dart';
import 'support/in_memory_file_system.dart';

/// Answers every download with [answer] and records what was asked.
final class _FakeDownloader implements EsiDownloader {
  _FakeDownloader(this.answer);

  _FakeDownloader.serving(String body)
    : answer = EsiDownloaded(200, utf8.encode(body));

  final EsiDownload answer;
  final List<(Uri, Map<String, String>)> calls = [];

  @override
  Future<EsiDownload> download(Uri url, Map<String, String> headers) async {
    calls.add((url, headers));
    return answer;
  }
}

/// The fixture with a changed description: same date, another hash.
String _otherSnapshot() {
  final document = esiFixture();
  (document['info']! as Map<String, Object?>)['title'] = 'Another fixture';
  return jsonEncode(document);
}

Map<String, String> _contents(InMemoryFileSystem fs) => {
  for (final path in fs.filePaths) path: fs.readAsString(path),
};

void main() {
  // Scenario: Fetch a listed date. Scenario: Re-read passes.
  test('fetch writes snapshot and pin for the served date, leaving no '
      'temporary file', () async {
    final fs = InMemoryFileSystem();
    final downloader = _FakeDownloader.serving(esiFixtureText());
    final result = await runTool(fs, [
      'esi',
      'fetch',
      '--date',
      esiFixtureDate,
    ], esiDownloader: downloader);

    expect(result.code, exitSuccess, reason: result.err);
    final (url, headers) = downloader.calls.single;
    expect(url, esiSpecUrl(esiFixtureDate));
    expect(headers, {'X-Compatibility-Date': esiFixtureDate});
    expect(fs.filePaths, [esiSnapshotPath, esiPinPath]);
    expect(fs.readAsString(esiSnapshotPath), esiFixtureText());
    final (:pin, :problems) = parseEsiPin(fs.readAsString(esiPinPath));
    expect(problems, isEmpty);
    expect(pin?.date, esiFixtureDate);
    expect(pin?.source, esiSpecUrl(esiFixtureDate).toString());
    expect(pin?.sha256, esiSha256(esiFixtureText()));
    expect(loadEsiSnapshot(fs), isA<EsiSnapshotLoaded>());
  });

  test('no CI workflow runs the fetch', () {
    final root = RealFileSystem.locate(Directory.current.path)!;
    for (final entry in root.list('.github/workflows')) {
      final text = root.readAsString('.github/workflows/${entry.name}');
      expect(text, isNot(contains('esi:fetch')), reason: entry.name);
      expect(text, isNot(contains('esi fetch')), reason: entry.name);
    }
  });

  test('the source URL asks for the date', () {
    expect(
      esiSpecUrl('2030-01-02').toString(),
      'https://esi.evetech.net/meta/openapi.json?compatibility_date=2030-01-02',
    );
  });

  // Scenario: Spec reports another date.
  test(
    'fetch refuses a spec reporting another date and changes nothing',
    () async {
      final fs = esiRepository(snapshot: _otherSnapshot());
      final before = _contents(fs);
      final result = await runTool(fs, [
        'esi',
        'fetch',
        '--date',
        '2030-01-03',
      ], esiDownloader: _FakeDownloader.serving(esiFixtureText()));
      expect(result.code, exitCheckFailed);
      expect(result.err, contains('2030-01-03'));
      expect(result.err, contains('info.version 2030-01-02'));
      expect(result.err, contains('X-Compatibility-Date enum 2030-01-02'));
      expect(_contents(fs), before);
      expect(fs.writeCount, 0);
    },
  );

  // Scenario: Download fails.
  for (final (name, answer, message) in [
    (
      'an error',
      const EsiDownloadFailed('connection refused'),
      'failed: connection refused',
    ),
    (
      'a timeout',
      const EsiDownloadFailed('timed out after 60 s'),
      'failed: timed out after 60 s',
    ),
    ('a non-200 status', EsiDownloaded(503, Uint8List(0)), 'returned HTTP 503'),
  ]) {
    test('fetch reports $name and changes nothing', () async {
      final fs = esiRepository();
      final before = _contents(fs);
      final result = await runTool(fs, [
        'esi',
        'fetch',
        '--date',
        esiFixtureDate,
      ], esiDownloader: _FakeDownloader(answer));
      expect(result.code, exitCheckFailed);
      expect(result.err, contains(message));
      expect(_contents(fs), before);
      expect(fs.writeCount, 0);
    });
  }

  test('fetch refuses a body with CR line endings', () async {
    final fs = InMemoryFileSystem();
    final result = await runTool(
      fs,
      ['esi', 'fetch', '--date', esiFixtureDate],
      esiDownloader: _FakeDownloader.serving(
        esiFixtureText().replaceAll('\n', '\r\n'),
      ),
    );
    expect(result.code, exitCheckFailed);
    expect(result.err, contains('CR line endings'));
    expect(fs.filePaths, isEmpty);
  });

  test('fetch refuses a body that starts with a byte order mark', () async {
    final fs = InMemoryFileSystem();
    final result = await runTool(
      fs,
      ['esi', 'fetch', '--date', esiFixtureDate],
      esiDownloader: _FakeDownloader(
        EsiDownloaded(
          200,
          Uint8List.fromList([
            0xEF,
            0xBB,
            0xBF,
            ...utf8.encode(esiFixtureText()),
          ]),
        ),
      ),
    );
    expect(result.code, exitCheckFailed);
    expect(result.err, contains('byte order mark'));
    expect(fs.filePaths, isEmpty);
  });

  // Scenario: Bad date argument.
  for (final args in [
    <String>[],
    ['--date', '2030-1-2'],
    ['--date', 'tomorrow'],
  ]) {
    test('fetch with ${args.isEmpty ? 'no date' : args.last} prints usage '
        'and downloads nothing', () async {
      final downloader = _FakeDownloader.serving(esiFixtureText());
      final fs = InMemoryFileSystem();
      final result = await runTool(fs, [
        'esi',
        'fetch',
        ...args,
      ], esiDownloader: downloader);
      expect(result.code, exitUsage);
      expect(result.err, contains('Pass --date as YYYY-MM-DD.'));
      expect(result.err, contains('Usage:'));
      expect(downloader.calls, isEmpty);
      expect(fs.filePaths, isEmpty);
    });
  }

  // Scenario: Two fetches interleave in one checkout.
  test('interleaved fetches with different hashes fail the late pin writer '
      'and the check', () async {
    final fs = InMemoryFileSystem();
    final fetchB = EsiFetcher(
      fs,
      _FakeDownloader.serving(_otherSnapshot()),
      uniqueToken: () => 'b',
    );
    EsiFetchResult? resultB;
    final fetchA = EsiFetcher(
      fs,
      _FakeDownloader.serving(esiFixtureText()),
      uniqueToken: () => 'a',
      onStep: (step) async {
        if (step == EsiFetchStep.snapshotInPlace) {
          resultB = await fetchB.fetch(esiFixtureDate);
        }
      },
    );

    final resultA = await fetchA.fetch(esiFixtureDate);

    expect(resultB, isA<EsiFetched>());
    expect(
      resultA,
      isA<EsiFetchFailed>()
          .having((r) => r.wroteFiles, 'wroteFiles', isTrue)
          .having(
            (r) => r.problems,
            'problems',
            contains(
              startsWith("$esiSnapshotPath does not match the pin's hash"),
            ),
          ),
    );
    expect(fs.filePaths, [esiSnapshotPath, esiPinPath]);
    expect(
      loadEsiSnapshot(fs),
      isA<EsiSnapshotRefused>().having(
        (r) => r.problems.single,
        'problem',
        startsWith("$esiSnapshotPath does not match the pin's hash"),
      ),
    );
  });

  group('HttpEsiDownloader over a loopback server', () {
    late HttpServer server;
    late Uri url;
    late Future<void> Function(HttpRequest request) handle;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      url = Uri.http('127.0.0.1:${server.port}', '/meta/openapi.json');
      server.listen((request) => handle(request));
    });
    tearDown(() => server.close(force: true));

    test('returns the status, the body and sends the headers', () async {
      String? seen;
      handle = (request) async {
        seen = request.headers.value('X-Compatibility-Date');
        request.response.write('{"a":1}');
        await request.response.close();
      };
      final download = await const HttpEsiDownloader().download(url, {
        'X-Compatibility-Date': '2030-01-02',
      });
      expect(seen, '2030-01-02');
      expect(
        download,
        isA<EsiDownloaded>()
            .having((d) => d.status, 'status', 200)
            .having((d) => utf8.decode(d.bytes), 'body', '{"a":1}'),
      );
    });

    test('reports a non-200 status', () async {
      handle = (request) async {
        request.response.statusCode = 404;
        await request.response.close();
      };
      final download = await const HttpEsiDownloader().download(url, {});
      expect(download, isA<EsiDownloaded>().having((d) => d.status, 's', 404));
    });

    test('gives up past the size limit', () async {
      handle = (request) async {
        request.response.add(Uint8List(64));
        await request.response.close();
      };
      final download = await const HttpEsiDownloader(maxBytes: 16)
          .download(url, {});
      expect(
        download,
        isA<EsiDownloadFailed>().having(
          (d) => d.reason,
          'reason',
          contains('larger than 16 bytes'),
        ),
      );
    });

    test('gives up after the time limit', () async {
      final release = Completer<void>();
      handle = (request) async {
        await release.future;
        await request.response.close();
      };
      final download = await const HttpEsiDownloader(
        timeout: Duration(milliseconds: 200),
      ).download(url, {});
      release.complete();
      expect(
        download,
        isA<EsiDownloadFailed>().having(
          (d) => d.reason,
          'reason',
          'timed out after 200 ms',
        ),
      );
    });
  });
}
