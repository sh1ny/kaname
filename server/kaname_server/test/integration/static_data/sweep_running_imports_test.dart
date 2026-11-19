import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_server/src/static_data/sweep_running_imports.dart';
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/migrated_database.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Given a running import record', (sessionBuilder, endpoints) {
    late Session session;
    late PostgresConnectionSettings settings;
    final at = DateTime.utc(2026, 3, 4, 5, 6);

    setUp(() async {
      session = sessionBuilder.build();
      settings = await migratedDatabaseSettings(session);
      await session.db.unsafeExecute('TRUNCATE sde_import');
      await SdeImport.db.insertRow(
        session,
        SdeImport(
          source: SdeImportSource.ccp,
          startedAt: DateTime.utc(2026, 3, 4),
          outcome: SdeImportOutcome.running,
        ),
      );
      await SdeImport.db.insertRow(
        session,
        SdeImport(
          source: SdeImportSource.ccp,
          startedAt: DateTime.utc(2026, 3, 3),
          finishedAt: DateTime.utc(2026, 3, 3, 1),
          outcome: SdeImportOutcome.succeeded,
          build: 5,
        ),
      );
    });

    test('when no import holds the lock then the sweep fails the running '
        'record and leaves the others', () async {
      final swept = await sweepRunningImports(
        session,
        reason: 'worker crashed',
        at: at,
      );

      expect(swept, isTrue);
      final records = await SdeImport.db.find(
        session,
        orderBy: (t) => t.startedAt,
      );
      expect(records.map((r) => (r.outcome, r.failureReason, r.finishedAt)), [
        (SdeImportOutcome.succeeded, null, DateTime.utc(2026, 3, 3, 1)),
        (SdeImportOutcome.failed, 'worker crashed', at),
      ]);
    });

    test('when an import holds the lock then the sweep leaves the record '
        'and reports it', () async {
      final holder = await PostgresStaticDataStore.open(settings);
      addTearDown(holder.close);
      expect(await holder.tryLock(), isTrue);

      final swept = await sweepRunningImports(
        session,
        reason: 'worker crashed',
      );

      expect(swept, isFalse);
      expect(
        (await SdeImport.db.find(
          session,
          where: (t) => t.outcome.equals(SdeImportOutcome.running),
        )),
        hasLength(1),
      );

      await holder.unlock();
      expect(
        await sweepRunningImports(session, reason: 'worker crashed'),
        isTrue,
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
