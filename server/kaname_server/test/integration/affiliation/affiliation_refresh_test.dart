import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:kaname_server/src/affiliation/affiliation_store.dart';
import 'package:kaname_server/src/esi/esi_affiliation_lookup.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:path/path.dart' as p;
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../support/in_process_pod.dart';
import '../support/migrated_database.dart';
import '../support/scratch_database.dart';

void main() {
  late InProcessPod harness;
  late Session session;
  late AffiliationStore store;
  late DateTime now;
  late List<(AffiliationIssue, int)> issues;
  late List<List<int>> sent;
  late FutureOr<WireOutcome> Function(List<int>) reply;
  late EsiClient client;

  setUpAll(() async {
    harness = await InProcessPod.start(
      configOverride: (config) => config.copyWith(
        futureCallExecutionEnabled: false,
        redis: RedisConfig(enabled: false, host: 'localhost', port: 8091),
      ),
    );
  });
  tearDownAll(() => harness.stop());

  setUp(() async {
    session = await harness.pod.createSession();
    addTearDown(session.close);
    await session.db.unsafeExecute(
      'TRUNCATE esi_identity RESTART IDENTITY CASCADE',
    );
    store = AffiliationStore(session);
    now = DateTime.utc(2026, 11, 27);
    issues = [];
    sent = [];
    reply = (ids) => _ok([for (final id in ids) _row(id, 40, 50)]);
    client = EsiScheduler(
      state: MemorySchedulerState(),
      key: const [1],
      now: () => now,
      send: (request, _, _) async {
        switch (request.operationId) {
          case 'GetAlliances':
            return const WireFailure(connectivityFailure: true);
          case 'GetStatus':
            return WireResponse(EsiResponse(status: 503));
          case 'PostCharactersAffiliation':
            final ids = (jsonDecode(
              utf8.decode(request.body!),
            ) as List<Object?>).cast<int>();
            sent.add(ids);
            return await reply(ids);
          default:
            fail('unexpected operation ${request.operationId}');
        }
      },
    ).client(EsiPriority.sync, poll: true);
  });

  Future<SsoIdentityRow> identity(int id, {Transaction? tx}) =>
      SsoIdentityRow.db.insertRow(
        session,
        SsoIdentityRow(
          characterId: id,
          characterName: 'Character $id',
          owner: 'verified-owner',
          blocked: false,
        ),
        transaction: tx,
      );

  AffiliationJob job({int? identityId}) => AffiliationJob(
    registry: store,
    lookup: (ids) => lookupAffiliation(client, ids),
    now: () => now,
    isStopping: () => false,
    onIssue: (issue, count) => issues.add((issue, count)),
    identityId: identityId,
  );

  test('an empty registry sends no affiliation request', () async {
    await job().run();
    expect(sent, isEmpty);
  });

  test(
    'the next sweep sees an identity that committed behind the cursor',
    () async {
      final inserted = Completer<void>();
      final publish = Completer<void>();
      final pending = session.db.transaction((tx) async {
        await identity(101, tx: tx);
        inserted.complete();
        await publish.future;
      });
      await inserted.future;
      try {
        await session.db.unsafeExecute('''
        INSERT INTO esi_identity ("characterId", owner, "characterName", blocked)
        SELECT number, 'verified-owner', 'Character ' || number, false
        FROM generate_series(102, 1102) AS number
        ''');
        reply = (ids) async {
          if (!publish.isCompleted) {
            publish.complete();
            await pending;
          }
          return _ok([for (final id in ids) _row(id, 40, 50)]);
        };
        await job().run();
        expect(sent.map((page) => page.length), [1000, 1]);
        expect(sent.expand((page) => page), isNot(contains(101)));
        expect(await store.read(101), isNull);
        sent.clear();
        await job().run();
        expect(sent.expand((page) => page), contains(101));
        expect((await store.read(101))?.corporationId, 40);
      } finally {
        if (!publish.isCompleted) publish.complete();
        await pending;
      }
    },
  );

  test('a failed observation write rolls back only its batch', () async {
    final original = await identity(101);
    await job(identityId: original.id).run();
    final previous = await store.read(101);
    sent.clear();
    await session.db.unsafeExecute('''
      INSERT INTO esi_identity ("characterId", owner, "characterName", blocked)
      SELECT number, 'verified-owner', 'Character ' || number, false
      FROM generate_series(102, 1101) AS number
      ''');
    await session.db.unsafeExecute('''
      ALTER TABLE character_affiliation ADD CONSTRAINT test_reject_first_page
      CHECK ("corporationId" <> 41)
      ''');
    addTearDown(
      () => session.db.unsafeExecute('''
      ALTER TABLE character_affiliation DROP CONSTRAINT test_reject_first_page
      '''),
    );
    reply = (ids) =>
        _ok([for (final id in ids) _row(id, id == 102 ? 41 : 42, 50)]);

    expect(await job().run(), AffiliationJobResult.completed);
    expect(sent.map((page) => page.length), [1000, 1]);
    expect(sent.last, [1101]);
    expect(await store.read(101), previous);
    expect(await store.read(103), isNull);
    expect((await store.read(1101))?.corporationId, 42);
    expect(issues, [(AffiliationIssue.writeFailed, 1000)]);
  });

  test(
    'a scheduler refusal leaves the batch unchanged without a retry',
    () async {
      await identity(101);
      await job().run();
      final saved = await store.read(101);
      expect(await client.getAlliances(), isA<EsiTransportFailed<List<int>>>());
      await job().run();
      expect(sent, [
        [101],
      ]);
      expect(await store.read(101), saved);
      expect(issues, [(AffiliationIssue.unavailable, 1)]);
    },
  );

  test(
    'replaces the corporation and clears the alliance on a valid move',
    () async {
      final pilot = await identity(101);
      await job().run();
      expect((await store.read(101))?.allianceId, 50);
      now = now.add(const Duration(hours: 1));
      reply = (_) => _ok([_row(101, 41, null)]);
      await job(identityId: pilot.id).run();
      final saved = (await store.read(101))!;
      expect(saved.corporationId, 41);
      expect(saved.allianceId, isNull);
      expect(saved.observedAt, now);
      expect(sent, [
        [101],
        [101],
      ]);
    },
  );

  test(
    'saves valid returned rows and preserves omitted observations',
    () async {
      await identity(101);
      await identity(102);
      await job().run();
      final omitted = await store.read(102);
      reply = (_) => _ok([_row(101, 41, null)]);
      await job().run();
      expect((await store.read(101))?.corporationId, 41);
      expect(await store.read(102), omitted);
      expect(issues, [(AffiliationIssue.omitted, 1)]);
    },
  );

  test(
    'malformed, duplicate, foreign or invalid responses change no observation',
    () async {
      await identity(101);
      await identity(102);
      await job().run();
      final saved = [await store.read(101), await store.read(102)];
      final first = _row(101, 41, null);
      final badReplies = [
        _ok([
          first,
          {'character_id': 102},
        ]),
        _ok([first, first]),
        _ok([first, _row(103, 41, null)]),
        _ok([first, _row(102, 0, null)]),
        _ok([first, _row(102, 41, -1)]),
        _ok([
          first,
          {..._row(102, 41, null), 'faction_id': -1},
        ]),
        _ok([first, _row(0, 41, null)]),
        _ok([first, _row(102, 41, null), _row(103, 41, null)]),
        const WireFailure(),
        WireResponse(EsiResponse(status: 500)),
      ];
      for (final bad in badReplies) {
        reply = (_) => bad;
        await job().run();
        expect([await store.read(101), await store.read(102)], saved);
      }
      expect(sent.length, 1 + badReplies.length);
    },
  );

  for (final laterValid in [true, false]) {
    test(
      laterValid
          ? 'a lower-order valid result cannot replace the higher-order row'
          : 'a failed higher-order lookup does not block an earlier valid result',
      () async {
        final pilot = await identity(101);
        final earlierEntered = Completer<void>();
        final earlierReply = Completer<WireOutcome>();
        // Read without advancing the generated BIGSERIAL sequence.
        Future<int> latestOrder() async =>
            (await session.db.unsafeQuery(
                  'SELECT last_value FROM character_affiliation_id_seq',
                )).single.single
                as int;
        reply = (_) {
          if (sent.length == 1) {
            earlierEntered.complete();
            return earlierReply.future;
          }
          return laterValid ? _ok([_row(101, 42, 50)]) : const WireFailure();
        };
        final earlier = job().run();
        await earlierEntered.future;
        try {
          final earlierOrder = await latestOrder();
          await job(identityId: pilot.id).run();
          expect(sent, [
            [101],
            [101],
          ]);
          expect(await latestOrder(), greaterThan(earlierOrder));
          if (laterValid) {
            expect((await store.read(101))?.corporationId, 42);
          } else {
            expect(issues, [(AffiliationIssue.unavailable, 1)]);
            expect(await store.read(101), isNull);
          }
          now = now.add(const Duration(minutes: 1));
        } finally {
          earlierReply.complete(_ok([_row(101, 41, 50)]));
          await earlier;
        }
        expect((await store.read(101))?.corporationId, laterValid ? 42 : 41);
      },
    );
  }

  test('an unknown character is distinct from one with no alliance', () async {
    await identity(101);
    expect(await store.read(101), isNull);
    reply = (_) => _ok([_row(101, 40, null)]);
    await job().run();
    expect((await store.read(101))?.corporationId, 40);
    expect((await store.read(101))!.allianceId, isNull);
    expect(await store.read(102), isNull);
  });

  test('deleting an identity removes its unique observation', () async {
    final pilot = await identity(101);
    await job().run();
    Future<int> duplicate() => session.db.unsafeExecute('''
      INSERT INTO character_affiliation
        ("identityId", "corporationId", "observedAt", "lookupOrder")
      SELECT "identityId", "corporationId", "observedAt", "lookupOrder"
      FROM character_affiliation
      ''');
    await expectLater(
      duplicate,
      throwsA(isA<DatabaseUniqueViolationException>()),
    );
    await SsoIdentityRow.db.deleteRow(session, pilot);
    expect(await store.read(101), isNull);
    final rows = await session.db.unsafeQuery(
      'SELECT id FROM character_affiliation',
    );
    expect(rows, isEmpty);
    await job(identityId: pilot.id).run();
    expect(sent, [
      [101],
    ]);
  });

  test('a lookup advances a logically restored high order', () async {
    final pilot = await identity(101);
    const restored = 9000000000;
    await session.db.unsafeExecute('''
      INSERT INTO character_affiliation
        ("identityId", "corporationId", "observedAt", "lookupOrder")
      VALUES (@identity, 12, '2000-01-01', $restored)
      ''', parameters: QueryParameters.named({'identity': pilot.id!}));
    await session.db.unsafeQuery('''
      SELECT setval(pg_get_serial_sequence('character_affiliation', 'id'), $restored)
      ''');
    await job(identityId: pilot.id).run();
    expect((await store.read(101))?.corporationId, 40);
    final order = await session.db.unsafeQuery(
      'SELECT "lookupOrder" FROM character_affiliation',
    );
    expect(order.single.single, restored + 1);
  });

  test('the additive migration preserves the verified registry', () async {
    final scratch = await ScratchDatabase.create();
    addTearDown(scratch.drop);
    final settings = await migratedDatabaseSettings(session);
    final database = await pg.Connection.open(
      pg.Endpoint(
        // Use the relative socket path so a long worktree path still fits
        // sockaddr_un. The test does not change the process working directory.
        host: settings.isUnixSocket ? p.relative(settings.host) : settings.host,
        port: settings.port,
        database: scratch.name,
        username: settings.user,
        password: settings.password,
        isUnixSocket: settings.isUnixSocket,
      ),
      settings: const pg.ConnectionSettings(sslMode: pg.SslMode.disable),
    );
    addTearDown(database.close);
    final registry = await File(p.join('migrations', 'migration_registry.txt'))
        .readAsLines();
    final index = registry.indexWhere(
      (id) => id.endsWith('-org-tree-affiliation'),
    );
    expect(index, greaterThan(0));
    final previous = registry[index - 1];
    final migration = registry[index];
    await database.execute(
      await File(p.join('migrations', previous, 'definition.sql'))
          .readAsString(),
      queryMode: pg.QueryMode.simple,
    );
    await database.execute('''
      INSERT INTO esi_identity (id, "characterId", owner, "characterName", blocked)
      VALUES (10, 101, 'verified-owner', 'Known', false),
             (11, 102, 'other-owner', 'Blocked', true)
      ''');
    await database.execute(
      await File(p.join('migrations', migration, 'migration.sql'))
          .readAsString(),
      queryMode: pg.QueryMode.simple,
    );
    expect(
      await database.execute(
        'SELECT id, "characterId", blocked FROM esi_identity ORDER BY id',
      ),
      [
        [10, 101, false],
        [11, 102, true],
      ],
    );
    expect(
      await database.execute('SELECT id FROM character_affiliation'),
      isEmpty,
    );
  });
}

Map<String, int> _row(int id, int corporation, int? alliance) => {
  'character_id': id,
  'corporation_id': corporation,
  'alliance_id': ?alliance,
};

WireResponse _ok(List<Map<String, int>> rows) =>
    WireResponse(EsiResponse(status: 200, body: utf8.encode(jsonEncode(rows))));
