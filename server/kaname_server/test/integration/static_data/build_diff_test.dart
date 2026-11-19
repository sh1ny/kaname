import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/migrated_database.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Given a migrated database', (sessionBuilder, endpoints) {
    late Session session;
    late PostgresConnectionSettings settings;

    setUp(() async {
      session = sessionBuilder.build();
      settings = await migratedDatabaseSettings(session);
      await session.db.unsafeExecute(
        'TRUNCATE ${PostgresStaticDataStore.writtenTables.keys.join(', ')}',
      );
    });

    /// Seeds [scenario] and compares its builds with the SQL differ.
    Future<BuildDiffReport> compare(DiffScenario scenario) async {
      final store = await PostgresStaticDataStore.open(settings);
      addTearDown(store.close);
      await scenario.seed(store);
      return store.differ().compare(scenario.fromBuild, scenario.toBuild);
    }

    test('when jsonb values are compared then key order does not matter '
        '(A1)', () async {
      final rows = await session.db.unsafeQuery(
        'SELECT \'{"a":1,"b":2}\'::jsonb = \'{"b":2,"a":1}\'::jsonb, '
        '\'{"a":{"x":1,"y":[1,2]}}\'::jsonb = '
        '\'{"a":{"y":[1,2],"x":1}}\'::jsonb, '
        '\'{"a":[1,2]}\'::jsonb = \'{"a":[2,1]}\'::jsonb',
      );
      expect(rows.single.toList(), [true, true, false]);
    });

    test('changed types file reports counts, keys and volume field', () async {
      final scenario = changedBuildScenario();
      final report = await compare(scenario);
      expect(report.toSdeJson().value, scenario.expectedReport);
      final types = report.files.single;
      expect(
        (types.added.count, types.removed.count, types.changed.count),
        (2, 1, 3),
      );
      expect(types.changedFields, {'volume': 3});
    });

    test('more than 1000 changed keys are cut off and marked', () async {
      final scenario = manyChangesScenario();
      final report = await compare(scenario);
      expect(report.toSdeJson().value, scenario.expectedReport);
      final changed = report.files.single.changed;
      expect(
        (changed.count, changed.keys.length, changed.truncated),
        (5000, 1000, true),
      );
    });

    test('a file only in the new build is listed as new with all records '
        'added', () async {
      final scenario = fileOnlyInOneBuildScenario();
      final report = await compare(scenario);
      expect(report.toSdeJson().value, scenario.expectedReport);
      final blueprints = report.files.firstWhere(
        (file) => file.file == 'blueprints.jsonl',
      );
      expect(blueprints.status, DiffFileStatus.newFile);
      expect(blueprints.added.count, 3);
    });

    test('key order alone is not a change', () async {
      final scenario = keyOrderScenario();
      final report = await compare(scenario);
      expect(report.toSdeJson().value, scenario.expectedReport);
    });

    test('a raw file with a repeated key and empty keys gives multiset '
        'counts that no join multiplies', () async {
      final scenario = rawMultisetScenario();
      final report = await compare(scenario);
      expect(report.toSdeJson().value, scenario.expectedReport);
      final file = report.files.single;
      expect(
        (file.added.count, file.removed.count, file.changed.count),
        (4, 5, 1),
      );
    });

    test(
      'when a build is not stored then it throws naming the build',
      () async {
        final store = await PostgresStaticDataStore.open(settings);
        addTearDown(store.close);
        await seedDiffBuild(
          store,
          100,
          const DiffBuildData(),
          BuildState.active,
        );
        await expectLater(
          store.differ().compare(100, 777),
          throwsA(
            isA<BuildNotStoredException>().having((e) => e.build, 'build', 777),
          ),
        );
        await expectLater(
          store.differ().compare(555, 100),
          throwsA(
            isA<BuildNotStoredException>().having((e) => e.build, 'build', 555),
          ),
        );
      },
    );

    test('when statements are observed then each is named and timed', () async {
      final scenario = changedBuildScenario();
      final store = await PostgresStaticDataStore.open(settings);
      addTearDown(store.close);
      await scenario.seed(store);
      final seen = <String>[];
      await store
          .differ(
            onStatement: (name, elapsed, rows) {
              expect(elapsed, greaterThanOrEqualTo(Duration.zero));
              seen.add(name);
            },
          )
          .compare(scenario.fromBuild, scenario.toBuild);
      expect(seen, contains('types.jsonl'));
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
