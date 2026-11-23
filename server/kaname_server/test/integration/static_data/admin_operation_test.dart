import 'dart:async';

import 'package:kaname_client/kaname_client.dart' as api;
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/admin_gate.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_server/src/static_data/static_data_access.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart' show Session, UuidValue;
import 'package:test/test.dart';

import '../support/announcer_support.dart';
import '../support/in_process_pod.dart';
import '../support/migrated_database.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  _publicOperationTests();
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

String _operationId(int n) =>
    '39a2ad86-27c8-47cd-9d78-${n.toString().padLeft(12, '0')}';

void _publicOperationTests() {
  group('Public admin operation reads', () {
    late InProcessPod server;
    late api.Client client;
    late FakeClock clock;
    Future<void> Function()? beforeSession;
    Future<void> Function()? afterSession;
    void Function()? leaseFinished;

    setUp(() async {
      server = await InProcessPod.start();
      addTearDown(server.stop);
      clock = FakeClock();
      beforeSession = null;
      afterSession = null;
      leaseFinished = null;
      Future<T> leased<T>(Future<T> Function(Session) action) async {
        try {
          await beforeSession?.call();
          final result = await server.pod.withSession(action);
          await afterSession?.call();
          return result;
        } finally {
          leaseFinished?.call();
        }
      }

      StaticDataAccess.installForTest(
        server.pod,
        StaticDataAccess(
          withSession: leased,
          gate: AdminGate(key: null, log: (_, _) {}, now: clock.now),
          clock: clock,
        ),
      );
      client = api.Client(server.baseUrl);
      addTearDown(client.close);
    });

    Future<void> seed(
      int id, {
      SdeAdminOperationKind kind = SdeAdminOperationKind.updateNow,
      SdeAdminOperationState state = SdeAdminOperationState.waiting,
      DateTime? createdAt,
      DateTime? endedAt,
      SdeAdminOperationOutcome? outcome,
      int? revision,
      int? activeBuild,
      bool changedBuilds = false,
    }) => server.pod.withSession((session) async {
      await SdeAdminOperation.db.insertRow(
        session,
        SdeAdminOperation(
          operationId: UuidValue.fromString(_operationId(id)),
          kind: kind,
          state: state,
          createdAt: createdAt ?? DateTime.now().toUtc(),
          endedAt: endedAt,
          outcome: outcome,
          expectedRevision: revision,
          activeBuild: activeBuild,
          changedBuilds: changedBuilds,
        ),
      );
    });

    Future<api.AdminOperationAnswer> read(int id) async {
      final answer = await client.staticData.operation(_operationId(id));
      clock.elapse(const Duration(seconds: 1));
      return answer;
    }

    test('the operation call for an importing update now answers kind '
        'update now, state running', () async {
      await seed(1);
      final waiting = await read(1);
      expect(waiting.state, api.AdminOperationReadState.waiting);
      expect(waiting.kind, api.SdeAdminOperationKind.updateNow);
      expect(waiting.operation, isNull);

      final settings = await server.pod.withSession(migratedDatabaseSettings);
      final store = await PostgresStaticDataStore.open(settings);
      addTearDown(store.close);
      expect(await store.tryLock(), isTrue);
      expect(await store.markAdminOperationRunning(_operationId(1)), isTrue);
      await store.insertRecord(
        ImportRecord(
          source: SdeSourceKind.ccp,
          startedAt: DateTime.now().toUtc(),
          outcome: ImportOutcome.running,
          build: 901,
        ),
      );

      final running = await read(1);
      expect(running.state, api.AdminOperationReadState.running);
      expect(running.kind, api.SdeAdminOperationKind.updateNow);
      expect(running.operation, isNull);
    });

    test(
      'X stays ended switched after another admin\'s rollback ends',
      () async {
        await server.pod.withSession((session) async {
          await seedBuild(session, 900, SdeBuildState.active);
          await seedBuild(session, 901, SdeBuildState.staged);
        });
        final settings = await server.pod.withSession(migratedDatabaseSettings);
        await seed(1);
        final update = await PostgresStaticDataStore.open(settings);
        addTearDown(update.close);
        expect(await update.tryLock(), isTrue);
        expect(await update.markAdminOperationRunning(_operationId(1)), isTrue);
        await update.inTransaction(
          (writer) => writer.switchTo(901, at: DateTime.now().toUtc()),
        );
        await update.unlock();
        final before = await read(1);
        expect(before.state, api.AdminOperationReadState.ended);
        expect(before.kind, api.SdeAdminOperationKind.updateNow);
        expect(
          before.operation!.outcome,
          api.SdeAdminOperationOutcome.switched,
        );
        expect(before.operation!.activeBuild, 901);
        expect(before.operation!.changedBuilds, isTrue);

        await seed(2, kind: SdeAdminOperationKind.rollback, revision: 1);
        final rollback = await PostgresStaticDataStore.open(settings);
        addTearDown(rollback.close);
        expect(await rollback.tryLock(), isTrue);
        expect(
          await rollback.markAdminOperationRunning(_operationId(2)),
          isTrue,
        );
        await rollback.inTransaction(
          (writer) => writer.rollBack(at: DateTime.now().toUtc()),
        );
        await rollback.unlock();

        final y = await read(2);
        expect(y.state, api.AdminOperationReadState.ended);
        expect(y.kind, api.SdeAdminOperationKind.rollback);
        expect(y.operation!.outcome, api.SdeAdminOperationOutcome.rolledBack);
        expect(y.operation!.activeBuild, 900);
        final x = await read(1);
        expect(x.state, api.AdminOperationReadState.ended);
        expect(x.kind, api.SdeAdminOperationKind.updateNow);
        expect(x.operation!.outcome, api.SdeAdminOperationOutcome.switched);
        expect(x.operation!.activeBuild, 901);
        expect(x.operation!.changedBuilds, isTrue);
        await server.pod.withSession((session) async {
          final active = await SdeBuild.db.findFirstRow(
            session,
            where: (t) => t.activeMarker.equals(true),
          );
          expect(active!.build, 900);
        });
      },
    );

    test('never-stored and expired ids answer unknown operation', () async {
      final now = DateTime.now().toUtc();
      await seed(
        1,
        state: SdeAdminOperationState.ended,
        createdAt: now.subtract(const Duration(days: 45)),
        endedAt: now.subtract(const Duration(days: 31)),
        outcome: SdeAdminOperationOutcome.switched,
      );
      for (final id in [1, 2]) {
        final answer = await read(id);
        expect(answer.state, api.AdminOperationReadState.unknownOperation);
        expect(answer.kind, isNull);
        expect(answer.operation, isNull);
      }
    });

    test('a job stored 40 days ago and ended 10 days ago answers ended '
        'with its outcome', () async {
      final now = DateTime.now().toUtc();
      await seed(
        1,
        createdAt: now.subtract(const Duration(days: 40)),
        endedAt: now.subtract(const Duration(days: 10)),
        state: SdeAdminOperationState.ended,
        outcome: SdeAdminOperationOutcome.switched,
        activeBuild: 901,
        changedBuilds: true,
      );
      final answer = await read(1);
      expect(answer.state, api.AdminOperationReadState.ended);
      expect(answer.kind, api.SdeAdminOperationKind.updateNow);
      expect(answer.operation!.outcome, api.SdeAdminOperationOutcome.switched);
      expect(answer.operation!.activeBuild, 901);
    });

    test(
      'an open job stored 40 days ago answers its state and is kept',
      () async {
        await seed(
          1,
          kind: SdeAdminOperationKind.rollback,
          revision: 1,
          state: SdeAdminOperationState.running,
          createdAt: DateTime.now().toUtc().subtract(const Duration(days: 40)),
        );
        final answer = await read(1);
        expect(answer.state, api.AdminOperationReadState.running);
        expect(answer.kind, api.SdeAdminOperationKind.rollback);
        expect(answer.operation, isNull);
        await server.pod.withSession((session) async {
          expect(await SdeAdminOperation.db.count(session), 1);
        });
      },
    );

    test('a checkout delayed past the owner deadline answers busy', () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final finished = Completer<void>();
      beforeSession = () async {
        entered.complete();
        await release.future;
      };
      leaseFinished = () => finished.complete();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final pending = client.staticData.operation(_operationId(1));
      await entered.future.timeout(const Duration(seconds: 10));
      clock.elapse(const Duration(seconds: 2));
      final answer = await pending;
      expect(answer.state, api.AdminOperationReadState.operationReadBusy);
      expect(answer.operation, isNull);
      release.complete();
      await finished.future.timeout(const Duration(seconds: 10));
    });

    test('a fifth operation read with four running answers operation read '
        'busy and timeouts keep tokens until session cleanup', () async {
      final release = Completer<void>();
      final allLeased = Completer<void>();
      final allFinished = Completer<void>();
      var finished = 0;
      leaseFinished = () {
        if (++finished == 4) allFinished.complete();
      };
      var leased = 0;
      afterSession = () async {
        if (++leased == 4) allLeased.complete();
        await release.future;
      };
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final pending = [
        for (var i = 1; i <= 4; i++)
          client.staticData.operation(_operationId(i)),
      ];
      await allLeased.future.timeout(const Duration(seconds: 10));
      final busy = await client.staticData.operation(_operationId(5));
      expect(busy.state, api.AdminOperationReadState.operationReadBusy);
      expect(busy.kind, isNull);
      clock.elapse(const Duration(seconds: 2));
      final timedOut = await Future.wait(pending);
      for (final answer in timedOut) {
        expect(answer.state, api.AdminOperationReadState.operationReadBusy);
      }
      expect(
        (await client.staticData.operation(_operationId(6))).state,
        api.AdminOperationReadState.operationReadBusy,
      );
      afterSession = null;
      release.complete();
      await allFinished.future.timeout(const Duration(seconds: 10));
      await Future<void>.delayed(Duration.zero);
      final recovered = await client.staticData.operation(_operationId(7));
      expect(recovered.state, api.AdminOperationReadState.unknownOperation);
    });
  });
}
