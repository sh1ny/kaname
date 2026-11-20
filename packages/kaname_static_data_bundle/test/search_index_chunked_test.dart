import 'dart:async';
import 'dart:math';

import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';
import 'package:test/test.dart';

/// A published type called [name] in group 25.
BundleType _type(int id, String name) => BundleType(
  id: id,
  name: LocalizedText({'en': name}),
  groupId: 25,
  published: id.isEven,
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
BundleSolarSystem _system(int id, String name) => BundleSolarSystem(
  id: id,
  name: LocalizedText({'en': name}),
  constellationId: 20000020,
  regionId: 10000002,
  securityStatus: 0.9,
  securityClass: null,
);

const _groups = [
  BundleGroup(
    id: 25,
    name: LocalizedText({'en': 'Frigate'}),
    categoryId: 6,
    published: true,
  ),
];

const _regions = [
  BundleRegion(
    id: 10000002,
    name: LocalizedText({'en': 'The Forge'}),
    factionId: null,
  ),
];

/// [count] types and as many systems with random short names, several of
/// them equal ignoring case, so the sort's every tie-break is exercised.
({List<BundleType> types, List<BundleSolarSystem> systems}) _random(int count) {
  final random = Random(7);
  String name() => String.fromCharCodes([
    for (var i = 0; i < 1 + random.nextInt(3); i++)
      (random.nextBool() ? 0x41 : 0x61) + random.nextInt(4),
  ]);
  return (
    types: [for (var id = 0; id < count; id++) _type(id, name())],
    systems: [
      for (var id = 0; id < count; id++) _system(30000000 + id, name()),
    ],
  );
}

/// What [index] answers, as plain values that compare with `equals`.
Object? _answers(SearchIndex index) => [
  for (final query in ['a', 'b', 'ab', 'Ca', 'd', '7', '30000007', 'zz'])
    [
      for (final hit in index.search(query).hits)
        [hit.kind, hit.id, hit.name, hit.context],
    ],
];

/// Counts event-loop turns (zero-length timers) until [stop] is called.
final class _TurnCounter {
  _TurnCounter() {
    void tick() {
      if (!_running) return;
      turns++;
      Timer.run(tick);
    }

    Timer.run(tick);
  }

  int turns = 0;
  bool _running = true;

  void stop() => _running = false;
}

void main() {
  for (final itemsPerChunk in [1, 3, 64, 1000000]) {
    test('the chunked build of $itemsPerChunk item(s) per chunk answers as '
        'the one-pass build does', () async {
      final (:types, :systems) = _random(300);
      final onePass = SearchIndex(
        types: types,
        groups: _groups,
        solarSystems: systems,
        regions: _regions,
      );

      final chunked = await SearchIndex.chunked(
        types: types,
        groups: _groups,
        solarSystems: systems,
        regions: _regions,
        itemsPerChunk: itemsPerChunk,
      );

      expect(_answers(chunked), equals(_answers(onePass)));
    });
  }

  test('the chunked build yields to the event loop between chunks', () async {
    final (:types, :systems) = _random(200);
    final counter = _TurnCounter();

    await SearchIndex.chunked(
      types: types,
      groups: _groups,
      solarSystems: systems,
      regions: _regions,
      itemsPerChunk: 10,
    );
    counter.stop();

    // 400 entries in chunks of 10: at least one real turn per chunk of
    // entries, more while sorting.
    expect(counter.turns, greaterThanOrEqualTo(40));
  });

  test('a chunk size below one is rejected', () {
    expect(
      () => SearchIndex.chunked(
        types: const [],
        groups: const [],
        solarSystems: const [],
        regions: const [],
        itemsPerChunk: 0,
      ),
      throwsArgumentError,
    );
  });
}
