import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:serverpod/serverpod.dart'
    show DatabaseUniqueViolationException, Session;
import 'package:test/test.dart';

import '../test_tools/serverpod_test_tools.dart';

/// Every table the build switch added.
const _newTables = ['sde_check', 'sde_switch', 'sde_build_diff'];

void main() {
  withServerpod('Given a migrated database', (sessionBuilder, endpoints) {
    late Session session;

    setUp(() async {
      session = sessionBuilder.build();
      await session.db.unsafeExecute(
        'TRUNCATE sde_build, sde_check, sde_switch, sde_build_diff',
      );
    });

    Future<Set<String>> columnsOf(String table) async {
      final rows = await session.db.unsafeQuery(
        'SELECT column_name FROM information_schema.columns '
        "WHERE table_name = '$table'",
      );
      return {for (final row in rows) row.single! as String};
    }

    test('when sde_build is read then it has the previous marker and the '
        'hold', () async {
      expect(
        await columnsOf('sde_build'),
        containsAll(['previousMarker', 'held']),
      );
    });

    test('when the new tables are read then each has its columns', () async {
      expect(
        await columnsOf('sde_check'),
        containsAll(['checkedAt', 'latestBuild', 'outcome', 'failureReason']),
      );
      expect(
        await columnsOf('sde_switch'),
        containsAll([
          'kind',
          'fromBuild',
          'toBuild',
          'at',
          'outcome',
          'failureReason',
        ]),
      );
      expect(
        await columnsOf('sde_build_diff'),
        containsAll([
          'fromBuild',
          'toBuild',
          'createdAt',
          'outcome',
          'failureReason',
          'report',
        ]),
      );
    });

    test('when the store writes tables then it writes the new ones', () {
      expect(
        PostgresStaticDataStore.writtenTables.keys,
        containsAll(_newTables),
      );
    });

    test('when a build row is inserted without a hold then it is not '
        'held', () async {
      await session.db.unsafeExecute(
        'INSERT INTO sde_build (build, state, "importedAt") '
        "VALUES (1, 'staged', now())",
      );
      final rows = await session.db.unsafeQuery(
        'SELECT held, "previousMarker" FROM sde_build',
      );
      expect(rows.single, [false, null]);
    });

    test('when two builds are marked previous then the second insert '
        'violates the unique index', () async {
      await session.db.unsafeExecute(
        'INSERT INTO sde_build (build, state, "importedAt", "previousMarker") '
        "VALUES (1, 'previous', now(), true)",
      );
      await expectLater(
        session.db.unsafeExecute(
          'INSERT INTO sde_build (build, state, "importedAt", '
          '"previousMarker") '
          "VALUES (2, 'previous', now(), true)",
        ),
        throwsA(isA<DatabaseUniqueViolationException>()),
      );
    });

    test('when many builds are not previous then their null markers do not '
        'collide', () async {
      for (final build in [1, 2, 3]) {
        await session.db.unsafeExecute(
          'INSERT INTO sde_build (build, state, "importedAt") '
          "VALUES ($build, 'staged', now())",
        );
      }
      final rows = await session.db.unsafeQuery('SELECT 1 FROM sde_build');
      expect(rows, hasLength(3));
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
