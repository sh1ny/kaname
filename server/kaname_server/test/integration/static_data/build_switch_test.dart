import 'dart:io';

import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart'
    show DatabaseUniqueViolationException, Session;
import 'package:test/test.dart';

import '../support/migrated_database.dart';
import '../test_tools/serverpod_test_tools.dart';

/// Every table the build switch added.
const _newTables = ['sde_check', 'sde_switch', 'sde_build_diff'];

/// Every table a stored build has rows in, plus the records, for the reset.
const _allTables = [
  'sde_import',
  'sde_check',
  'sde_switch',
  'sde_build_diff',
  'sde_record',
  'sde_build',
  'sde_category',
  'sde_group',
  'sde_type',
  'sde_market_group',
  'sde_meta_group',
  'sde_dogma_attribute',
  'sde_dogma_attribute_category',
  'sde_dogma_effect',
  'sde_dogma_unit',
  'sde_type_dogma',
  'sde_region',
  'sde_constellation',
  'sde_solar_system',
];

final _t0 = DateTime.utc(2026, 1, 1, 12);

ImportRecord _running() => ImportRecord(
  source: SdeSourceKind.local,
  startedAt: _t0,
  outcome: ImportOutcome.running,
);

TypedRow _typeRow(int sdeId) => TypedRow(
  table: 'sde_type',
  sdeId: sdeId,
  values: {
    'groupId': 9101,
    'name': 'T$sdeId',
    'published': true,
    'volume': 5.0,
    'capacity': null,
    'portionSize': 1,
    'mass': 1000.0,
    'marketGroupId': null,
    'metaGroupId': null,
  },
  raw: SdeJson({'_key': sdeId, 'extra': 'kept'}),
);

