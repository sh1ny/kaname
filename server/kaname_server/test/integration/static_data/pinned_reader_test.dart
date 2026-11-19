import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_server/src/static_data/orm_static_data_reader.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/migrated_database.dart';
import '../test_tools/serverpod_test_tools.dart';

const _allTables = [
  'sde_import',
  'sde_check',
  'sde_switch',
  'sde_build_diff',
  'sde_record',
  'sde_build',
  'sde_type',
  'sde_solar_system',
];

final _t0 = DateTime.utc(2026, 1, 1, 12);

TypedRow _typeRow(int sdeId, String name) => TypedRow(
  table: 'sde_type',
  sdeId: sdeId,
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
  raw: SdeJson({'_key': sdeId, 'name': name}),
);

void main() {
  withServerpod('Given stored builds read through the pinned reader', (
    sessionBuilder,
    endpoints,
  ) {
    late Session session;
    late PostgresStaticDataStore store;
    late OrmStaticDataReader reader;

    setUp(() async {
      session = sessionBuilder.build();
      final settings = await migratedDatabaseSettings(session);
      await session.db.unsafeExecute('TRUNCATE ${_allTables.join(', ')}');
      store = await PostgresStaticDataStore.open(settings);
      addTearDown(store.close);
      reader = OrmStaticDataReader(session);
    });

    /// Stores [build] as [state] with type 34 named `Tritanium-<build>`.
    Future<void> seed(int build, BuildState state) async {
      final id = await store.insertRecord(
        ImportRecord(
          source: SdeSourceKind.local,
          startedAt: _t0,
          outcome: ImportOutcome.running,
        ),
      );
      await store.inTransaction((writer) async {
        await writer.insertTyped(build, [_typeRow(34, 'Tritanium-$build')]);
        await writer.commitBuild(
          build: build,
          state: state,
          importedAt: _t0,
          recordId: id,
          record: ImportRecord(
            source: SdeSourceKind.local,
            startedAt: _t0,
            outcome: ImportOutcome.running,
          ).finished(ImportOutcome.succeeded, at: _t0, build: build),
        );
      });
    }

    Future<void> switchTo(int build) =>
        store.inTransaction((writer) => writer.switchTo(build, at: _t0));

    test('a pinned request keeps reading the old build across a '
        'switch', () async {
      await seed(1, BuildState.active);
      await seed(2, BuildState.staged);

      final pinned = await reader.pinActiveBuild();
      await switchTo(2);

      final old = await pinned.type(34);
      expect(pinned.build, 1);
      expect(old?.name, 'Tritanium-1');
      expect(old?.groupId, 9101);
      expect(old?.raw.value['name'], 'Tritanium-1');
      expect(await pinned.type(999), isNull);

      final fresh = await reader.pinActiveBuild();
      expect(fresh.build, 2);
      expect((await fresh.type(34))?.name, 'Tritanium-2');
    });

    test('a pinned build removed by two switches fails with build no longer '
        'stored', () async {
      await seed(1, BuildState.active);
      await seed(2, BuildState.staged);
      final pinned = await reader.pinActiveBuild();
      await switchTo(2);
      await seed(3, BuildState.staged);
      await switchTo(3);

      await expectLater(
        pinned.type(34),
        throwsA(isA<BuildNoLongerStored>().having((e) => e.build, 'build', 1)),
      );
      await expectLater(
        pinned.solarSystem(1),
        throwsA(isA<BuildNoLongerStored>()),
      );
    });

    test('pinning with no active build fails with no active build', () async {
      await seed(1, BuildState.staged);

      await expectLater(reader.pinActiveBuild(), throwsA(isA<NoActiveBuild>()));
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
