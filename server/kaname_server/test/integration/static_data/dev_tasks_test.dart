import 'package:kaname_core/kaname_core.dart' show SdeJson;
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_server/src/static_data/sde_dev_tasks.dart';
import 'package:kaname_server/src/static_data/sde_diff_args.dart';
import 'package:kaname_server/src/static_data/sde_diff_render.dart';
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

    Future<PostgresStaticDataStore> open() =>
        PostgresStaticDataStore.open(settings);

    /// Runs `sde:diff` and returns its exit code, stdout and stderr.
    Future<(int, String, String)> diff(int from, int to) async {
      final out = StringBuffer();
      final err = StringBuffer();
      final code = await runSdeDiff(
        SdeDiffRun(fromBuild: from, toBuild: to),
        open: open,
        out: out,
        err: err,
        precondition: 'precondition',
      );
      return (code, out.toString(), err.toString());
    }

    /// Runs `sde:rollback` and returns its exit code, stdout and stderr.
    Future<(int, String, String)> rollback() async {
      final out = StringBuffer();
      final err = StringBuffer();
      final code = await runSdeRollback(
        open: open,
        out: out,
        err: err,
        precondition: 'precondition',
      );
      return (code, out.toString(), err.toString());
    }

    test('sde:diff prints the same report as the stored one', () async {
      final scenario = changedBuildScenario();
      final store = await open();
      addTearDown(store.close);
      await scenario.seed(store);
      await store.insertDiff(
        BuildDiffRecord(
          fromBuild: scenario.fromBuild,
          toBuild: scenario.toBuild,
          createdAt: DateTime.utc(2026, 1, 2),
          outcome: DiffOutcome.succeeded,
          report: SdeJson(scenario.expectedReport),
        ),
      );
      final stored = await store.diff(scenario.fromBuild, scenario.toBuild);

      final (code, out, err) = await diff(scenario.fromBuild, scenario.toBuild);

      expect(code, 0);
      expect(err, isEmpty);
      expect(
        out,
        renderBuildDiff(BuildDiffReport.fromSdeJson(stored!.report!)),
      );
      expect(out, contains('types.jsonl'));
      expect(out, contains('added:   2 (keys: 11, 12)'));
      expect(out, contains('removed: 1 (keys: 10)'));
      expect(out, contains('changed: 3 (keys: 1, 2, 3)'));
      expect(out, contains('volume (3)'));
      // The task stores nothing.
      final rows = await session.db.unsafeQuery(
        'SELECT count(*) FROM sde_build_diff',
      );
      expect(rows.single.single, 1);
    });

    test('sde:diff of a missing build exits non-zero with build not '
        'stored', () async {
      final scenario = changedBuildScenario();
      final store = await open();
      addTearDown(store.close);
      await scenario.seed(store);

      final (code, out, err) = await diff(scenario.fromBuild, 999);

      expect(code, isNot(0));
      expect(out, isEmpty);
      expect(err, contains('build not stored: 999'));
    });

    test('sde:rollback of a previous build exits 0 and names both '
        'builds', () async {
      final store = await open();
      addTearDown(store.close);
      await seedDiffBuild(
        store,
        100,
        DiffBuildData(typed: [typeRow(1)]),
        BuildState.previous,
      );
      await seedDiffBuild(
        store,
        101,
        DiffBuildData(typed: [typeRow(1)]),
        BuildState.active,
      );

      final (code, out, err) = await rollback();

      expect(code, 0);
      expect(err, isEmpty);
      expect(out, contains('101'));
      expect(out, contains('100'));
      final verify = await open();
      addTearDown(verify.close);
      final states = {
        for (final b in await verify.storedBuilds()) b.build: b.state,
      };
      expect(states, {100: BuildState.active, 101: BuildState.previous});
    });

    test('sde:rollback without a previous build exits non-zero with the '
        'message', () async {
      final store = await open();
      addTearDown(store.close);
      await seedDiffBuild(
        store,
        101,
        DiffBuildData(typed: [typeRow(1)]),
        BuildState.active,
      );

      final (code, out, err) = await rollback();

      expect(code, isNot(0));
      expect(out, isEmpty);
      expect(err, contains('no previous build'));
    });

    test('sde:rollback while an import runs exits non-zero with import '
        'running', () async {
      final holder = await open();
      addTearDown(holder.close);
      expect(await holder.tryLock(), isTrue);
      addTearDown(holder.unlock);

      final (code, out, err) = await rollback();

      expect(code, isNot(0));
      expect(out, isEmpty);
      expect(err, contains('import running'));
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
