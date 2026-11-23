import 'package:kaname_esi/kaname_esi.dart';
import 'package:test/test.dart';

import 'support/fixture_transport.dart';

/// A hand-written operation shaped like a generated one: `GET /things/{id}`
/// answering a JSON object with a required integer `id`.
Future<EsiResult<int>> getThing(EsiTransport transport, int id) => EsiCall.run(
  transport,
  EsiRequest(
    method: EsiMethod.get,
    operationId: 'GetThingsId',
    target: EsiCall.target('/things/${EsiCall.segment(id, 'id')}'),
    headers: EsiCall.headers(compatibilityDate: '2026-11-19'),
  ),
  decode: (json) => switch (json) {
    {'id': final int id} => id,
    _ => throw const EsiDecodeException(r'$.id', 'expected an integer'),
  },
);

/// A hand-written operation that answers 204 with no content.
Future<EsiResult<void>> deleteThing(EsiTransport transport, int id) =>
    EsiCall.run<void>(
      transport,
      EsiRequest(
        method: EsiMethod.delete,
        operationId: 'DeleteThingsId',
        target: EsiCall.target('/things/${EsiCall.segment(id, 'id')}'),
        headers: EsiCall.headers(compatibilityDate: '2026-11-19'),
      ),
      decode: (_) {},
      noContent: () {},
    );

final class _ThrowingTransport implements EsiTransport {
  @override
  Future<EsiTransportOutcome> send(EsiRequest request) =>
      Future.error(const FormatException('socket closed'));
}

void main() {
  group('Transport fails', () {
    test('a reported failure becomes a result carrying the report', () async {
      final result = await getThing(
        FixtureTransport(const EsiTransportFailure('connection refused')),
        1,
      );
      expect(
        result,
        isA<EsiTransportFailed<int>>().having(
          (r) => r.reason,
          'reason',
          'connection refused',
        ),
      );
    });

    test('an exception the transport throws becomes a result too', () async {
      final result = await getThing(_ThrowingTransport(), 1);
      expect(
        result,
        isA<EsiTransportFailed<int>>().having(
          (r) => r.reason,
          'reason',
          contains('socket closed'),
        ),
      );
    });
  });

  test(
    'Success: 200 with ETag, Expires, Last-Modified and X-Pages 3',
    () async {
      final transport = FixtureTransport.respond(
        200,
        headers: {
          'ETag': '"abc"',
          'Expires': 'Mon, 23 Nov 2026 12:00:00 GMT',
          'Last-Modified': 'Mon, 23 Nov 2026 11:00:00 GMT',
          'X-Pages': '3',
        },
        body: '{"id": 42}',
      );
      final result = await getThing(transport, 42);
      expect(
        result,
        isA<EsiSuccess<int>>()
            .having((r) => r.body, 'body', 42)
            .having((r) => r.status, 'status', 200)
            .having((r) => r.etag, 'etag', '"abc"')
            .having(
              (r) => r.expires,
              'expires',
              'Mon, 23 Nov 2026 12:00:00 GMT',
            )
            .having(
              (r) => r.lastModified,
              'lastModified',
              'Mon, 23 Nov 2026 11:00:00 GMT',
            )
            .having((r) => r.pages, 'pages', 3),
      );
      expect(transport.requests.single.target.toString(), '/things/42');
    },
  );

  test('No content: 204 is a success without a body', () async {
    final result = await deleteThing(FixtureTransport.respond(204), 7);
    expect(
      result,
      isA<EsiSuccess<void>>().having((r) => r.status, 'status', 204),
    );
  });

  test('Not modified: 304 carries ETag and Expires', () async {
    final result = await getThing(
      FixtureTransport.respond(
        304,
        headers: {'etag': '"abc"', 'expires': 'Mon, 23 Nov 2026 12:00:00 GMT'},
      ),
      1,
    );
    expect(
      result,
      isA<EsiNotModified<int>>()
          .having((r) => r.etag, 'etag', '"abc"')
          .having((r) => r.expires, 'expires', 'Mon, 23 Nov 2026 12:00:00 GMT'),
    );
  });

  test('ESI error with body: 404 with an error message', () async {
    final result = await getThing(
      FixtureTransport.respond(404, body: '{"error":"Character not found"}'),
      1,
    );
    expect(
      result,
      isA<EsiError<int>>()
          .having((r) => r.status, 'status', 404)
          .having((r) => r.message, 'message', 'Character not found'),
    );
  });

  test('ESI error without a readable body: 502 with a non-JSON body', () async {
    final result = await getThing(
      FixtureTransport.respond(502, body: '<html>Bad Gateway</html>'),
      1,
    );
    expect(
      result,
      isA<EsiError<int>>()
          .having((r) => r.status, 'status', 502)
          .having((r) => r.message, 'message', isNull),
    );
  });

  group('header and body edges', () {
    test('a non-integer X-Pages is malformed, not a guess', () async {
      final result = await getThing(
        FixtureTransport.respond(
          200,
          headers: {'X-Pages': 'three'},
          body: '{"id": 1}',
        ),
        1,
      );
      expect(
        result,
        isA<EsiMalformed<int>>().having(
          (r) => r.path,
          'path',
          r'$headers.x-pages',
        ),
      );
    });

    test('a decoder mismatch is malformed with its path', () async {
      final result = await getThing(
        FixtureTransport.respond(200, body: '{"id": "1"}'),
        1,
      );
      expect(
        result,
        isA<EsiMalformed<int>>()
            .having((r) => r.status, 'status', 200)
            .having((r) => r.path, 'path', r'$.id'),
      );
    });

    test('an empty 200 body is malformed at the root', () async {
      final result = await getThing(FixtureTransport.respond(200), 1);
      expect(
        result,
        isA<EsiMalformed<int>>().having((r) => r.path, 'path', r'$'),
      );
    });
  });
}
