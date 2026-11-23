import 'dart:typed_data';

import 'package:kaname_esi/kaname_esi.dart';
import 'package:test/test.dart';

import 'support/fixture_transport.dart';

void main() {
  group('EsiCall.query', () {
    test('writes nothing for null and one pair for a scalar', () {
      expect(EsiCall.query('page', null), isEmpty);
      expect(EsiCall.query('page', 2), [('page', '2')]);
      expect(EsiCall.query('strict', true), [('strict', 'true')]);
    });

    test('repeats an exploded array and joins one that is not', () {
      expect(EsiCall.query('ids', [1, 2]), [('ids', '1'), ('ids', '2')]);
      expect(EsiCall.query('ids', [1, 2], explode: false), [('ids', '1,2')]);
    });

    test('the target encodes each value exactly once', () {
      final target = EsiCall.target('/jobs', [
        ...EsiCall.query('after', 'a+b/c='),
      ]);
      expect(target.toString(), '/jobs?after=a%2Bb%2Fc%3D');
      expect(target.queryParameters['after'], 'a+b/c=');
    });
  });

  group('EsiRequest', () {
    test('owns read-only copies of its headers and body', () {
      final headers = {'X-Compatibility-Date': esiCompatibilityDate};
      final bytes = Uint8List.fromList([0x5B, 0x31, 0x5D]);
      final request = EsiRequest(
        method: EsiMethod.post,
        operationId: 'PostThings',
        target: EsiCall.target('/things'),
        headers: headers,
        body: bytes,
      );
      bytes[1] = 0x32;
      headers['X-Compatibility-Date'] = 'changed';
      expect(request.body, [0x5B, 0x31, 0x5D]);
      expect(request.headers['X-Compatibility-Date'], esiCompatibilityDate);
      expect(() => request.body![1] = 0x32, throwsUnsupportedError);
      expect(
        () => request.headers['X-Compatibility-Date'] = 'changed',
        throwsUnsupportedError,
      );
    });
  });

  group('EsiCall.invoke', () {
    test('sends the built request and reads the body from the root', () async {
      final transport = FixtureTransport.respond(200, body: '[1,2]');
      final result = await EsiCall.invoke<List<int>>(
        transport,
        () => EsiRequest(
          method: EsiMethod.get,
          operationId: 'GetThings',
          target: EsiCall.target('/things'),
          headers: EsiCall.headers(compatibilityDate: '2030-01-02'),
        ),
        read: (json, path) => EsiJson.list(json, path, EsiJson.integer),
      );
      expect(
        result,
        isA<EsiSuccess<List<int>>>().having((r) => r.body, 'body', [1, 2]),
      );
      expect(transport.requests.single.operationId, 'GetThings');
    });

    test(
      'a broken bound becomes an invalid request and sends nothing',
      () async {
        final transport = FixtureTransport.respond(200, body: '[]');
        final result = await EsiCall.invoke<void>(transport, () {
          EsiCheck.range(0, 'page', minimum: 1);
          throw StateError('unreachable');
        }, read: EsiJson.ignore);
        expect(
          result,
          isA<EsiInvalidRequest<void>>()
              .having((r) => r.parameter, 'parameter', 'page')
              .having((r) => r.reason, 'reason', 'must be at least 1, got 0'),
        );
        expect(transport.requests, isEmpty);
      },
    );

    test('a malformed body names the path below the root', () async {
      final result = await EsiCall.invoke<List<int>>(
        FixtureTransport.respond(200, body: '[1,"x"]'),
        () => EsiRequest(
          method: EsiMethod.get,
          operationId: 'GetThings',
          target: EsiCall.target('/things'),
          headers: const {},
        ),
        read: (json, path) => EsiJson.list(json, path, EsiJson.integer),
      );
      expect(
        result,
        isA<EsiMalformed<List<int>>>().having((r) => r.path, 'path', r'$[1]'),
      );
    });
  });
}
