import 'dart:async';
import 'dart:convert';

import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:kaname_server/src/esi/esi_call_log_store.dart';
import 'package:kaname_server/src/esi/sso_sessions.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'support/observe_postgres_lock.dart';
import 'support/observed_database_session.dart';
import 'test_tools/serverpod_test_tools.dart';

const assets = 'GetCharactersCharacterIdAssets';
const other = 'GetCharactersCharacterIdBlueprints';
const probe = 'GetStatus';
final day = DateTime.utc(2000, 11, 25);
const member = EsiCallLogViewer(member: 1);
const admin = EsiCallLogViewer(member: 1, admin: true);
const _actor = (account: 1, session: 1);

Future<void> seed(
  Session session,
  DateTime at, {
  String route = assets,
  int? owner = 1,
  int? character = 10,
  String outcome = 'success',
  Transaction? transaction,
}) async {
  await session.db.unsafeExecute(
    '''
    INSERT INTO esi_call_log_entry
      ("recordedAt", operation, outcome, "latencyMicros", "memberId", "characterId")
    VALUES (@at::timestamp, @route::text, @outcome::text, 0,
            @owner::bigint, @character::bigint)
  ''',
    parameters: QueryParameters.named({
      'at': at,
      'route': route,
      'outcome': outcome,
      'owner': owner,
      'character': character,
    }),
    transaction: transaction,
  );
}

