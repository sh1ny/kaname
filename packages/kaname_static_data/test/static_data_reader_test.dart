import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:test/test.dart';

final _t0 = DateTime.utc(2026, 1, 1, 12);

TypedRow _type(int id, String name) => TypedRow(
  table: 'sde_type',
  sdeId: id,
  values: {
    'groupId': 9101,
    'name': name,
    'published': true,
    'volume': 5.0,
    'capacity': null,
    'portionSize': 1,
    'mass': 1000.0,
    'marketGroupId': null,
    'metaGroupId': null,
  },
  raw: SdeJson({'_key': id, 'name': name}),
);

TypedRow _system(int id, String name) => TypedRow(
  table: 'sde_solar_system',
  sdeId: id,
  values: {
    'constellationId': 20,
    'regionId': 10,
    'name': name,
    'securityStatus': 0.9,
    'securityClass': 'A',
  },
  raw: SdeJson({'_key': id, 'name': name}),
);

void main() {
  group('Given an in-memory store with an active build', () {
    late InMemoryStaticDataStore store;
    late InMemoryStaticDataReader reader;

    Future<void> put(int build, BuildState state, String suffix) async {
      await store.inTransaction((writer) async {
        await writer.insertTyped(build, [
          _type(34, 'Tritanium$suffix'),
          _system(30000142, 'Jita$suffix'),
        ]);
      });
      store.seedBuild(build, state);
    }

    setUp(() async {
      store = InMemoryStaticDataStore();
      reader = InMemoryStaticDataReader(store);
      await put(1, BuildState.active, '-1');
    });

    test('when a type is read then it has typed fields and raw JSON', () async {
      final pinned = await reader.pinActiveBuild();
      final row = await pinned.type(34);

      expect(pinned.build, 1);
      expect(row?.sdeId, 34);
      expect(row?.name, 'Tritanium-1');
      expect(row?.groupId, 9101);
      expect(row?.published, isTrue);
      expect(row?.volume, 5.0);
      expect(row?.capacity, isNull);
      expect(row?.raw.value['name'], 'Tritanium-1');
    });

    test('when a solar system is read then it has typed fields and raw '
        'JSON', () async {
      final row = await (await reader.pinActiveBuild()).solarSystem(30000142);

      expect(row?.name, 'Jita-1');
      expect(row?.constellationId, 20);
      expect(row?.regionId, 10);
      expect(row?.securityStatus, 0.9);
      expect(row?.securityClass, 'A');
      expect(row?.raw.value['_key'], 30000142);
    });

    test('when an id is missing from a stored build then the lookup returns '
        'null', () async {
      final pinned = await reader.pinActiveBuild();

      expect(await pinned.type(1), isNull);
      expect(await pinned.solarSystem(1), isNull);
    });

    test('when the build switches then the pin keeps reading its build and a '
        'new pin reads the new one', () async {
      final pinned = await reader.pinActiveBuild();
      await put(2, BuildState.staged, '-2');
      await store.inTransaction((writer) => writer.switchTo(2, at: _t0));

      expect((await pinned.type(34))?.name, 'Tritanium-1');
      final fresh = await reader.pinActiveBuild();
      expect(fresh.build, 2);
      expect((await fresh.type(34))?.name, 'Tritanium-2');
    });

    test('when two switches remove the pinned build then a lookup throws '
        'build no longer stored', () async {
      final pinned = await reader.pinActiveBuild();
      await put(2, BuildState.staged, '-2');
      await store.inTransaction((writer) => writer.switchTo(2, at: _t0));
      await put(3, BuildState.staged, '-3');
      await store.inTransaction((writer) => writer.switchTo(3, at: _t0));

      await expectLater(
        pinned.type(34),
        throwsA(isA<BuildNoLongerStored>().having((e) => e.build, 'build', 1)),
      );
      await expectLater(
        pinned.solarSystem(30000142),
        throwsA(isA<BuildNoLongerStored>()),
      );
    });

    test('when no build is active then pinning throws no active build', () {
      store.seedBuild(1, BuildState.previous);

      expect(reader.pinActiveBuild(), throwsA(isA<NoActiveBuild>()));
    });
  });
}
