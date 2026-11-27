import 'dart:async';

import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:kaname_server/src/esi/esi_call_log_store.dart';
import 'package:kaname_server/src/generated/endpoints.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'esi_call_log_test.dart' show admin, assets, other, probe, seed;
import 'support/migrated_database.dart';
import 'support/observe_postgres_lock.dart';
import 'support/tcp_proxy.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('ESI call-log release', (sessions, _) {
    final day = DateTime.utc(2090, 1, 15);
    final grace = day.add(const Duration(minutes: 1));
    final recent = day.subtract(const Duration(hours: 1));
    late Session session;
    late DateTime clock;
    late EsiCallLogStore store;

    setUp(() async {
      session = sessions.build();
      addTearDown(session.close);
      await session.db.unsafeExecute('''
        TRUNCATE esi_call_log_entry, esi_call_log_exclusion, esi_call_log_seal
      ''');
      clock = grace;
      store = EsiCallLogStore(now: () => clock);
    });

    Future<void> independent(int size) async {
      for (var id = 1; id <= size; id++) {
        await seed(session, recent, owner: id, character: id * 10);
      }
    }

    Future<void> exclusion(
      int account,
      DateTime at, {
      Transaction? transaction,
    }) async {
      await session.db.unsafeExecute(
        'INSERT INTO esi_call_log_exclusion (id, "excludedAt") '
        'VALUES (@id::bigint, @at::timestamp)',
        parameters: QueryParameters.named({'id': account, 'at': at}),
        transaction: transaction,
      );
    }

    Future<void> rejectSeal() async {
      await session.db.unsafeExecute('''
        CREATE OR REPLACE FUNCTION fail_test_call_log_seal() RETURNS trigger
        LANGUAGE plpgsql AS \$\$
        BEGIN RAISE EXCEPTION 'intentional seal failure'; END;
        \$\$
      ''');
      await session.db.unsafeExecute('''
        CREATE TRIGGER fail_test_call_log_seal BEFORE INSERT OR UPDATE
        ON esi_call_log_seal FOR EACH STATEMENT
        EXECUTE FUNCTION fail_test_call_log_seal()
      ''');
      addTearDown(() async {
        await session.db.unsafeExecute('''
          DROP TRIGGER IF EXISTS fail_test_call_log_seal ON esi_call_log_seal
        ''');
      });
    }

    Future<void> allowSeal() async {
      await session.db.unsafeExecute('''
        DROP TRIGGER fail_test_call_log_seal ON esi_call_log_seal
      ''');
    }

    Future<DateTime?> sealedEnd() async {
      final rows = await session.db.unsafeQuery('''
        SELECT "windowEnd" FROM esi_call_log_seal WHERE id = 1
      ''');
      return rows.isEmpty ? null : (rows.single.single as DateTime).toUtc();
    }

    test(
      'next window is not published before its UTC grace and committed seal',
      () async {
        clock = day.add(const Duration(seconds: 1));
        await seed(
          session,
          recent.subtract(const Duration(days: 1)),
          route: probe,
          owner: null,
          character: null,
        );
        final before = await store.routeCountsWithWindow(session, admin);
        expect(before.window, day.subtract(const Duration(days: 1)));
        expect(before.rows, [(operation: probe, total: 1, errors: 0)]);

        final recorded = day.subtract(const Duration(seconds: 1));
        final scheduler = EsiScheduler(
          state: MemorySchedulerState(),
          key: const [1],
          now: () => recorded,
          callLog: (receipt) => store.append(session, receipt),
          send: (_, _, _) async => WireResponse(EsiResponse(status: 304)),
        );
        await scheduler.client(EsiPriority.interactive).getStatus();
        await scheduler.drainCallLog();
        final duringGrace = await store.routeCountsWithWindow(session, admin);
        expect(duringGrace.window, before.window);
        expect(duringGrace.rows, before.rows);
        expect(await sealedEnd(), before.window);
        clock = grace;
        await rejectSeal();
        await expectLater(
          store.routeCounts(session, admin),
          throwsA(isA<EsiCallLogUnavailable>()),
        );
        await allowSeal();
        expect((await store.routeCounts(session, admin)).single.total, 2);
        expect(await sealedEnd(), day);
      },
    );

    for (final preview in [true, false]) {
      final stage = preview ? 'preview' : 'response admission';
      test('standalone $stage seal read uses the statement budget', () async {
        final end = await store.sealWindow(session);
        await session.db.transaction((tx) async {
          await session.db.unsafeExecute(r'''
            CREATE FUNCTION require_seal_read_budget() RETURNS boolean
            LANGUAGE plpgsql AS $$
            BEGIN
              IF current_setting('statement_timeout')::interval <> interval '10 seconds'
                THEN RAISE EXCEPTION 'seal read has no statement budget';
              END IF;
              RETURN true;
            END
            $$
          ''', transaction: tx);
          await session.db.unsafeExecute('''
            ALTER TABLE esi_call_log_seal RENAME TO fixture_call_log_seal
          ''', transaction: tx);
          await session.db.unsafeExecute('''
            CREATE VIEW esi_call_log_seal AS
            SELECT id, "windowEnd" FROM fixture_call_log_seal
            WHERE require_seal_read_budget()
          ''', transaction: tx);
        });
        addTearDown(() async {
          await session.db.unsafeExecute('DROP VIEW esi_call_log_seal');
          await session.db.unsafeExecute('''
            ALTER TABLE fixture_call_log_seal RENAME TO esi_call_log_seal
          ''');
          await session.db.unsafeExecute(
            'DROP FUNCTION require_seal_read_budget()',
          );
        });
        expect(
          preview
              ? await store.sealWindow(session)
              : await store.currentSeal(session),
          end,
        );
      });
    }

    test(
      'eligible accounts qualify totals including ineligible calls',
      () async {
        await independent(5);
        for (final id in [6, 7]) {
          await seed(
            session,
            recent,
            owner: id,
            character: 70,
            outcome: 'error',
          );
        }
        expect(await store.routeCounts(session, admin), [
          (operation: assets, total: 7, errors: 2),
        ]);
      },
    );

    test(
      'one character across several accounts cannot qualify a private route',
      () async {
        for (var id = 1; id <= 5; id++) {
          await seed(session, recent, owner: id, character: 10);
        }
        expect(await store.routeCounts(session, admin), isEmpty);
      },
    );

    test(
      'overlap on another route disqualifies accounts for the window',
      () async {
        await independent(6);
        for (final owner in [1, 6]) {
          await seed(
            session,
            recent,
            route: other,
            owner: owner,
            character: 70,
          );
        }
        expect(await store.routeCounts(session, admin), isEmpty);
      },
    );

    test(
      'pre-cutoff join disqualifies retained receipts without a new append',
      () async {
        await independent(5);
        await exclusion(5, grace.subtract(const Duration(microseconds: 1)));
        expect(await store.routeCounts(session, admin), isEmpty);
      },
    );

    for (final commit in [true, false]) {
      test(
        commit
            ? 'release includes committed exclusion stamped before cutoff'
            : 'rolled-back exclusion does not disqualify contributors',
        () async {
          await independent(5);
          final wrote = Completer<int>();
          final settle = Completer<void>();
          final aborted = StateError('intentional transaction rollback');
          final holding = session.db.transaction((tx) async {
            await session.db.unsafeQuery(
              'SELECT pg_advisory_xact_lock_shared(682997614)',
              transaction: tx,
            );
            await exclusion(
              5,
              grace.subtract(const Duration(seconds: 1)),
              transaction: tx,
            );
            final pid = await session.db.unsafeQuery(
              'SELECT pg_backend_pid()',
              transaction: tx,
            );
            wrote.complete(pid.single.single as int);
            await settle.future;
            if (!commit) throw aborted;
          });
          final settled = commit
              ? holding
              : expectLater(holding, throwsA(same(aborted)));
          final holder = await Future.any<int>([
            wrote.future,
            settled.then(
              (_) =>
                  fail('The writer settled before holding the exclusion lock.'),
            ),
          ]);
          final read = EsiCallLogStore(
            now: () => clock,
            boundReleaseLock: false,
          ).routeCounts(session, admin);
          try {
            await observePostgresLock(session, holder, read);
          } finally {
            settle.complete();
            await settled;
          }
          final rows = await read;
          if (commit) {
            expect(rows, isEmpty);
          } else {
            expect(rows.single.total, 5);
          }
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }

    test(
      'release with an unresolved pre-cutoff write is unavailable',
      () async {
        await independent(5);
        final wrote = Completer<void>();
        final settle = Completer<void>();
        final holding = session.db.transaction((tx) async {
          await session.db.unsafeQuery(
            'SELECT pg_advisory_xact_lock_shared(682997614)',
            transaction: tx,
          );
          await exclusion(
            5,
            grace.subtract(const Duration(seconds: 1)),
            transaction: tx,
          );
          wrote.complete();
          await settle.future;
        });
        try {
          await Future.any([wrote.future, holding]);
          await expectLater(
            EsiCallLogStore(
              now: () => clock,
              waitForReleaseLock: false,
            ).routeCounts(session, admin),
            throwsA(isA<EsiCallLogUnavailable>()),
          );
          expect(await sealedEnd(), isNull);
        } finally {
          settle.complete();
          await holding;
        }
        expect(await store.routeCounts(session, admin), isEmpty);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('exclusion at the exact cutoff affects only later windows', () async {
      await independent(5);
      await exclusion(5, grace);
      expect((await store.routeCounts(session, admin)).single.total, 5);
      clock = grace.add(const Duration(days: 1));
      expect(await store.routeCounts(session, admin), isEmpty);
    });

    test('a post-cutoff stamp cannot disqualify an older window', () async {
      await independent(4);
      clock = grace.add(const Duration(microseconds: 1));
      await session.db.transaction(
        (tx) => store.excludeAccount(session, tx, 5),
      );
      expect(await sealedEnd(), isNull);

      clock = day.subtract(const Duration(seconds: 1));
      final scheduler = EsiScheduler(
        state: MemorySchedulerState(),
        key: const [1],
        now: () => clock,
        callLog: (receipt) => store.append(session, receipt),
        send: (_, _, _) async => WireResponse(EsiResponse(status: 304)),
      );
      final client = scheduler.client(
        EsiPriority.interactive,
        principal: EsiPrincipal(
          application: 'fixture',
          character: 50,
          member: 5,
          generation: 'first',
          accountExcluded: true,
          bearer: () => 'fixture-bearer',
        ),
      );
      await EsiCall.run<void>(
        client.transport,
        EsiRequest(
          method: EsiMethod.get,
          operationId: assets,
          target: Uri.parse('/characters/50/assets'),
          headers: const {},
        ),
        decode: (_) {},
      );
      await scheduler.drainCallLog();
      expect(
        (await session.db.unsafeQuery('''
          SELECT "accountExcluded" FROM esi_call_log_entry WHERE "memberId" = 5
        ''')).single.single,
        isTrue,
      );

      clock = grace;
      final first = await store.routeCountsWithWindow(session, admin);
      expect(first.window, day);
      expect(first.rows, [(operation: assets, total: 5, errors: 0)]);

      clock = grace.add(const Duration(days: 1));
      final next = await store.routeCountsWithWindow(session, admin);
      expect(next.window, day.add(const Duration(days: 1)));
      expect(next.rows, isEmpty);
    });

    test(
      'post-cutoff exclusion leaves the same totals with a cold cache',
      () async {
        await independent(5);
        final prior = await store.routeCounts(session, admin);
        await exclusion(5, grace.add(const Duration(microseconds: 1)));
        clock = grace.add(const Duration(minutes: 1));
        expect(
          await EsiCallLogStore(now: () => clock).routeCounts(session, admin),
          prior,
        );
      },
    );

    test(
      'retiring an account does not change its receipt eligibility',
      () async {
        final signer = await SsoIdentityRow.db.insertRow(
          session,
          SsoIdentityRow(
            characterId: 50,
            owner: 'fixture',
            characterName: 'Pilot',
            blocked: false,
          ),
        );
        final account = await MemberAccountRow.db.insertRow(
          session,
          MemberAccountRow(mainIdentityId: signer.id!),
        );
        final id = account.id!;
        await SsoIdentityRow.db.updateRow(
          session,
          signer.copyWith(accountId: id),
        );
        for (var i = 1; i <= 4; i++) {
          await seed(session, recent, owner: id + i, character: i * 10);
        }
        await seed(session, recent, owner: id, character: 50);
        final published = await store.routeCountsWithWindow(session, admin);
        expect(published.window, day);
        expect(published.rows.single.total, 5);

        clock = grace.add(const Duration(microseconds: 1));
        await session.db.transaction((tx) async {
          await store.excludeAccount(session, tx, id);
          await SsoIdentityRow.db.updateRow(
            session,
            signer.copyWith(wasDetached: true),
            transaction: tx,
          );
          await MemberAccountRow.db.deleteRow(
            session,
            account,
            transaction: tx,
          );
        });
        expect(await MemberAccountRow.db.findById(session, id), isNull);
        expect(
          (await session.db.unsafeQuery(
            'SELECT "excludedAt" FROM esi_call_log_exclusion WHERE id = @id::bigint',
            parameters: QueryParameters.named({'id': id}),
          )).single.single,
          clock,
        );
        final cold = EsiCallLogStore(now: () => clock);
        final recomputed = await cold.routeCountsWithWindow(session, admin);
        expect(recomputed.window, published.window);
        expect(recomputed.rows, published.rows);
      },
    );

    test('sealed range rejects late input and retains totals across a clock step and restart', () async {
      await independent(5);
      final prior = await store.routeCountsWithWindow(session, admin);
      expect(prior.rows.single.total, 5);
      clock = day.subtract(const Duration(seconds: 3));
      final restarted = EsiCallLogStore(now: () => clock);
      await session.db.transaction(
        (tx) => restarted.excludeAccount(session, tx, 5),
      );
      final excluded = await session.db.unsafeQuery('''
        SELECT "excludedAt" FROM esi_call_log_exclusion WHERE id = 5
      ''');
      expect((excluded.single.single as DateTime).toUtc(), grace);
      final scheduler = EsiScheduler(
        state: MemorySchedulerState(),
        key: const [1],
        now: () => clock,
        callLog: (receipt) => restarted.append(session, receipt),
        send: (_, _, _) async => WireResponse(EsiResponse(status: 304)),
      );
      await scheduler.client(EsiPriority.interactive).getStatus();
      await scheduler.drainCallLog();
      final rows = await session.db.unsafeQuery(
        'SELECT count(*) FROM esi_call_log_entry',
      );
      expect(rows.single.single, 5);
      final after = await restarted.routeCountsWithWindow(session, admin);
      expect(after.window, prior.window);
      expect(after.rows, prior.rows);
    });

    test('an unsealed cutoff crossing does not freeze eligibility', () async {
      await independent(5);
      await rejectSeal();
      await expectLater(
        store.routeCounts(session, admin),
        throwsA(isA<EsiCallLogUnavailable>()),
      );
      expect(await sealedEnd(), isNull);
      clock = day;
      await session.db.transaction(
        (tx) => store.excludeAccount(session, tx, 5),
      );
      expect(await sealedEnd(), isNull);
      await allowSeal();
      clock = grace;
      expect(await store.routeCounts(session, admin), isEmpty);
      expect(await sealedEnd(), day);
    });

    test('seal failure yields no page and recovery cannot regress', () async {
      await independent(5);
      await rejectSeal();
      await expectLater(
        store.routeCounts(session, admin),
        throwsA(isA<EsiCallLogUnavailable>()),
      );
      expect(await sealedEnd(), isNull);
      await allowSeal();
      expect((await store.routeCounts(session, admin)).single.total, 5);
      clock = day;
      expect(
        (await EsiCallLogStore(
          now: () => clock,
        ).routeCountsWithWindow(session, admin)).window,
        day,
      );
    });

    test('a committed seal with a lost acknowledgment is used only by a later read', () async {
      await independent(5);
      final direct = await migratedDatabaseSettings(session);
      final proxy = direct.isUnixSocket
          ? await TcpProxy.startToUnixSocket(direct.host)
          : await TcpProxy.start(direct.host, direct.port);
      addTearDown(proxy.close);
      final observer = await pg.Connection.open(
        pg.Endpoint(
          host: direct.host,
          port: direct.port,
          database: direct.database,
          username: direct.user,
          password: direct.password,
          isUnixSocket: direct.isUnixSocket,
        ),
        settings: const pg.ConnectionSettings(sslMode: pg.SslMode.disable),
      );
      addTearDown(observer.close);
      final reader = Serverpod(
        ['--mode', 'test'],
        Protocol(),
        Endpoints(),
        configOverride: (config) => config.copyWith(
          healthCheckInterval: Duration.zero,
          futureCallExecutionEnabled: false,
          database: PostgresDatabaseConfig(
            host: '127.0.0.1',
            port: proxy.port,
            name: direct.database,
            user: direct.user,
            password: direct.password ?? '',
          ),
        ),
      );
      addTearDown(() => reader.shutdown(exitProcess: false));
      await reader.start(runInGuardedZone: false);
      await observer.execute('''
        CREATE FUNCTION test_seal_ack() RETURNS trigger LANGUAGE plpgsql AS \$\$
        BEGIN
          PERFORM pg_advisory_xact_lock(682997614, 1);
          PERFORM pg_notify('test_seal_ack', NEW."windowEnd"::text);
          RETURN NEW;
        END
        \$\$;
        CREATE CONSTRAINT TRIGGER test_seal_ack AFTER INSERT ON esi_call_log_seal
        DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION test_seal_ack()
      ''', queryMode: pg.QueryMode.simple);
      addTearDown(
        () => observer.execute('''
        DROP TRIGGER test_seal_ack ON esi_call_log_seal;
        DROP FUNCTION test_seal_ack()
      ''', queryMode: pg.QueryMode.simple),
      );
      final committed = observer.channels['test_seal_ack'].first;
      await observer.execute('LISTEN test_seal_ack');
      await observer.execute('SELECT pg_advisory_lock(682997614, 1)');
      final holder =
          (await observer.execute('SELECT pg_backend_pid()')).single.single
              as int;
      final read = reader.withSession(
        (s) => EsiCallLogStore(
          now: () => clock,
          boundReleaseLock: false,
        ).routeCountsWithWindow(s, admin),
        enableLogging: false,
      );
      final refused = expectLater(read, throwsA(isA<EsiCallLogUnavailable>()));
      try {
        await observePostgresLock(session, holder, read);
        proxy.holdTargetReads();
        await observer.execute('SELECT pg_advisory_unlock(682997614, 1)');
        await committed;
        expect(await sealedEnd(), day);
      } finally {
        proxy.disconnectClients();
        proxy.releaseTargetReads();
      }
      await refused;
      clock = day;
      final recovered = await EsiCallLogStore(now: () => clock)
          .routeCountsWithWindow(session, admin);
      expect(recovered.window, day);
      expect(recovered.rows.single.total, 5);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('prune and replacement seal commit or roll back together', () async {
      await seed(session, day.subtract(const Duration(days: 5)), route: probe);
      await seed(session, day.add(const Duration(days: 1)), route: probe);
      expect((await store.routeCounts(session, admin)).single.total, 1);
      await rejectSeal();
      clock = grace.add(const Duration(days: 3));
      await expectLater(
        store.prune(session),
        throwsA(isA<EsiCallLogUnavailable>()),
      );
      expect(await sealedEnd(), day);
      expect(
        (await session.db.unsafeQuery(
          'SELECT count(*) FROM esi_call_log_entry',
        )).single.single,
        2,
      );
      await allowSeal();
      expect(await store.prune(session), 1);
      clock = grace;
      final after = await EsiCallLogStore(now: () => clock)
          .routeCountsWithWindow(session, admin);
      expect(after.window, day.add(const Duration(days: 3)));
      expect(after.rows.single.total, 1);
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