void main() {
  withServerpod('ESI call log', rollbackDatabase: RollbackDatabase.disabled, (
    builder,
    _,
  ) {
    late Session session;
    late EsiCallLogStore store;
    late DateTime now;
    final recent = day.subtract(const Duration(hours: 1));

    setUp(() async {
      session = builder.build();
      addTearDown(session.close);
      await session.db.unsafeExecute(
        'TRUNCATE esi_call_log_entry, esi_call_log_seal, esi_session, '
        'esi_identity, member_account',
      );
      now = day.add(const Duration(minutes: 2));
      SsoSessions(
        now: () => now,
        adminCharacters: {10},
      ).bind(session.serverpod);
      await session.db.transaction((tx) async {
        await session.db.unsafeExecute('''
          INSERT INTO esi_identity (id, "characterId", owner, "characterName", blocked)
          VALUES (1, 10, 'fixture', 'Pilot', false)
        ''', transaction: tx);
        await session.db.unsafeExecute(
          'INSERT INTO member_account (id, "mainIdentityId") VALUES (1, 1)',
          transaction: tx,
        );
        await session.db.unsafeExecute(
          'UPDATE esi_identity SET "accountId" = 1 WHERE id = 1',
          transaction: tx,
        );
        await session.db.unsafeExecute('''
          INSERT INTO esi_session (id, "identityId", "accountId", digest, "expiresAt")
          VALUES (1, 1, 1, 'fixture', '2100-01-01')
        ''', transaction: tx);
      });
      store = EsiCallLogStore(now: () => now);
    });

    test('no supplied secret reaches any stored column', () async {
      const secret = 'synthetic_do_not_store';
      final scheduler = EsiScheduler(
        state: MemorySchedulerState(),
        key: const [1],
        callLog: (row) => store.append(session, row),
        now: () => DateTime.utc(2090),
        onCallLogFailure: () => fail('append rejected'),
        send: (request, bearer, _) async {
          expect(bearer, '${secret}_bearer');
          if (request.target.query.endsWith('throw')) {
            throw StateError('${secret}_exception');
          }
          return WireResponse(
            EsiResponse(
              status: 200,
              headers: {
                'x-ratelimit-group': '${secret}_group',
                'x-ratelimit-limit': '1800/15m',
                'x-ratelimit-used': '1',
                'x-ratelimit-remaining': '1799',
                'etag': '${secret}_etag',
              },
              body: utf8.encode('"${secret}_response"'),
            ),
          );
        },
      );
      final client = scheduler.client(
        EsiPriority.interactive,
        principal: EsiPrincipal(
          application: '${secret}_application',
          character: 10,
          member: 1,
          generation: '${secret}_generation',
          ownershipGeneration: 4,
          bearer: () => '${secret}_bearer',
        ),
      );
      for (final suffix in ['ok', 'throw']) {
        await EsiCall.run(
          client.transport,
          EsiRequest(
            method: EsiMethod.get,
            operationId: assets,
            target: Uri.parse('/characters/10/assets?q=${secret}_$suffix'),
            headers: {'If-None-Match': '${secret}_request_header'},
            body: utf8.encode('${secret}_request_body'),
          ),
          decode: (value) => value as String,
        );
      }
      await scheduler.drainCallLog();
      final rows = await session.db.unsafeQuery(
        'SELECT to_jsonb(e)::text FROM esi_call_log_entry e ORDER BY id',
      );
      expect(rows, hasLength(2));
      for (final row in rows) {
        final Map<String, Object?> values =
            (jsonDecode(row.single! as String) as Map<String, Object?>);
        expect(
          values.keys,
          unorderedEquals([
            'id',
            'recordedAt',
            'operation',
            'outcome',
            'status',
            'cost',
            'latencyMicros',
            'bucket',
            'memberId',
            'characterId',
            'accountExcluded',
            'ownershipGeneration',
          ]),
        );
        expect(row.single, isNot(contains(secret)));
        expect(values['operation'], assets);
        expect(values['bucket'], 'char-asset');
        expect(values['ownershipGeneration'], 4);
      }
    });

    test('exact cutoff filters and deletes only expired rows', () async {
      final cutoff = now.subtract(const Duration(days: 7));
      await seed(session, cutoff);
      await seed(session, cutoff.add(const Duration(microseconds: 1)));
      expect(
        (await store.ownRows(session, _actor)).single.recordedAt,
        cutoff.add(const Duration(microseconds: 1)),
      );
      expect(await store.prune(session), 1);
      expect(
        (await session.db.unsafeQuery('SELECT id FROM esi_call_log_entry')),
        hasLength(1),
      );
    });

    test(
      'own history and pruning agree when the cutoff advances during admission',
      () async {
        final later = now.add(const Duration(minutes: 1));
        final cutoff = later.subtract(const Duration(days: 7));
        final current = cutoff.add(const Duration(microseconds: 1));
        await seed(session, cutoff);
        await seed(session, current);
        final reader = ObservedDatabaseSession(
          session,
          unboundedFirstLock: true,
        );
        final observer = builder.build();
        addTearDown(reader.close);
        addTearDown(observer.close);
        final locked = Completer<int>();
        final release = Completer<void>();
        final writer = session.db.transaction((tx) async {
          await session.db.unsafeExecute(
            'LOCK TABLE esi_session IN ACCESS EXCLUSIVE MODE',
            transaction: tx,
          );
          final holder =
              (await session.db.unsafeQuery(
                    'SELECT pg_backend_pid()',
                    transaction: tx,
                  )).single.single
                  as int;
          locked.complete(holder);
          await release.future;
        });
        late Future<List<EsiCallLogItem>> read;
        try {
          final holder = await Future.any<int>([
            locked.future,
            writer.then(
              (_) => fail('The writer did not hold the sessions table.'),
            ),
          ]);
          read = store.ownRows(reader, _actor);
          await observePostgresLock(observer, holder, read);
          now = later;
        } finally {
          release.complete();
          await writer;
        }
        expect((await read).map((row) => row.recordedAt), [current]);
        expect(await store.prune(session), 1);
        expect(
          (await store.ownRows(session, _actor)).single.recordedAt,
          current,
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('next sweep catches up using its current clock', () async {
      await seed(session, recent);
      expect(await store.prune(session), 0);
      now = now.add(const Duration(days: 8));
      expect(await store.prune(session), 1);
    });

    test('admins and members see only their own rows', () async {
      await seed(session, recent);
      await seed(session, recent, owner: 2);
      await seed(session, recent, character: 11);
      await seed(session, recent, owner: null);
      expect((await store.ownRows(session, _actor)).single.character, 10);
    });

    test('missing viewer and member aggregate access denied', () async {
      await expectLater(
        store.ownRows(session, null),
        throwsA(isA<EsiCallLogDenied>()),
      );
      await expectLater(
        store.routeCounts(session, member),
        throwsA(isA<EsiCallLogDenied>()),
      );
      await expectLater(
        store.routeCounts(session, null),
        throwsA(isA<EsiCallLogDenied>()),
      );
    });

    test(
      'private counts require enough members and exclude refusals from errors',
      () async {
        for (var owner = 1; owner <= 5; owner++) {
          await seed(session, recent, owner: owner, character: owner * 10);
          if (owner != 5) {
            await seed(
              session,
              recent,
              route: other,
              owner: owner,
              character: owner * 10,
            );
          }
        }
        await seed(session, recent, outcome: 'notSent');
        await seed(session, recent, outcome: 'error');
        expect(await store.routeCounts(session, admin), [
          (operation: assets, total: 7, errors: 1),
        ]);
        expect(
          await EsiCallLogStore(
            now: () => now,
            minimumMembers: 6,
          ).routeCounts(session, admin),
          isEmpty,
        );
      },
    );

    test('transfer does not expose prior member rows', () async {
      await seed(session, recent, owner: 2);
      await seed(session, recent, outcome: 'error');
      expect(
        (await store.ownRows(session, _actor)).single.outcome,
        EsiCallLogOutcome.error,
      );
    });

    test('same account and character cannot read a receipt from a prior ownership generation', () async {
      await seed(session, recent);
      await seed(session, recent, route: other);
      await session.db.unsafeExecute(
        'UPDATE esi_identity SET "ownershipGeneration" = 2 WHERE id = 1',
      );
      await session.db.unsafeExecute(
        'UPDATE esi_call_log_entry SET "ownershipGeneration" = 2 '
        'WHERE operation = @operation',
        parameters: QueryParameters.named({'operation': other}),
      );
      expect(
        (await store.ownRows(session, _actor)).map((row) => row.operation),
        [other],
      );
    });

    test('alts contribute one member', () async {
      for (var character = 10; character < 15; character++) {
        await seed(session, recent, character: character);
      }
      expect(await store.routeCounts(session, admin), isEmpty);
    });

    test('late write cannot change released totals during grace', () async {
      now = day;
      final old = recent.subtract(const Duration(days: 1));
      await seed(session, old, route: probe, owner: null, character: null);
      final previous = await store.routeCounts(session, admin);
      expect(previous.single.total, 1);
      await seed(session, recent, route: probe, owner: null, character: null);
      expect(await store.routeCounts(session, admin), previous);
      now = day.add(const Duration(minutes: 1));
      expect((await store.routeCounts(session, admin)).single.total, 2);
    });

    test(
      'public probe aggregate does not require member attribution',
      () async {
        await seed(session, recent, route: probe, owner: null, character: null);
        expect(await store.routeCounts(session, admin), [
          (operation: probe, total: 1, errors: 0),
        ]);
      },
    );

    test('no trusted member excludes a private row', () async {
      for (var owner = 1; owner <= 4; owner++) {
        await seed(session, recent, owner: owner, character: owner * 10);
      }
      await seed(session, recent, owner: null);
      expect((await store.ownRows(session, _actor)).single.character, 10);
      expect(await store.routeCounts(session, admin), isEmpty);
    });

    test(
      'an unattributed error adds nothing to qualifying private totals',
      () async {
        for (var owner = 1; owner <= 5; owner++) {
          await seed(session, recent, owner: owner, character: owner * 10);
        }
        await seed(session, recent, owner: null, outcome: 'error');
        expect(await store.routeCounts(session, admin), [
          (operation: assets, total: 5, errors: 0),
        ]);
      },
    );

    test('expired append cannot alter released counts', () async {
      var failures = 0;
      final runtime = EsiScheduler(
        state: MemorySchedulerState(),
        key: const [1],
        now: () => recent,
        callLog: (row) => store.append(session, row),
        onCallLogFailure: () => failures++,
        send: (_, _, _) async => WireResponse(EsiResponse(status: 304)),
      );
      final result = await runtime.client(EsiPriority.interactive).getStatus();
      expect(result, isA<EsiNotModified<Status>>());
      await runtime.drainCallLog();
      expect(failures, 1);
      expect(
        await session.db.unsafeQuery('SELECT id FROM esi_call_log_entry'),
        isEmpty,
      );
      expect(await store.routeCounts(session, admin), isEmpty);
    });

    test('uncommitted admitted append blocks or joins release', () async {
      final locked = Completer<void>();
      final finish = Completer<void>();
      final held = session.db.transaction((transaction) async {
        await session.db.unsafeQuery(
          'SELECT pg_advisory_xact_lock_shared(682997614)',
          transaction: transaction,
        );
        await seed(
          session,
          recent,
          route: probe,
          owner: null,
          character: null,
          transaction: transaction,
        );
        locked.complete();
        await finish.future;
      });
      try {
        await Future.any([locked.future, held]);
        await expectLater(
          EsiCallLogStore(
            now: () => now,
            waitForReleaseLock: false,
          ).routeCounts(session, admin),
          throwsA(isA<EsiCallLogUnavailable>()),
        );
      } finally {
        finish.complete();
        await held;
      }
      final released = await store.routeCounts(session, admin);
      expect(released.single.total, 1);
      expect(await store.routeCounts(session, admin), released);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
