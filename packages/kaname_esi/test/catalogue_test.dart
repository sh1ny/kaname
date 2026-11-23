import 'package:kaname_esi/kaname_esi.dart';
import 'package:test/test.dart';

import 'support/operation_coverage.dart';

EsiRoute _route(EsiMethod method, String pathTemplate) =>
    esiCatalogue.find(method, pathTemplate) ??
    fail('no catalogue entry for ${method.wire} $pathTemplate');

void main() {
  group('One catalogue entry per operation', () {
    test('catalogue has 208 entries, one per operation id', () {
      final snapshot = OperationCoverage.load().operations;
      expect(snapshot, hasLength(208));
      expect(esiCatalogue.routes, hasLength(208));
      for (final MapEntry(key: id, value: (:method, :template))
          in snapshot.entries) {
        final route = esiCatalogue[id] ?? fail('no catalogue entry for $id');
        expect(route.operationId, id);
        expect(route.method.wire, method, reason: id);
        expect(route.pathTemplate, template, reason: id);
      }
    });

    test('unknown operation id has no entry', () {
      expect(esiCatalogue['GetNoSuchOperation'], isNull);
    });
  });

  group('Lookup by method and path template', () {
    test('lookup by method and path template finds the entry', () {
      expect(
        _route(EsiMethod.get, '/characters/{character_id}/assets').operationId,
        'GetCharactersCharacterIdAssets',
      );
    });

    test('DELETE on the assets path has no entry', () {
      expect(
        esiCatalogue.find(
          EsiMethod.delete,
          '/characters/{character_id}/assets',
        ),
        isNull,
      );
    });
  });

  group('Rate group per route', () {
    test('alliance contacts carry alliance-social 300 per 15m', () {
      expect(
        _route(EsiMethod.get, '/alliances/{alliance_id}/contacts').rateGroup,
        const EsiRateLimited(
          name: 'alliance-social',
          maxTokens: 300,
          window: Duration(minutes: 15),
        ),
      );
    });

    test('GET /alliances carries EsiRateGroup.none', () {
      expect(
        _route(EsiMethod.get, '/alliances').rateGroup,
        same(EsiRateGroup.none),
      );
    });
  });

  group('Scopes and required roles per route', () {
    test('extractions carry the mining scope and Station_Manager', () {
      final route = _route(
        EsiMethod.get,
        '/corporation/{corporation_id}/mining/extractions',
      );
      expect(route.scopes, ['esi-industry.read_corporation_mining.v1']);
      expect(route.roles, ['Station_Manager']);
      expect(route.requiresAuthentication, isTrue);
    });

    test('public route has no scopes and no roles', () {
      final route = _route(EsiMethod.get, '/alliances');
      expect(route.scopes, isEmpty);
      expect(route.roles, isEmpty);
      expect(route.requiresAuthentication, isFalse);
    });
  });

  group('Cache behaviour per route', () {
    test('/alliances cache facts as stated, cache mode absent', () {
      final route = _route(EsiMethod.get, '/alliances');
      expect(route.serverCacheMode, 'ttl-based');
      expect(route.serverCacheTtl, const Duration(seconds: 3600));
      expect(route.clientCacheTtl, const Duration(seconds: 3600));
      expect(route.cacheAge, const Duration(seconds: 3600));
      expect(route.cacheMode, isNull);
    });

    test('alliance icons have every cache fact absent', () {
      final route = _route(EsiMethod.get, '/alliances/{alliance_id}/icons');
      expect(route.cacheMode, isNull);
      expect(route.serverCacheMode, isNull);
      expect(route.serverCacheTtl, isNull);
      expect(route.clientCacheTtl, isNull);
      expect(route.cacheAge, isNull);
    });
  });

  group('Pagination kind per route', () {
    test('assets route is page-numbered', () {
      expect(
        _route(EsiMethod.get, '/characters/{character_id}/assets').pagination,
        EsiPagination.pages,
      );
    });

    test('freelance jobs route is cursor-paginated', () {
      expect(
        _route(
          EsiMethod.get,
          '/corporations/{corporation_id}/freelance-jobs',
        ).pagination,
        EsiPagination.cursor,
      );
    });

    test('/alliances is unpaginated', () {
      expect(
        _route(EsiMethod.get, '/alliances').pagination,
        EsiPagination.none,
      );
    });
  });
}