void main() {
  withServerpod('Given a migrated database', (sessionBuilder, endpoints) {
    late Session session;

    setUp(() async {
      session = sessionBuilder.build();
      await session.db.unsafeExecute(
        'TRUNCATE sde_build, sde_check, sde_switch, sde_build_diff',
      );
    });

    Future<Set<String>> columnsOf(String table) async {
      final rows = await session.db.unsafeQuery(
        'SELECT column_name FROM information_schema.columns '
        "WHERE table_name = '$table'",
      );
      return {for (final row in rows) row.single! as String};
    }

    test('when sde_build is read then it has the previous marker and the '
        'hold', () async {
      expect(
        await columnsOf('sde_build'),
        containsAll(['previousMarker', 'held']),
      );
    });

    test('when the new tables are read then each has its columns', () async {
      expect(
        await columnsOf('sde_check'),
        containsAll(['checkedAt', 'latestBuild', 'outcome', 'failureReason']),
      );
      expect(
        await columnsOf('sde_switch'),
        containsAll([
          'kind',
          'fromBuild',
          'toBuild',
          'at',
          'outcome',
          'failureReason',
        ]),
      );
      expect(
        await columnsOf('sde_build_diff'),
        containsAll([
          'fromBuild',
          'toBuild',
          'createdAt',
          'outcome',
          'failureReason',
          'report',
        ]),
      );
    });

    test('when the store writes tables then it writes the new ones', () {
      expect(
        PostgresStaticDataStore.writtenTables.keys,
        containsAll(_newTables),
      );
    });

    test('when a build row is inserted without a hold then it is not '
        'held', () async {
      await session.db.unsafeExecute(
        'INSERT INTO sde_build (build, state, "importedAt") '
        "VALUES (1, 'staged', now())",
      );
      final rows = await session.db.unsafeQuery(
        'SELECT held, "previousMarker" FROM sde_build',
      );
      expect(rows.single, [false, null]);
    });

    test('when two builds are marked previous then the second insert '
        'violates the unique index', () async {
      await session.db.unsafeExecute(
        'INSERT INTO sde_build (build, state, "importedAt", "previousMarker") '
        "VALUES (1, 'previous', now(), true)",
      );
      await expectLater(
        session.db.unsafeExecute(
          'INSERT INTO sde_build (build, state, "importedAt", '
          '"previousMarker") '
          "VALUES (2, 'previous', now(), true)",
        ),
        throwsA(isA<DatabaseUniqueViolationException>()),
      );
    });

    test('when many builds are not previous then their null markers do not '
        'collide', () async {
      for (final build in [1, 2, 3]) {
        await session.db.unsafeExecute(
          'INSERT INTO sde_build (build, state, "importedAt") '
          "VALUES ($build, 'staged', now())",
        );
      }
      final rows = await session.db.unsafeQuery('SELECT 1 FROM sde_build');
      expect(rows, hasLength(3));
    });

    group('Given stored builds on a migrated database', () {
      late PostgresConnectionSettings settings;
      late Directory scratch;

      setUp(() async {
        settings = await migratedDatabaseSettings(session);
        await session.db.unsafeExecute('TRUNCATE ${_allTables.join(', ')}');
        scratch = await Directory.systemTemp.createTemp('kaname_switch_');
        addTearDown(() => scratch.delete(recursive: true));
      });

      Future<PostgresStaticDataStore> open() async {
        final store = await PostgresStaticDataStore.open(settings);
        addTearDown(store.close);
        return store;
      }

      /// Stores [build] as [state] with [rows] type rows and as many raw
      /// records.
      Future<void> seed(
        PostgresStaticDataStore store,
        int build,
        BuildState state, {
        int rows = 1,
      }) async {
        final id = await store.insertRecord(_running());
        await store.inTransaction((writer) async {
          await writer.insertTyped(build, [
            for (var i = 1; i <= rows; i++) _typeRow(i),
          ]);
          await writer.insertRaw(build, [
            for (var i = 1; i <= rows; i++)
              RawRecord(
                file: 'blueprints.jsonl',
                line: i,
                key: '$i',
                record: SdeJson({'_key': i}),
              ),
          ]);
          await writer.commitBuild(
            build: build,
            state: state,
            importedAt: _t0,
            recordId: id,
            record: _running().finished(
              ImportOutcome.succeeded,
              at: _t0,
              build: build,
            ),
          );
        });
      }

      Future<Map<int, BuildState>> states(
        PostgresStaticDataStore store,
      ) async => {
        for (final StoredBuild(:build, :state) in await store.storedBuilds())
          build: state,
      };

      /// The states read through the group's own session, for after the job
      /// has closed its store.
      Future<Map<int, BuildState>> sessionStates() async => {
        for (final row in await session.db.unsafeQuery(
          'SELECT build, state FROM sde_build',
        ))
          row[0]! as int: BuildState.values.byName(row[1]! as String),
      };

      Future<Set<int>> rowBuilds(String table) async => {
        for (final row in await session.db.unsafeQuery(
          'SELECT DISTINCT build FROM $table',
        ))
          row.single! as int,
      };

      Future<List<List<Object?>>> switchRows() async => [
        for (final row in await session.db.unsafeQuery(
          'SELECT kind, "fromBuild", "toBuild", outcome, "failureReason" '
          'FROM sde_switch ORDER BY id',
        ))
          row.toList(),
      ];

      test('when a switch deletes a whole build then reads of the active '
          'build never block for a second', () async {
        final store = await open();
        await seed(store, 1, BuildState.previous, rows: 3000);
        await seed(store, 2, BuildState.active, rows: 2000);
        await seed(store, 3, BuildState.staged);
        final reader = await pg.Connection.open(
          pg.Endpoint(
            host: settings.host,
            port: settings.port,
            database: settings.database,
            username: settings.user,
            password: settings.password,
            isUnixSocket: settings.isUnixSocket,
          ),
          settings: pg.ConnectionSettings(sslMode: pg.SslMode.disable),
        );
        addTearDown(reader.close);

        var switching = true;
        var reads = 0;
        var slowest = Duration.zero;
        final reading = () async {
          while (switching) {
            final watch = Stopwatch()..start();
            final result = await reader.execute(
              r'SELECT count(*) FROM "sde_type" WHERE "build" = $1::bigint',
              parameters: [2],
            );
            watch.stop();
            expect(result.single.single, 2000);
            reads++;
            if (watch.elapsed > slowest) slowest = watch.elapsed;
          }
        }();

        await store.inTransaction((writer) async {
          await writer.switchTo(3, at: _t0);
          // Keep the transaction open, its deletes uncommitted, while the
          // reader keeps reading.
          await Future<void>.delayed(const Duration(milliseconds: 500));
        });
        switching = false;
        await reading;

        expect(reads, greaterThan(0));
        expect(slowest, lessThan(const Duration(seconds: 1)));
        expect(await rowBuilds('sde_type'), {2, 3});
      });

      test('after a switch the old active is previous and nothing else is '
          'stored', () async {
        final store = await open();
        await seed(store, 1, BuildState.previous);
        await seed(store, 2, BuildState.active);
        await seed(store, 3, BuildState.staged);

        await store.inTransaction((writer) => writer.switchTo(3, at: _t0));

        expect(await states(store), {
          2: BuildState.previous,
          3: BuildState.active,
        });
        expect(await rowBuilds('sde_type'), {2, 3});
        expect(await rowBuilds('sde_record'), {2, 3});
      });

      test('an import drops the staged build first and never stores more than '
          'three', () async {
        final store = await open();
        await seed(store, 1997, BuildState.previous);
        await seed(store, 1998, BuildState.active);
        await seed(store, 1999, BuildState.staged);
        // The import's first row must find the old staged build gone, and
        // three builds' rows may never be stored at once.
        await session.db.unsafeExecute('''
          CREATE FUNCTION kaname_check_first_row() RETURNS trigger AS \$\$
          BEGIN
            IF EXISTS (SELECT 1 FROM sde_build WHERE state = 'staged')
                OR EXISTS (SELECT 1 FROM sde_type WHERE build = 1999)
                OR (SELECT count(DISTINCT build) FROM sde_type
                    WHERE build <> NEW.build) > 2 THEN
              RAISE EXCEPTION 'the old staged build is still stored';
            END IF;
            RETURN NEW;
          END \$\$ LANGUAGE plpgsql;
          CREATE TRIGGER kaname_first_row BEFORE INSERT ON sde_type
            FOR EACH ROW EXECUTE FUNCTION kaname_check_first_row();
        ''');
        addTearDown(
          () => session.db.unsafeExecute(
            'DROP TRIGGER IF EXISTS kaname_first_row ON sde_type; '
            'DROP FUNCTION IF EXISTS kaname_check_first_row()',
          ),
        );

        final result = await ImportSdeJob(
          store: store,
          source: LocalZipSdeSource(
            SdeFixture.complete(build: 2000).writeTo(scratch),
            scratchRoot: scratch,
          ),
        ).run();

        expect(
          result,
          isA<ImportSucceeded>(),
          reason: '${result is ImportFailed ? result.reason : result}',
        );
        expect(await sessionStates(), {
          1997: BuildState.previous,
          1998: BuildState.active,
          2000: BuildState.staged,
        });
        expect(await rowBuilds('sde_type'), {1997, 1998, 2000});
        expect(await rowBuilds('sde_record'), {1997, 1998, 2000});
      });

      test('switch makes the new build active, the old previous and removes '
          'the oldest', () async {
        final store = await open();
        await seed(store, 1, BuildState.previous);
        await seed(store, 2, BuildState.active, rows: 3);
        await seed(store, 3, BuildState.staged);
        // The old previous build is the one that goes, with its diffs.
        await store.insertDiff(
          BuildDiffRecord(
            fromBuild: 1,
            toBuild: 2,
            createdAt: _t0,
            outcome: DiffOutcome.failed,
            failureReason: 'x',
          ),
        );
        await store.insertDiff(
          BuildDiffRecord(
            fromBuild: 2,
            toBuild: 3,
            createdAt: _t0,
            outcome: DiffOutcome.failed,
            failureReason: 'y',
          ),
        );
        await session.db.unsafeExecute(
          'UPDATE sde_build SET held = true WHERE build IN (1, 2)',
        );

        await store.inTransaction((writer) => writer.switchTo(3, at: _t0));

        expect(await store.storedBuilds(), [
          isA<StoredBuild>()
              .having((b) => b.build, 'build', 2)
              .having((b) => b.state, 'state', BuildState.previous)
              .having((b) => b.held, 'held', isFalse),
          isA<StoredBuild>()
              .having((b) => b.build, 'build', 3)
              .having((b) => b.state, 'state', BuildState.active)
              .having((b) => b.held, 'held', isFalse),
        ]);
        expect(await rowBuilds('sde_type'), {2, 3});
        expect(await store.diff(1, 2), isNull);
        expect(await store.diff(2, 3), isNotNull);
        expect(await switchRows(), [
          ['forward', 2, 3, 'succeeded', null],
        ]);
      });

      test('a failing switch statement keeps the active build and leaves the '
          'new one staged', () async {
        final store = await open();
        await seed(store, 1, BuildState.previous);
        await seed(store, 2, BuildState.active);
        await seed(store, 3, BuildState.staged);
        // The hook: the last statement of the switch, the record insert,
        // fails after every earlier statement has run.
        await session.db.unsafeExecute('''
          CREATE FUNCTION kaname_fail_switch() RETURNS trigger AS \$\$
          BEGIN RAISE EXCEPTION 'injected switch failure'; END
          \$\$ LANGUAGE plpgsql;
          CREATE TRIGGER kaname_fail BEFORE INSERT ON sde_switch
            FOR EACH ROW EXECUTE FUNCTION kaname_fail_switch();
        ''');
        addTearDown(
          () => session.db.unsafeExecute(
            'DROP TRIGGER IF EXISTS kaname_fail ON sde_switch; '
            'DROP FUNCTION IF EXISTS kaname_fail_switch()',
          ),
        );

        await expectLater(
          store.inTransaction((writer) => writer.switchTo(3, at: _t0)),
          throwsA(isA<pg.ServerException>()),
        );
        await session.db.unsafeExecute(
          'DROP TRIGGER kaname_fail ON sde_switch',
        );
        await store.insertFailedSwitch(
          SwitchRecord(
            kind: SwitchKind.forward,
            fromBuild: 2,
            toBuild: 3,
            at: _t0,
            outcome: SwitchOutcome.failed,
            failureReason: 'injected switch failure',
          ),
        );

        expect(await states(store), {
          1: BuildState.previous,
          2: BuildState.active,
          3: BuildState.staged,
        });
        expect(await rowBuilds('sde_type'), {1, 2, 3});
        expect(await switchRows(), [
          ['forward', 2, 3, 'failed', 'injected switch failure'],
        ]);
      });

      test('rollback swaps active and previous and moves the hold', () async {
        final store = await open();
        await seed(store, 1, BuildState.previous);
        await seed(store, 2, BuildState.active);
        await session.db.unsafeExecute(
          'UPDATE sde_build SET held = true WHERE build = 1',
        );

        await store.inTransaction((writer) => writer.rollBack(at: _t0));

        expect(await store.storedBuilds(), [
          isA<StoredBuild>()
              .having((b) => b.build, 'build', 1)
              .having((b) => b.state, 'state', BuildState.active)
              .having((b) => b.held, 'held', isFalse),
          isA<StoredBuild>()
              .having((b) => b.build, 'build', 2)
              .having((b) => b.state, 'state', BuildState.previous)
              .having((b) => b.held, 'held', isTrue),
        ]);
        expect(await rowBuilds('sde_type'), {1, 2});
        expect(await switchRows(), [
          ['rollback', 2, 1, 'succeeded', null],
        ]);
      });

      test('rollback without a previous build fails with no previous '
          'build', () async {
        final store = await open();
        await seed(store, 2, BuildState.active);

        final result = await RollbackJob(store: store, clock: () => _t0).run();

        expect(result, isA<RollbackFailed>());
        expect((result as RollbackFailed).reason, 'no previous build');
        expect(await sessionStates(), {2: BuildState.active});
        expect(await switchRows(), [
          ['rollback', 2, 2, 'failed', 'no previous build'],
        ]);
      });

      test(
        'rollback while the lock is held fails with import running',
        () async {
          final holder = await open();
          await seed(holder, 1, BuildState.previous);
          await seed(holder, 2, BuildState.active);
          expect(await holder.tryLock(), isTrue);

          final store = await PostgresStaticDataStore.open(settings);
          final result = await RollbackJob(
            store: store,
            clock: () => _t0,
          ).run();

          expect(result, isA<RollbackFailed>());
          expect((result as RollbackFailed).reason, 'import running');
          expect(await states(holder), {
            1: BuildState.previous,
            2: BuildState.active,
          });
          await holder.unlock();
        },
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
