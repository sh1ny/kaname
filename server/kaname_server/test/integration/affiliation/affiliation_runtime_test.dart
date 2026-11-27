import 'dart:async';

import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_server/src/affiliation/affiliation_runtime.dart';
import 'package:kaname_server/src/affiliation/affiliation_store.dart';
import 'package:kaname_server/src/affiliation/org_tree_config.dart';
import 'package:kaname_server/src/esi/server_sso.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/kaname_serverpod.dart';
import 'package:path/path.dart' as p;
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/protocol.dart' show FutureCallClaimEntry;
import 'package:serverpod/serverpod.dart';
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
    final f = await AffiliationFixture.open();
    expect(ServerSso.install(f.pod, const {}, esiRuntime: () => f.esi), isNull);
    await f.pod.withSession((s) async {
      await f.addIdentity(s, 101, blocked: true);
      await f.pod.futureCallManager!.runScheduledFutureCalls();
      expect((await AffiliationStore(s).read(101))?.corporationId, 42);
    });
  });

  test(
    'missing Redis configuration or service secret does not stop the server',
    () async {
      final f = await AffiliationFixture.open(active: false);
      final config = f.pod.config.copyWith(futureCallExecutionEnabled: true);
      expect(
        affiliationAvailability(
          config.copyWith(
            redis: RedisConfig(enabled: false, host: 'localhost', port: 8091),
          ),
          'production',
          'configured',
        ),
        AffiliationAvailability.missingScheduler,
      );
      expect(
        affiliationAvailability(config, 'production', ''),
        AffiliationAvailability.missingScheduler,
      );
      await f.pod.withSession((s) async {
        expect(await f.queue(s), isEmpty);
        expect((await s.db.unsafeQuery('SELECT 1')).single.single, 1);
      });
      expect(f.wire, isEmpty);
    },
  );

  test(
    'disabled future calls or execution registers no affiliation work',
    () async {
      final f = await AffiliationFixture.open(active: false);
      expect(
        affiliationAvailability(f.pod.config, 'production', 'configured'),
        AffiliationAvailability.inactive,
      );
      expect(
        affiliationAvailability(
          f.pod.config.copyWith(
            futureCall: const FutureCallConfig(enabled: false),
            futureCallExecutionEnabled: true,
          ),
          'production',
          'configured',
        ),
        AffiliationAvailability.inactive,
      );
      await f.pod.withSession((s) async => expect(await f.queue(s), isEmpty));
      expect(f.wire, isEmpty);
    },
  );

  test(
    'persisted sweep and first-known calls skip with no active runtime',
    () async {
      final f = await AffiliationFixture.open(active: false);
      await f.pod.withSession((s) async {
        final id = (await f.addIdentity(s, 101)).id!;
        final sweep = await AffiliationRuntime.dispatchSweep(s, _startup);
        final first = await AffiliationRuntime.dispatchFirstKnown(s, id);
        expect(sweep, AffiliationDispatch.inactive);
        expect(first, AffiliationDispatch.inactive);
        expect(await AffiliationStore(s).read(101), isNull);
      });
      expect(f.wire, isEmpty);
    },
  );

  test(
    'Serverpod reclaims the abandoned slot and dispatches the next hour',
    () async {
      final f = await AffiliationFixture.open();
      f.respond = (request, ids) => f.json(request, 200, [
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
      f.respond = (request, ids) async {
        if (f.wire.length == 1) {
          first.complete();
          await unblock.future;
        }
        await f.json(request, 200, [
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
    f.respond = (request, ids) async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
      await f.json(request, 200, [
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
        f.respond = (request, _) => f.json(request, 503, {'error': 'downtime'});
        expect(await f.client.getAlliances(), isA<EsiError<List<int>>>());
        expect(await f.client.getStatus(), isA<EsiError<Status>>());
        f.respond = (request, ids) => f.json(
          request,
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
    INSERT INTO esi_identity ("characterId", "characterName", owner, blocked)
    SELECT n, 'Character ' || n, 'verified-owner', n = 103
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
    SsoHolderRow(characterId: 102, phase: 'deviceHeld', generation: 1),
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
