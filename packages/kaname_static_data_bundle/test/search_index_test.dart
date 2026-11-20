import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';
import 'package:test/test.dart';

import 'support/bundle_fixture.dart';

/// A type called [name] in group 25.
BundleType type(int id, String? name, {bool published = true}) => BundleType(
  id: id,
  name: LocalizedText({'en': ?name}),
  groupId: 25,
  published: published,
  volume: null,
  capacity: null,
  portionSize: null,
  mass: null,
  marketGroupId: null,
  metaGroupId: null,
  radius: null,
  factionId: null,
  raceId: null,
  variationParentTypeId: null,
);

/// A solar system called [name] in region 10000002.
BundleSolarSystem system(int id, String name) => BundleSolarSystem(
  id: id,
  name: LocalizedText({'en': name}),
  constellationId: 20000020,
  regionId: 10000002,
  securityStatus: 0.9,
  securityClass: null,
);

/// The index of [types] and [systems] with group 25 and region 10000002.
SearchIndex index({
  List<BundleType> types = const [],
  List<BundleSolarSystem> systems = const [],
}) => SearchIndex(
  types: types,
  groups: const [
    BundleGroup(
      id: 25,
      name: LocalizedText({'en': 'Frigate'}),
      categoryId: 6,
      published: true,
    ),
  ],
  solarSystems: systems,
  regions: const [
    BundleRegion(
      id: 10000002,
      name: LocalizedText({'en': 'The Forge'}),
      factionId: null,
    ),
  ],
);

/// The names of [results]' hits, in order.
List<String?> names(SearchResults results) => [
  for (final hit in results.hits) hit.name,
];

void main() {
  test('prefix matches come before substring matches', () {
    final search = index(
      types: [type(1, 'Drifter'), type(2, 'Rifter')],
      systems: [system(30000001, 'Rifterdal')],
    );

    final results = search.search('  RIF ');

    expect(names(results), ['Rifter', 'Rifterdal', 'Drifter']);
    expect(results.more, isFalse);
  });

  test('unpublished type is not a name match', () {
    final search = index(types: [type(1, 'Hidden Rifter', published: false)]);

    expect(search.search('hidden').hits, isEmpty);
    expect(search.search('rifter').hits, isEmpty);
  });

  test('300 matches return 50 and a more flag', () {
    final search = index(
      types: [
        for (var i = 300; i >= 1; i--)
          type(i, 'Thing ${i.toString().padLeft(3, '0')}'),
      ],
    );

    final results = search.search('thing');

    expect(results.hits, hasLength(50));
    expect(results.more, isTrue);
    expect(results.hits.first.name, 'Thing 001');
    expect(results.hits.last.name, 'Thing 050');
  });

  test('exact unpublished type id comes first and its name does not match', () {
    final search = index(
      types: [
        type(587, 'Secret Prototype', published: false),
        type(1, 'Model 587'),
      ],
      systems: [system(587, 'Five Eight Seven')],
    );

    final byId = search.search('587');
    expect(
      [for (final hit in byId.hits) (hit.kind, hit.id)],
      [
        (SearchKind.type, 587),
        (SearchKind.solarSystem, 587),
        (SearchKind.type, 1),
      ],
    );
    expect(byId.hits.first.name, 'Secret Prototype');

    expect(search.search('secret prototype').hits, isEmpty);
  });

  test('unknown id returns only name matches', () {
    final search = index(types: [type(1, 'Model 424242')]);

    expect([for (final hit in search.search('424242').hits) hit.id], [1]);
    expect(search.search('999999').hits, isEmpty);
  });

  test('results carry the group or region name', () {
    final search = index(
      types: [type(587, 'Rifter')],
      systems: [system(30000142, 'Jita')],
    );

    expect(
      search.search('rifter').hits.single,
      isA<SearchHit>()
          .having((h) => h.kind, 'kind', SearchKind.type)
          .having((h) => h.id, 'id', 587)
          .having((h) => h.context, 'context', 'Frigate'),
    );
    expect(search.search('jita').hits.single.context, 'The Forge');
  });

  test('an empty or blank query returns nothing', () {
    final search = index(types: [type(1, 'Rifter')]);

    expect(search.search('').hits, isEmpty);
    expect(search.search('   ').hits, isEmpty);
  });

  test('an index of an opened bundle finds its types and systems', () {
    final built = fixtureBuilder().build();
    final bundle = switch (openBundle(
      built.bytes,
      build: fixtureBuild,
      sha256: built.sha256,
    )) {
      BundleOpened(:final bundle) => bundle,
      BundleRefused(:final refusal) => fail('$refusal'),
    };

    final search = SearchIndex.of(bundle);

    expect(names(search.search('jit')), ['Jita']);
    expect(search.search('rifter').hits.single.context, 'Frigate');
    expect(search.search('34562').hits.single.name, isNull);
  });
}
