import 'dart:async';

import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:kaname_server/src/affiliation/affiliation_runtime.dart';
import 'package:kaname_server/src/affiliation/affiliation_store.dart';
import 'package:kaname_server/src/affiliation/org_tree_config.dart';
import 'package:kaname_server/src/esi/server_esi_runtime.dart';
import 'package:kaname_server/src/esi/server_sso.dart';
import 'package:kaname_server/src/esi/sso_sessions.dart' show ssoDigest;
import 'package:kaname_server/src/generated/future_calls.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/kaname_serverpod.dart';
import 'package:path/path.dart' as p;
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/protocol.dart'
    show FutureCallClaimEntry, FutureCallEntry;
import 'package:serverpod/serverpod.dart';
// ignore: implementation_imports
import 'package:serverpod/src/server/log_manager/session_log.dart'
    show sessionLog;
// ignore: implementation_imports
import 'package:serverpod/src/server/serverpod.dart'
    show ServerpodInternalMethods;
import 'package:test/test.dart';

import '../support/migrated_database.dart';
import 'affiliation_fixture.dart';

const _hour = Duration(hours: 1);
const _startup = (boot: 'current', slot: 0);
const _hourly = (boot: 'current', slot: 1);

void main() {
  test('invalid tree fails before the API listener', () {
    var resolvedConfig = false;
    expect(
      () => KanameServerpod(
        ['--mode', 'test'],
        environment: const {'KANAME_ORG_TREE': 'invalid-tree-sentinel'},
        configOverride: (config) {
          resolvedConfig = true;
          return config;
        },
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.toString(),
          'safe diagnostic',
          allOf(
            contains('KANAME_ORG_TREE'),
            isNot(contains('invalid-tree-sentinel')),
          ),
        ),
      ),
    );
    expect(resolvedConfig, isFalse);
  });

  test('starts unconfigured and queues the startup sweep', () async {
    final fixture = await AffiliationFixture.open();
    final pod = fixture.pod;
    expect(pod.orgTree, isA<UnconfiguredOrgTree>());
    await pod.withSession((s) async {
      await fixture.addIdentity(s, 101);
      final queued = await fixture.queue(s);
      expect(queued.single.identifier, 'kaname-affiliation:current:0');
      await pod.futureCallManager!.runScheduledFutureCalls();
      expect((await AffiliationStore(s).read(101))?.corporationId, 42);
      expect(fixture.wire.single.ids, [101]);
    });
  });

  test('refreshes known identities without a valid SSO registration', () async {
    final sent = <String>[];
    final runtime = _ControlledRuntime((request, bearer, _) async {
      sent.add(request.operationId);
      expect(bearer, isNull);
      return jsonReply(200, [
        {'character_id': 101, 'corporation_id': 42},
      ]);
    });
    final pod = await startComposedAffiliation(openRuntime: () => runtime);
    expect(ServerSso.of(pod), isNull);
    await pod.withSession((s) async {
      final queued = await FutureCallEntry.db.find(s);
      expect(queued.single.identifier, startsWith('kaname-affiliation:'));
      expect(queued.single.identifier, endsWith(':0'));
      await SsoIdentityRow.db.insertRow(
        s,
        SsoIdentityRow(
          characterId: 101,
          characterName: 'Known',
          owner: 'verified-owner',
          blocked: true,
        ),
      );
      await pod.futureCallManager!.runScheduledFutureCalls();
      expect((await AffiliationStore(s).read(101))?.corporationId, 42);
      expect(sent, ['PostCharactersAffiliation']);
    });
    await pod.shutdown(exitProcess: false);
    expect(runtime.closes, 1);
  });

  test(
    'missing Redis configuration or service secret does not stop the server',
    () async {
      for (final (redis, secret) in [(false, true), (true, false)]) {
        final pod = await startComposedAffiliation(
          redis: redis,
          hasSecret: secret,
        );
        await pod.withSession((s) async {
          expect(await FutureCallEntry.db.find(s), isEmpty);
          expect((await s.db.unsafeQuery('SELECT 1')).single.single, 1);
        });
      }
    },
  );

  test(
    'disabled future calls or execution registers no affiliation work',
    () async {
      for (final (enable, execute) in [(false, true), (true, false)]) {
        final pod = await startComposedAffiliation(
          futureCalls: enable,
          execute: execute,
        );
        await pod.withSession((s) async {
          expect(await FutureCallEntry.db.find(s), isEmpty);
        });
      }
    },
  );

  test(
    'persisted sweep and first-known calls skip with no active runtime',
    () async {
      final f = await AffiliationFixture.open(
        active: false,
        persistentLogs: true,
      );
      await f.pod.withSession((s) async {
        final id = (await f.addIdentity(s, 101)).id!;
        final store = AffiliationStore(s);
        await store.save(1, f.now, [
          (identityId: id, corporationId: 51, allianceId: null),
        ]);
        final before = await store.read(101);
        final calls = f.pod.futureCalls;
        await calls
            .callWithDelay(Duration.zero)
            .affiliationCall
            .sweep(AffiliationSweepArgs(boot: 'previous', slot: 1));
        await calls
            .callWithDelay(Duration.zero)
            .affiliationCall
            .firstKnown(AffiliationFirstKnownArgs(identityId: id));
        expect(await f.queue(s), hasLength(2));
        await f.pod.futureCallManager!.runScheduledFutureCalls();
        await sessionLog.flush();
        expect(await f.queue(s), isEmpty);
        final notices = await s.db.unsafeQuery('''
          SELECT count(*) FROM serverpod_log
          WHERE message = 'affiliation: no active runtime; skipped queued work'
          ''');
        expect(notices.single.single, 2);
        expect(await store.read(101), before);
      });
      expect(f.wire, isEmpty);
    },
  );

  test(
    'Serverpod reclaims the abandoned slot and dispatches the next hour',
    () async {
      final f = await AffiliationFixture.open();
      f.respond = (ids) async => jsonReply(200, [
        {'character_id': ids.single, 'corporation_id': 40 + f.wire.length},
      ]);
      await f.pod.withSession((s) async {
        await f.addIdentity(s, 101);
        final abandoned = (await f.queue(s)).single;
        await FutureCallClaimEntry.db.insertRow(
          s,
          FutureCallClaimEntry(
            futureCallId: abandoned.id,
            lastHeartbeatTime: DateTime.utc(2000),
          ),
        );
        final manager = f.pod.futureCallManager!;
        final finished = await _completionEvents(s);
        final startupDone = finished.stream.first;
        await manager.start();
        expect(await startupDone, 'kaname-affiliation:current:0');
        final hourDone = finished.stream.first;
        await f.clock.advance(_hour);
        expect(await hourDone, 'kaname-affiliation:current:1');
        await manager.stop(unregisterAll: false);
        expect(await f.queue(s), isEmpty);
        expect(f.wire.map((call) => call.ids), [
          [101],
          [101],
        ]);
        expect((await AffiliationStore(s).read(101))?.corporationId, 42);
      });
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'coalesces a full sweep but permits first-known and the following hour',
    () async {
      final f = await AffiliationFixture.open();
      final first = Completer<void>();
      final unblock = Completer<void>();
      f.respond = (ids) async {
        if (f.wire.length == 1) {
          first.complete();
          await unblock.future;
        }
        return jsonReply(200, [
          {'character_id': ids.single, 'corporation_id': 42},
        ]);
      };
      await f.pod.withSession((s) async {
        final id = (await f.addIdentity(s, 101)).id!;
        final active = AffiliationRuntime.dispatchSweep(s, _startup);
        await first.future;
        try {
          await f.clock.advance(_hour);
          expect(
            await AffiliationRuntime.dispatchSweep(s, _hourly),
            AffiliationDispatch.coalesced,
          );
          expect(
            await AffiliationRuntime.dispatchFirstKnown(s, id),
            AffiliationDispatch.completed,
          );
          expect(f.log, contains('affiliation: sweep coalesced'));
        } finally {
          unblock.complete();
          await active;
        }
        await f.clock.advance(_hour);
        expect(
          await AffiliationRuntime.dispatchSweep(s, (boot: 'current', slot: 2)),
          AffiliationDispatch.completed,
        );
        expect(f.wire.map((call) => call.ids), [
          [101],
          [101],
          [101],
        ]);
      });
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('shutdown saves the active batch and closes the runtime without another send', () async {
    final f = await AffiliationFixture.open();
    final entered = Completer<void>();
    final release = Completer<void>();
    AffiliationObservation? saved;
    f.respond = (ids) async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
      return jsonReply(200, [
        {'character_id': ids.first, 'corporation_id': 42},
      ]);
    };
    await f.pod.withSession(_seedRegistry);
    f.pod.experimental.shutdownTasks.addTask('observe-save', () async {
      saved = await f.pod.withSession((s) => AffiliationStore(s).read(101));
    });
    await f.pod.futureCallManager!.start();
    await entered.future;
    final drain = f.shutdown();
    release.complete();
    await drain;
    expect(saved?.corporationId, 42);
    expect(f.wire.single.ids, hasLength(1000));
    expect(f.closes, 1);
    expect(f.clock.due, isNull);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('startup and hourly calls send bounded anonymous batches for the whole registry', () async {
    final f = await AffiliationFixture.open();
    await f.pod.withSession((s) async {
      await _seedRegistry(s);
      expect(
        await AffiliationRuntime.dispatchSweep(s, _startup),
        AffiliationDispatch.completed,
      );
      await f.clock.advance(_hour);
      expect(
        await AffiliationRuntime.dispatchSweep(s, _hourly),
        AffiliationDispatch.completed,
      );
      for (final start in [0, 2]) {
        final calls = f.wire.sublist(start, start + 2);
        expect(calls.map((call) => call.ids.length), [1000, 1]);
        expect(
          calls.expand((call) => call.ids),
          List.generate(1001, (i) => 101 + i),
        );
        expect(calls.map((call) => call.token), [null, null]);
      }
      expect((await AffiliationStore(s).read(101))?.corporationId, 42);
      expect((await AffiliationStore(s).read(1101))?.corporationId, 42);
    });
  });

  test(
    'paused affiliation preserves the observation until a later scheduled call',
    () async {
      final f = await AffiliationFixture.open();
      await f.pod.withSession((s) async {
        final id = (await f.addIdentity(s, 101)).id!;
        await AffiliationRuntime.dispatchSweep(s, _startup);
        final store = AffiliationStore(s);
        final before = await store.read(101);
        f.respond = (_) async => jsonReply(503, {'error': 'downtime'});
        expect(await f.client.getAlliances(), isA<EsiError<List<int>>>());
        expect(await f.client.getStatus(), isA<EsiError<Status>>());
        f.respond = (ids) async => jsonReply(
          200,
          ids.isEmpty
              ? {
                  'players': 1,
                  'server_version': '1',
                  'start_time': '2026-11-01T00:00:00Z',
                  'vip': false,
                }
              : [
                  {'character_id': ids.single, 'corporation_id': 43},
                ],
        );
        await AffiliationRuntime.dispatchFirstKnown(s, id);
        expect(await store.read(101), before);
        expect(f.wire.map((call) => call.ids), <List<int>>[
          [101],
          [],
          [],
          [],
        ]);
        await f.clock.advance(_hour);
        await AffiliationRuntime.dispatchSweep(s, _hourly);
        expect((await store.read(101))?.corporationId, 43);
        expect(f.wire.last.ids, [101]);
      });
    },
  );
}

Future<void> _seedRegistry(Session s) async {
  await s.db.unsafeExecute('''
    INSERT INTO esi_identity ("characterId", "characterName", owner, blocked, "wasDetached")
    SELECT n, 'Character ' || n, 'verified-owner', n = 103, n = 104
    FROM generate_series(101, 1101) AS n ORDER BY n
    ''');
  final linked = (await SsoIdentityRow.db.findFirstRow(
    s,
    where: (t) => t.characterId.equals(101),
  ))!;
  final account = await MemberAccountRow.db.insertRow(
    s,
    MemberAccountRow(mainIdentityId: linked.id!),
  );
  await SsoIdentityRow.db.updateRow(s, linked.copyWith(accountId: account.id));
  await SsoHolderRow.db.insertRow(
    s,
    SsoHolderRow(
      characterId: 102,
      phase: 'deviceReserved',
      generation: 2,
      vaultGeneration: 1,
      proofDigest: ssoDigest('fixture-device-claim'),
      grantFingerprint: 'fixture-grant',
      requestedScopes: ['esi-skills.read_skills.v1'],
    ),
  );
  await EsiTokenVaultRow.db.insertRow(
    s,
    EsiTokenVaultRow(
      characterId: 102,
      holderKind: 'server',
      holderId: 'server',
      generation: 2,
      status: 'parked',
      fence: 0,
    ),
  );
}

Future<StreamController<String>> _completionEvents(Session session) async {
  final db = await migratedDatabaseSettings(session);
  final observer = await pg.Connection.open(
    pg.Endpoint(
      host: db.isUnixSocket ? p.relative(db.host) : db.host,
      port: db.port,
      database: db.database,
      username: db.user,
      password: db.password,
      isUnixSocket: db.isUnixSocket,
    ),
    settings: const pg.ConnectionSettings(sslMode: pg.SslMode.disable),
  );
  addTearDown(observer.close);
  await observer.execute('''
    CREATE FUNCTION test_affiliation_done() RETURNS trigger LANGUAGE plpgsql AS \$\$
    BEGIN
      PERFORM pg_notify('test_affiliation_done', OLD.identifier);
      RETURN OLD;
    END
    \$\$;
    CREATE TRIGGER test_affiliation_done AFTER DELETE ON serverpod_future_call
    FOR EACH ROW EXECUTE FUNCTION test_affiliation_done()
    ''', queryMode: pg.QueryMode.simple);
  final events = StreamController<String>.broadcast();
  final subscription = observer.channels['test_affiliation_done'].listen(
    events.add,
  );
  addTearDown(() async {
    await subscription.cancel();
    await events.close();
  });
  await observer.execute('LISTEN test_affiliation_done');
  return events;
}

final class _ControlledRuntime implements ServerEsiRuntime {
  _ControlledRuntime(EsiWireSend send)
    : _scheduler = EsiScheduler(
        state: MemorySchedulerState(),
        key: const [1],
        send: send,
      );

  final EsiScheduler _scheduler;
  int closes = 0;

  @override
  EsiClient client(
    EsiPriority priority, {
    EsiPrincipal? principal,
    bool poll = false,
    int? corporation,
  }) => _scheduler.client(
    priority,
    principal: principal,
    poll: poll,
    corporation: corporation,
  );

  @override
  Future<void> close() async => closes++;
}
