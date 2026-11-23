import 'package:kaname_esi/kaname_esi.dart';
import 'package:test/test.dart';

const _assets = EsiRoute(
  operationId: 'GetCharactersCharacterIdAssets',
  method: EsiMethod.get,
  pathTemplate: '/characters/{character_id}/assets',
  rateGroup: EsiRateLimited(
    name: 'char-asset',
    maxTokens: 1800,
    window: Duration(minutes: 15),
  ),
  pagination: EsiPagination.pages,
  requiresAuthentication: true,
  scopes: ['esi-assets.read_assets.v1'],
  serverCacheTtl: Duration(hours: 1),
);

void main() {
  group('EsiRateGroup', () {
    test('none is one value, distinct from every named group', () {
      expect(EsiRateGroup.none, same(EsiRateGroup.none));
      expect(EsiRateGroup.none, isA<EsiNoRateGroup>());
      expect(EsiRateGroup.none, isNot(_assets.rateGroup));
    });

    test('named groups compare by name, tokens and window', () {
      const a = EsiRateLimited(
        name: 'g',
        maxTokens: 300,
        window: Duration(minutes: 15),
      );
      expect(
        a,
        const EsiRateLimited(
          name: 'g',
          maxTokens: 300,
          window: Duration(minutes: 15),
        ),
      );
      expect(
        a.hashCode,
        const EsiRateLimited(
          name: 'g',
          maxTokens: 300,
          window: Duration(minutes: 15),
        ).hashCode,
      );
      expect(
        a,
        isNot(
          const EsiRateLimited(
            name: 'g',
            maxTokens: 301,
            window: Duration(minutes: 15),
          ),
        ),
      );
    });
  });

  group('EsiRoute', () {
    test('equal fields give equal routes, lists compared by content', () {
      final copy = EsiRoute(
        operationId: 'GetCharactersCharacterIdAssets',
        method: EsiMethod.get,
        pathTemplate: '/characters/{character_id}/assets',
        rateGroup: const EsiRateLimited(
          name: 'char-asset',
          maxTokens: 1800,
          window: Duration(minutes: 15),
        ),
        pagination: EsiPagination.pages,
        requiresAuthentication: true,
        scopes: ['esi-assets.read_assets.v1'],
        serverCacheTtl: const Duration(hours: 1),
      );
      expect(copy, _assets);
      expect(copy.hashCode, _assets.hashCode);
    });

    test('an absent cache fact differs from a stated one', () {
      const noCache = EsiRoute(
        operationId: 'GetCharactersCharacterIdAssets',
        method: EsiMethod.get,
        pathTemplate: '/characters/{character_id}/assets',
        rateGroup: EsiRateLimited(
          name: 'char-asset',
          maxTokens: 1800,
          window: Duration(minutes: 15),
        ),
        pagination: EsiPagination.pages,
        requiresAuthentication: true,
        scopes: ['esi-assets.read_assets.v1'],
      );
      expect(noCache.serverCacheTtl, isNull);
      expect(noCache, isNot(_assets));
    });
  });

  group('EsiCatalogue', () {
    const catalogue = EsiCatalogue(
      byOperationId: {'GetCharactersCharacterIdAssets': _assets},
      byMethodAndPath: {'GET /characters/{character_id}/assets': _assets},
    );

    test('finds a route by operation id and by method and path', () {
      expect(catalogue['GetCharactersCharacterIdAssets'], same(_assets));
      expect(
        catalogue.find(EsiMethod.get, '/characters/{character_id}/assets'),
        same(_assets),
      );
      expect(
        EsiCatalogue.methodAndPathKey(
          EsiMethod.get,
          '/characters/{character_id}/assets',
        ),
        'GET /characters/{character_id}/assets',
      );
    });

    test('an unknown id or method gives no entry', () {
      expect(catalogue['GetNothing'], isNull);
      expect(
        catalogue.find(EsiMethod.delete, '/characters/{character_id}/assets'),
        isNull,
      );
    });
  });
}
