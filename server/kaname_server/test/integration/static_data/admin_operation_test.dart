import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:test/test.dart';

import '../support/migrated_database.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Admin operation database assumptions', (sessions, _) {
    late pg.Connection owner;
    late pg.Connection waiter;
    late int waiterPid;

    setUp(() async {
      final settings = await migratedDatabaseSettings(sessions.build());
      owner = await _open(settings);
      addTearDown(owner.close);
      waiter = await _open(settings);
      addTearDown(waiter.close);
      waiterPid =
          (await waiter.execute('SELECT pg_backend_pid()')).single.single
              as int;
      await owner.execute('''
CREATE TABLE IF NOT EXISTS operation_probe (id int PRIMARY KEY, state text)
''');
      await owner.execute('TRUNCATE operation_probe');
    });

    test('A6: first activation commits the build, revision and operation '
        'together', () async {
      const build = 700;
      const operationId = '67864b1a-2c5d-4ed8-90a4-59b3cf5411b5';
      final now = DateTime.utc(2026, 11, 23);
      await owner.execute(
        'INSERT INTO "sde_admin_operation" '
        '("operationId", "kind", "state", "createdAt") '
        r"VALUES ($1::text::uuid, 'updateNow', 'waiting', $2::timestamp)",
        parameters: [operationId, now],
      );
      final settings = await migratedDatabaseSettings(sessions.build());
      final store = await PostgresStaticDataStore.open(settings);
      addTearDown(store.close);
      expect(await store.tryLock(), isTrue);
      expect(await store.markAdminOperationRunning(operationId), isTrue);
      const running = <Object?>[null, null, 'running', null, null, false];

      Future<List<Object?>> visible() async => (await waiter.execute(
        'SELECT b."build", r."revision", o."state", o."outcome", '
        'o."activeBuild", o."changedBuilds" '
        'FROM "sde_admin_operation" o '
        'LEFT JOIN "sde_build" b ON b."activeMarker" '
        'LEFT JOIN "sde_build_revision" r ON r."id" = 1 '
        r'WHERE o."operationId" = $1::text::uuid',
        parameters: [operationId],
      )).single.toList();

      final record = ImportRecord(
        source: SdeSourceKind.ccp,
        startedAt: now,
        outcome: ImportOutcome.running,
        build: build,
      );
      final recordId = await store.insertRecord(record);
      final abort = StateError('abort before first-activation commit');
      Future<void> activate({required bool commit}) =>
          store.inTransaction(activatingBuild: build, (writer) async {
            await expectLater(
              owner.execute(
                'SELECT 1 FROM "sde_admin_operation" '
                r'WHERE "operationId" = $1::text::uuid FOR UPDATE NOWAIT',
                parameters: [operationId],
              ),
              throwsA(
                isA<pg.ServerException>().having(
                  (error) => error.code,
                  'SQLSTATE',
                  '55P03',
                ),
              ),
            );
            await writer.commitBuild(
              build: build,
              state: BuildState.active,
              importedAt: now,
              recordId: recordId,
              record: record.finished(ImportOutcome.succeeded, at: now),
            );
            expect(await visible(), running);
            if (!commit) throw abort;
          });

      await expectLater(activate(commit: false), throwsA(same(abort)));
      expect(await visible(), running);
      await activate(commit: true);
      expect(await visible(), [build, 1, 'ended', 'switched', build, true]);
    });

    test(
      'A7: an update waiting on a concurrent end rechecks its fence',
      () async {
        await owner.execute(
          "INSERT INTO operation_probe VALUES (1, 'running')",
        );
        late Future<pg.Result> update;
        await owner.runTx((transaction) async {
          await transaction.execute(
            "UPDATE operation_probe SET state = 'ended'",
          );
          update = waiter.runTx((tx) async {
            await tx.execute('SET TRANSACTION ISOLATION LEVEL READ COMMITTED');
            return tx.execute('''
UPDATE operation_probe SET state = 'failed' WHERE id = 1 AND state <> 'ended'
RETURNING state
''');
          });
          await _waitForBlock(transaction, waiterPid);
        });

        expect(await update, isEmpty);
        expect(
          (await owner.execute('SELECT state FROM operation_probe'))
              .single
              .single,
          'ended',
        );
      },
    );

    test(
      'A8: an upsert waits on an uncommitted insert then updates it',
      () async {
        late Future<pg.Result> upsert;
        await owner.runTx((transaction) async {
          await transaction.execute(
            "INSERT INTO operation_probe VALUES (1, 'waiting')",
          );
          upsert = waiter.execute('''
INSERT INTO operation_probe VALUES (1, 'ended')
ON CONFLICT (id) DO UPDATE SET state = excluded.state
RETURNING state
''');
          await _waitForBlock(transaction, waiterPid);
        });

        expect((await upsert).single.single, 'ended');
        expect(
          (await owner.execute('SELECT state FROM operation_probe'))
              .single
              .single,
          'ended',
        );
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}

Future<pg.Connection> _open(PostgresConnectionSettings settings) =>
    pg.Connection.open(
      pg.Endpoint(
        host: settings.host,
        port: settings.port,
        database: settings.database,
        username: settings.user,
        password: settings.password,
        isUnixSocket: settings.isUnixSocket,
      ),
      settings: const pg.ConnectionSettings(sslMode: pg.SslMode.disable),
    );

Future<void> _waitForBlock(pg.TxSession owner, int waiterPid) async {
  final wait = Stopwatch()..start();
  while (wait.elapsed < const Duration(seconds: 5)) {
    final blocks = await owner.execute(
      r'SELECT pg_backend_pid() = ANY(pg_blocking_pids($1))',
      parameters: [waiterPid],
    );
    if (blocks.single.single == true) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('The owner never blocked the concurrent statement');
}
