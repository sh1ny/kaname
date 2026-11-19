import 'dart:io';

import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_server/src/static_data/static_data_lock.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/migrated_database.dart';
import '../test_tools/serverpod_test_tools.dart';

/// Every table the store writes, for the reset between tests.
const _tables = [
  'sde_import',
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

TypedRow _typeRow(int sdeId, {String name = 'T'}) => TypedRow(
  table: 'sde_type',
  sdeId: sdeId,
  values: {
    'groupId': 9101,
    'name': name,
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

RawRecord _rawRecord(String file, int line) => RawRecord(
  file: file,
  line: line,
  key: '$line',
  record: SdeJson({'_key': line}),
);

void main() {
  withServerpod('Given a migrated database', (sessionBuilder, endpoints) {
    late Session session;
    late PostgresConnectionSettings settings;
    late Directory scratch;

    setUp(() async {
      session = sessionBuilder.build();
      settings = await migratedDatabaseSettings(session);
      await session.db.unsafeExecute('TRUNCATE ${_tables.join(', ')}');
      scratch = await Directory.systemTemp.createTemp('kaname_pg_store_');
      addTearDown(() => scratch.delete(recursive: true));
    });

    Future<PostgresStaticDataStore> open() async {
      final store = await PostgresStaticDataStore.open(settings);
      addTearDown(store.close);
      return store;
    }

    /// Stores [build] as [state] with one type row and one raw record.
    Future<void> store1(
      PostgresStaticDataStore store,
      int build,
      BuildState state,
    ) async {
      final id = await store.insertRecord(_running());
      await store.inTransaction((writer) async {
        await writer.insertTyped(build, [_typeRow(build)]);
        await writer.insertRaw(build, [_rawRecord('blueprints.jsonl', 1)]);
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

    Future<ImportResult> importZip(
      SdeFixture fixture,
      PostgresStaticDataStore store,
    ) => ImportSdeJob(
      store: store,
      source: LocalZipSdeSource(fixture.writeTo(scratch), scratchRoot: scratch),
    ).run();

    Future<List<SdeBuild>> builds() =>
        SdeBuild.db.find(session, orderBy: (t) => t.build);

    Future<Set<int>> typeBuilds() async => {
      for (final row in await SdeType.db.find(session)) row.build,
    };

    test('new build is staged next to the active one', () async {
      final store = await open();
      await store1(store, 1, BuildState.active);
      await store1(store, 2, BuildState.staged);

      final stored = await builds();
      expect(stored.map((b) => (b.build, b.state, b.activeMarker)), [
        (1, SdeBuildState.active, true),
        (2, SdeBuildState.staged, null),
      ]);
      expect(await typeBuilds(), {1, 2});
    });

    test('failure after rows leaves no rows and active untouched', () async {
      final store = await open();
      await store1(store, 1, BuildState.active);

      await expectLater(
        store.inTransaction((writer) async {
          await writer.insertTyped(2, [_typeRow(2)]);
          await writer.insertRaw(2, [_rawRecord('blueprints.jsonl', 1)]);
          throw StateError('boom');
        }),
        throwsStateError,
      );

      expect(await typeBuilds(), {1});
      expect(await SdeRecord.db.find(session), hasLength(1));
      expect((await builds()).single.build, 1);
    });

    test('typed columns and raw jsonb round-trip', () async {
      final store = await open();
      await store1(store, 1, BuildState.active);

      final row = (await SdeType.db.find(session)).single;
      expect(row.sdeId, 1);
      expect(row.groupId, 9101);
      expect(row.name, 'T');
      expect(row.published, isTrue);
      expect(row.volume, 5.0);
      expect(row.capacity, isNull);
      expect(row.mass, 1000.0);
      expect(row.raw.value, {'_key': 1, 'extra': 'kept'});
      final record = (await SdeRecord.db.find(session)).single;
      expect(
        (record.file, record.line, record.key),
        ('blueprints.jsonl', 1, '1'),
      );
      final kinds = await session.db.unsafeQuery(
        'SELECT pg_typeof("raw")::text FROM sde_type',
      );
      expect(kinds.single.single, 'jsonb');
    });

    test('build with new types and file imports without code change', () async {
      final fixture = SdeFixture.complete(build: 2000);
      fixture.files['types.jsonl']!.add({
        '_key': 987654,
        'groupID': 9101,
        'name': {'en': 'Brand new type'},
        'brandNewField': {
          'nested': [1, 2, 3],
        },
      });
      fixture.files['brandNewFile.jsonl'] = [
        {'_key': 5, 'whatever': 'value'},
      ];
      final store = await open();

      final result = await importZip(fixture, store);

      expect(result, isA<ImportSucceeded>(), reason: '$result');
      final type = await SdeType.db.findFirstRow(
        session,
        where: (t) => t.sdeId.equals(987654),
      );
      expect(type!.name, 'Brand new type');
      expect(type.raw.value['brandNewField'], {
        'nested': [1, 2, 3],
      });
      final raw = await SdeRecord.db.find(
        session,
        where: (t) => t.file.equals('brandNewFile.jsonl'),
      );
      expect(raw.single.record.value, {'_key': 5, 'whatever': 'value'});
    });

    test('succeeded record commits with rows and holds four reports', () async {
      final store = await open();
      final id = await store.insertRecord(_running());
      late final Set<SdeImportOutcome> seenInside;
      late final int buildRowsInside;
      const report = ImportReport(
        fileCounts: {'types.jsonl': 2},
        drift: DriftReport(
          newFiles: ['x.jsonl'],
          newFields: [],
          wrongTypedFields: [],
          missingFiles: [],
        ),
        badRecords: BadRecordsReport({}),
        knownIds: KnownIdsReport(checked: 0, findings: []),
        fieldCheck: FieldCheckReport([]),
      );

      await store.inTransaction((writer) async {
        await writer.insertTyped(7, [_typeRow(7)]);
        await writer.commitBuild(
          build: 7,
          state: BuildState.active,
          importedAt: _t0,
          recordId: id,
          record: _running().finished(
            ImportOutcome.succeeded,
            at: _t0,
            build: 7,
            report: report,
          ),
        );
        // Another connection still sees the record as running, with no
        // build row: nothing is visible before the commit.
        seenInside = {
          for (final r in await SdeImport.db.find(session)) r.outcome,
        };
        buildRowsInside = (await builds()).length;
      });

      expect(seenInside, {SdeImportOutcome.running});
      expect(buildRowsInside, 0);
      final stored = (await SdeImport.db.find(session)).single;
      expect(stored.outcome, SdeImportOutcome.succeeded);
      expect(stored.build, 7);
      expect(stored.source, SdeImportSource.local);
      expect(stored.finishedAt, _t0);
      expect(stored.fileCounts!.value, {'types.jsonl': 2});
      expect(stored.drift!.value['newFiles'], ['x.jsonl']);
      expect(stored.badRecords!.value['total'], 0);
      expect(stored.knownIds, isNotNull);
      expect(stored.fieldCheck, isNotNull);
      expect(await typeBuilds(), {7});
    });

    test('second importer is skipped while the lock is held', () async {
      final holder = await open();
      expect(await holder.tryLock(), isTrue);
      final fixture = SdeFixture.complete(build: 3000);
      final second = await open();

      final result = await importZip(fixture, second);

      expect(result, isA<ImportSkipped>());
      expect((result as ImportSkipped).reason, 'import already running');
      final records = await SdeImport.db.find(session);
      expect(records.single.outcome, SdeImportOutcome.skipped);
      expect(await builds(), isEmpty);

      await holder.unlock();
      final third = await open();
      expect(await third.tryLock(), isTrue);
    });

    test('commit removes every other staged build', () async {
      final store = await open();
      await store1(store, 1, BuildState.active);
      // Two staged builds, which only a stale state could leave at rest.
      for (final build in [2, 3]) {
        await session.db.unsafeExecute(
          'INSERT INTO sde_build (build, state, "importedAt") '
          "VALUES ($build, 'staged', now())",
        );
        await session.db.unsafeExecute(
          'INSERT INTO sde_type (build, "sdeId", raw) '
          "VALUES ($build, $build, '{}')",
        );
        await session.db.unsafeExecute(
          'INSERT INTO sde_record (build, file, line, key, record) '
          "VALUES ($build, 'f.jsonl', 1, '', '{}')",
        );
      }

      await store1(store, 4, BuildState.staged);

      expect((await builds()).map((b) => b.build), [1, 4]);
      expect(await typeBuilds(), {1, 4});
      final rawBuilds = {
        for (final r in await SdeRecord.db.find(session)) r.build,
      };
      expect(rawBuilds, {1, 4});
    });

    test('first build becomes active', () async {
      final store = await open();

      final result = await importZip(SdeFixture.complete(build: 1000), store);

      expect((result as ImportSucceeded).state, BuildState.active);
      expect((await builds()).map((b) => (b.build, b.state, b.activeMarker)), [
        (1000, SdeBuildState.active, true),
      ]);
    });

    test('later build stays staged', () async {
      final first = await open();
      await importZip(SdeFixture.complete(build: 1000), first);
      final store = await open();

      final result = await importZip(SdeFixture.complete(build: 1001), store);

      expect((result as ImportSucceeded).state, BuildState.staged);
      expect((await builds()).map((b) => (b.build, b.state, b.activeMarker)), [
        (1000, SdeBuildState.active, true),
        (1001, SdeBuildState.staged, null),
      ]);
    });

    test('when the first build is stored then its marker is true and only '
        'one active build can exist', () async {
      final store = await open();
      await store1(store, 1, BuildState.active);

      await expectLater(
        store1(store, 2, BuildState.active),
        throwsA(isA<pg.ServerException>()),
      );
      expect((await builds()).single.activeMarker, isTrue);
    });

    test('when a store is open then session timeouts are five minutes and '
        'the lock key conflicts with the start hook probe', () async {
      final store = await open();
      expect(await store.tryLock(), isTrue);

      final probe = await pg.Connection.open(
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
      addTearDown(probe.close);
      final probed = await probe.runTx(
        (tx) => tx.execute(
          r'SELECT pg_try_advisory_xact_lock($1)',
          parameters: [staticDataAdvisoryLockKey],
        ),
      );
      expect(probed.single.single, isFalse);

      expect(
        await store.currentSetting('idle_in_transaction_session_timeout'),
        '5min',
      );
      expect(await store.currentSetting('statement_timeout'), '5min');
    });

    test('when more than 100 records exist then pruning keeps the newest '
        '100 by start time', () async {
      final store = await open();
      for (var i = 0; i < 105; i++) {
        await store.insertRecord(
          ImportRecord(
            build: i,
            source: SdeSourceKind.ccp,
            startedAt: _t0.add(Duration(minutes: i)),
            outcome: ImportOutcome.skipped,
          ),
        );
      }

      await store.pruneRecords(keep: 100);

      final kept = await SdeImport.db.find(session);
      expect(kept, hasLength(100));
      expect(kept.map((r) => r.build!).reduce((a, b) => a < b ? a : b), 5);
    });

    test('when a record is read by id then that record comes back, not the '
        'newest', () async {
      final store = await open();
      final first = await store.insertRecord(_running());
      await store.insertRecord(
        _running().finished(
          ImportOutcome.skipped,
          at: _t0.add(const Duration(minutes: 1)),
          failureReason: 'import already running',
        ),
      );

      final view = await store.importRecord(first);
      expect(view?.outcome, 'running');
      expect(view?.failureReason, isNull);
      expect(await store.importRecord(first + 1000), isNull);
    });

    test('when records are running then they fail with the reason and '
        'the count comes back', () async {
      final store = await open();
      await store.insertRecord(_running());
      await store.insertRecord(_running());

      final changed = await store.failRunningRecords(
        reason: 'interrupted',
        at: _t0,
      );

      expect(changed, 2);
      final rows = await SdeImport.db.find(session);
      expect(rows.map((r) => r.outcome).toSet(), {SdeImportOutcome.failed});
      expect(rows.first.failureReason, 'interrupted');
    });

    test(
      'when more rows than one batch are inserted then all arrive',
      () async {
        final store = await open();
        final id = await store.insertRecord(_running());
        await store.inTransaction((writer) async {
          await writer.insertTyped(1, [
            for (var i = 0; i < 1203; i++) _typeRow(i),
          ]);
          await writer.commitBuild(
            build: 1,
            state: BuildState.active,
            importedAt: _t0,
            recordId: id,
            record: _running().finished(ImportOutcome.succeeded, at: _t0),
          );
        });
        expect(await SdeType.db.count(session), 1203);
        expect(await store.hasBuild(1), isTrue);
        expect(await store.hasBuild(2), isFalse);
        expect(await store.hasActiveBuild(), isTrue);
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);

  group('PostgresConnectionSettings', () {
    test('when printed then the password is redacted', () {
      const settings = PostgresConnectionSettings(
        host: 'h',
        port: 1,
        database: 'd',
        user: 'u',
        password: 'hunter2',
        requireSsl: true,
      );
      expect(settings.toString(), isNot(contains('hunter2')));
      expect(settings.toString(), contains('<redacted>'));
    });
  });
}
