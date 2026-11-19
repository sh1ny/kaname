import 'package:kaname_server/src/static_data/postgres_settings_resolver.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../test_tools/serverpod_test_tools.dart';

void main() {
  test('Given an external database config when resolving then the settings '
      'name its host, port, user, TLS and the password', () {
    final config = PostgresDatabaseConfig(
      host: 'db.internal',
      port: 5433,
      user: 'kaname',
      password: 'unused-here',
      name: 'kaname_prod',
      requireSsl: true,
    );

    final settings = postgresSettingsFromConfig(config, password: 'from-file');

    expect(settings.host, 'db.internal');
    expect(settings.port, 5433);
    expect(settings.database, 'kaname_prod');
    expect(settings.user, 'kaname');
    expect(settings.password, 'from-file');
    expect(settings.requireSsl, isTrue);
    expect(settings.isUnixSocket, isFalse);
    expect(settings.toString(), isNot(contains('from-file')));
  });

  withServerpod('Given the embedded Postgres of the test run mode', (
    sessionBuilder,
    endpoints,
  ) {
    test('when resolving then the settings name the Unix socket and a '
        'connection opens through them', () async {
      final session = sessionBuilder.build();

      final settings = await resolveWorkerPostgresSettings(session);

      expect(settings.isUnixSocket, isTrue);
      expect(settings.host, endsWith('.s.PGSQL.${settings.port}'));
      final database = await session.db.unsafeQuery(
        'SELECT current_database()',
      );
      expect(settings.database, database.single.single);
      final store = await PostgresStaticDataStore.open(settings);
      addTearDown(store.close);
      expect(await store.hasActiveBuild(), isFalse);
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
