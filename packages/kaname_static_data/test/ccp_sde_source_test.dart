import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:test/test.dart';

import 'support/fake_http.dart';

const int _build = 4242;

String _latest(int build) =>
    '{"_key": "sde", "buildNumber": $build, "releaseDate": "2026-01-01T00:00:00Z"}\n';

void main() {
  late Directory scratch;

  setUp(
    () => scratch = Directory.systemTemp.createTempSync('kaname_ccp_test_'),
  );
  tearDown(() => scratch.deleteSync(recursive: true));

  CcpSdeSource sourceFor(
    FakeHttpClient client, {
    SdeLimits limits = const SdeLimits(),
  }) => CcpSdeSource(
    client: client,
    baseUrl: Uri.parse('https://sde.example.test/static-data/'),
    limits: limits,
    scratchRoot: scratch,
  );

  Future<String> reasonOf(Future<Object?> Function() action) async {
    try {
      await action();
    } on SdeSourceException catch (e) {
      return e.reason;
    }
    fail('expected an SdeSourceException');
  }

  final zip = buildZip({
    'types.jsonl': [
      {'_key': 1, 'name': 'a'},
      {'_key': 2, 'name': 'b'},
    ],
    '_sde.jsonl': [
      {'_key': 'sde', 'buildNumber': _build},
    ],
  });

  group('CcpSdeSource', () {
    test('reads latest.jsonl and downloads that build', () async {
      final client = FakeHttpClient((request) async {
        return switch (request.url.path) {
          '/static-data/latest.jsonl' => bytesResponse(
            utf8.encode(_latest(_build)),
          ),
          '/static-data/eve-online-static-data-$_build-jsonl.zip' =>
            bytesResponse(zip),
          _ => bytesResponse(const [], status: 404),
        };
      });
      final source = sourceFor(client);

      expect(source.kind, SdeSourceKind.ccp);
      expect(await source.announcedBuild(), _build);
      final archive = await source.open();
      addTearDown(archive.close);

      expect(archive.fileNames, ['_sde.jsonl', 'types.jsonl']);
      final lines = await archive.lines('types.jsonl').toList();
      expect(lines.map((l) => (l as SdeTextLine).text), [
        '{"_key":1,"name":"a"}',
        '{"_key":2,"name":"b"}',
      ]);
      // latest.jsonl is read once, then the zip of exactly that build.
      expect(client.requested.map((u) => u.pathSegments.last), [
        'latest.jsonl',
        'eve-online-static-data-$_build-jsonl.zip',
      ]);

      await archive.close();
      expect(scratch.listSync(), isEmpty, reason: 'temp directory deleted');
    });

    test('unreachable, cut-off and corrupt sources fail with reason', () async {
      // CCP cannot be reached.
      var client = FakeHttpClient(
        (_) async => throw const SocketException('network is unreachable'),
      );
      expect(
        await reasonOf(() => sourceFor(client).announcedBuild()),
        allOf(contains('CCP unreachable'), contains('network is unreachable')),
      );

      // CCP answers with an error status.
      client = FakeHttpClient(
        (_) async => bytesResponse(const [], status: 503),
      );
      expect(
        await reasonOf(() => sourceFor(client).announcedBuild()),
        allOf(contains('CCP'), contains('503')),
      );

      // latest.jsonl is not what it should be.
      client = FakeHttpClient(
        (_) async => bytesResponse(utf8.encode('not json\n')),
      );
      expect(
        await reasonOf(() => sourceFor(client).announcedBuild()),
        contains('latest.jsonl'),
      );

      // The download ends before the announced length.
      client = FakeHttpClient((request) async {
        if (request.url.path.endsWith('latest.jsonl')) {
          return bytesResponse(utf8.encode(_latest(_build)));
        }
        return chunkedResponse([zip.sublist(0, 20)], contentLength: zip.length);
      });
      expect(
        await reasonOf(() => sourceFor(client).open()),
        contains('download cut off'),
      );

      // The download breaks off with a network error.
      client = FakeHttpClient((request) async {
        if (request.url.path.endsWith('latest.jsonl')) {
          return bytesResponse(utf8.encode(_latest(_build)));
        }
        return http.StreamedResponse(
          Stream<List<int>>.error(const SocketException('connection reset')),
          200,
        );
      });
      expect(
        await reasonOf(() => sourceFor(client).open()),
        contains('download cut off'),
      );

      // The download is complete but is not a zip.
      client = FakeHttpClient((request) async {
        if (request.url.path.endsWith('latest.jsonl')) {
          return bytesResponse(utf8.encode(_latest(_build)));
        }
        return bytesResponse(utf8.encode('this is not a zip file at all'));
      });
      expect(
        await reasonOf(() => sourceFor(client).open()),
        contains('zip cannot be read'),
      );

      expect(scratch.listSync(), isEmpty, reason: 'failures leave no files');
    });

    test('a download over the cap, too slow or stalled is aborted', () async {
      FakeHttpClient serving(http.StreamedResponse Function() zipResponse) =>
          FakeHttpClient((request) async {
            if (request.url.path.endsWith('latest.jsonl')) {
              return bytesResponse(utf8.encode(_latest(_build)));
            }
            return zipResponse();
          });

      // More bytes than the cap, without announcing a length.
      var client = serving(
        () => chunkedResponse([List.filled(100, 0), List.filled(100, 0)]),
      );
      expect(
        await reasonOf(
          () => sourceFor(
            client,
            limits: const SdeLimits(maxDownloadBytes: 150),
          ).open(),
        ),
        'download exceeds 150 bytes',
      );

      // An announced length over the cap fails before a byte is read.
      client = serving(() => chunkedResponse(const [], contentLength: 1000));
      expect(
        await reasonOf(
          () => sourceFor(
            client,
            limits: const SdeLimits(maxDownloadBytes: 150),
          ).open(),
        ),
        'download exceeds 150 bytes',
      );

      // Bytes arrive but the whole download takes too long.
      client = serving(
        () => chunkedResponse(
          List.generate(50, (_) => [1, 2, 3]),
          delay: const Duration(milliseconds: 10),
        ),
      );
      expect(
        await reasonOf(
          () => sourceFor(
            client,
            limits: const SdeLimits(
              downloadTimeout: Duration(milliseconds: 60),
            ),
          ).open(),
        ),
        'download exceeds 60 ms',
      );

      // Nothing arrives.
      client = serving(
        () => http.StreamedResponse(
          Stream<List<int>>.fromFuture(Completer<List<int>>().future),
          200,
        ),
      );
      expect(
        await reasonOf(
          () => sourceFor(
            client,
            limits: const SdeLimits(
              downloadIdleTimeout: Duration(milliseconds: 40),
            ),
          ).open(),
        ),
        'download stalled: no bytes for 40 ms',
      );

      expect(scratch.listSync(), isEmpty);
    });
  });
}
