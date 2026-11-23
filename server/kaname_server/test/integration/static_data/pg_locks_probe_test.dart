import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_server/src/static_data/static_data_lock.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart'
    show QueryParameters, Session, Transaction;
import 'package:test/test.dart';

import '../support/migrated_database.dart';
import '../support/scratch_database.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('A1: advisory lock layout', (sessions, _) {
    test(
      'identifies job and sweep locks in this database, not another',
      () async {
        final session = sessions.build();
        final settings = await migratedDatabaseSettings(session);
        final other = await ScratchDatabase.create();
        addTearDown(other.drop);
        final databases = (local: settings.database, other: other.name);
        final store = await PostgresStaticDataStore.open(settings);
        addTearDown(store.close);

        expect(await store.tryLock(), isTrue);
        expect(await _holders(session, databases), [settings.database]);
        await store.unlock();
        expect(await _holders(session, databases), isEmpty);

        await session.db.transaction((transaction) async {
          final granted = await session.db.unsafeQuery(
            'SELECT pg_try_advisory_xact_lock(@key)',
            parameters: QueryParameters.named({
              'key': staticDataAdvisoryLockKey,
            }),
            transaction: transaction,
          );
          expect(granted.single.single, isTrue);
          expect(await _holders(session, databases, transaction: transaction), [
            settings.database,
          ]);
        });
        expect(await _holders(session, databases), isEmpty);

        final connection = await pg.Connection.open(
          pg.Endpoint(
            host: settings.host,
            port: settings.port,
            database: other.name,
            username: settings.user,
            password: settings.password,
            isUnixSocket: settings.isUnixSocket,
          ),
          settings: const pg.ConnectionSettings(sslMode: pg.SslMode.disable),
        );
        addTearDown(connection.close);
        final granted = await connection.execute(
          r'SELECT pg_try_advisory_lock($1)',
          parameters: [staticDataAdvisoryLockKey],
        );
        expect(granted.single.single, isTrue);
        expect(await _holders(session, databases), [other.name]);
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}

Future<List<String>> _holders(
  Session session,
  ({String local, String other}) databases, {
  Transaction? transaction,
}) async {
  final rows = await session.db.unsafeQuery(
    '''
SELECT d.datname
FROM pg_locks AS l
JOIN pg_database AS d ON d.oid = l.database
WHERE l.locktype = 'advisory' AND l.granted
  AND l.classid = @high::oid AND l.objid = @low::oid AND l.objsubid = 1
  AND d.datname IN (@local, @other)
''',
    parameters: QueryParameters.named({
      'high': staticDataAdvisoryLockKey >>> 32,
      'low': staticDataAdvisoryLockKey & 0xffffffff,
      'local': databases.local,
      'other': databases.other,
    }),
    transaction: transaction,
  );
  return [for (final row in rows) row.single as String];
}
