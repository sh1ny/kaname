import 'dart:convert';

import 'package:kaname_esi/kaname_esi.dart';
import 'package:test/test.dart';

import 'support/fixture_transport.dart';

/// The headers a built request may carry; anything else would be identity
/// or scheduling the transport owns.
const Set<String> _allowedHeaders = {
  'X-Compatibility-Date',
  'If-None-Match',
  'Accept-Language',
  'Content-Type',
};

void main() {
  late FixtureTransport transport;
  late EsiClient client;

  setUp(() {
    transport = FixtureTransport.respond(200, body: '[]');
    client = EsiClient(transport);
  });

  group('Requests carry the pinned compatibility date', () {
    test(
      'assets request target, compatibility date and absent headers',
      () async {
        await client.getCharactersCharacterIdAssets(
          characterId: 90000001,
          page: 2,
        );
        final request = transport.requests.single;
        expect(request.method, EsiMethod.get);
        expect('${request.target}', '/characters/90000001/assets?page=2');
        expect(request.headers['X-Compatibility-Date'], esiCompatibilityDate);
        for (final absent in [
          'If-None-Match',
          'User-Agent',
          'Authorization',
          'X-Tenant',
        ]) {
          expect(request.headers.containsKey(absent), isFalse, reason: absent);
        }
      },
    );

    test('POST /universe/names sends JSON [1,2]', () async {
      await client.postUniverseNames(body: [1, 2]);
      final request = transport.requests.single;
      expect(request.method, EsiMethod.post);
      expect('${request.target}', '/universe/names');
      expect(utf8.decode(request.body!), '[1,2]');
      expect(request.headers['Content-Type'], 'application/json');
    });

    test('empty id list is an invalid request and nothing is sent', () async {
      final result = await client.postUniverseNames(body: []);
      expect(
        result,
        isA<EsiInvalidRequest<Object?>>().having(
          (r) => r.parameter,
          'parameter',
          'body',
        ),
      );
      expect(transport.requests, isEmpty);
    });

    for (final id in ['', '.', '..']) {
      test(
        'path argument "$id" is an invalid request and nothing is sent',
        () async {
          final result = await client.getCosmeticsSkinr(skinrId: id);
          expect(
            result,
            isA<EsiInvalidRequest<Object?>>().having(
              (r) => r.parameter,
              'parameter',
              'skinr_id',
            ),
          );
          expect(transport.requests, isEmpty);
        },
      );
    }

    test('a path argument holding dots among other text is encoded', () async {
      await client.getCosmeticsSkinr(skinrId: 'a.b');
      expect('${transport.requests.single.target}', '/cosmetics/skinr/a.b');
    });
  });

  group('One typed method per operation', () {
    test('cursor a+b/c= is encoded once as after=a%2Bb%2Fc%3D', () async {
      await client.getCorporationsFreelanceJobsListing(
        corporationId: 98000001,
        after: 'a+b/c=',
      );
      final target = transport.requests.single.target;
      expect(target.query, 'after=a%2Bb%2Fc%3D');
      expect(Uri.decodeQueryComponent('a%2Bb%2Fc%3D'), 'a+b/c=');
      expect(target.queryParameters['after'], 'a+b/c=');
    });
  });

  group('Optional and forbidden headers', () {
    test("If-None-Match carries the caller's ETag exactly", () async {
      const etag = '"0f3a-W/xyz"';
      await client.getAlliances(ifNoneMatch: etag);
      expect(transport.requests.single.headers['If-None-Match'], etag);
    });

    test('Accept-Language only when the caller passes it', () async {
      await client.getAlliances(acceptLanguage: EsiLanguage.de);
      await client.getAlliances();
      expect(transport.requests[0].headers['Accept-Language'], 'de');
      expect(
        transport.requests[1].headers.containsKey('Accept-Language'),
        isFalse,
      );
    });
  });

  group('Call identity stays with the transport', () {
    test(
      'two clients on two transports each send only their own request',
      () async {
        final first = FixtureTransport.respond(200, body: '[]');
        final second = FixtureTransport.respond(200, body: '[]');
        await Future.wait([
          EsiClient(first).getCharactersCharacterIdAssets(characterId: 1),
          EsiClient(second).getCharactersCharacterIdAssets(characterId: 2),
        ]);
        expect(first.requests.single.target.path, '/characters/1/assets');
        expect(second.requests.single.target.path, '/characters/2/assets');
      },
    );

    test('built requests hold no Authorization, token or priority', () async {
      await client.getCharactersCharacterIdAssets(characterId: 90000001);
      await client.getAlliances(
        ifNoneMatch: '"e"',
        acceptLanguage: EsiLanguage.de,
      );
      await client.postUniverseNames(body: [1]);
      await client.getCorporationsFreelanceJobsListing(
        corporationId: 98000001,
        after: 'c',
      );
      expect(transport.requests, hasLength(4));
      for (final request in transport.requests) {
        expect(
          _allowedHeaders.containsAll(request.headers.keys),
          isTrue,
          reason: '${request.operationId}: ${request.headers.keys}',
        );
        final query = request.target.queryParameters.keys;
        expect(
          query.where((k) => k.contains('token') || k.contains('priority')),
          isEmpty,
          reason: request.operationId,
        );
      }
    });
  });
}
