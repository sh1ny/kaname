import 'package:kaname_server/src/static_data/development_postgres_settings.dart';
import 'package:test/test.dart';

const _embedded = '''
database:
  host: localhost
  port: 8090
  name: kaname
  user: postgres
  dataPath: .serverpod/development/pgdata
''';

const _passwords = '''
shared:
  database: "from-shared"
development:
  database: "from-development"
''';

const _conf = '''
#port = 1111
listen_addresses = ''
port = 5432
unix_socket_directories = '../run'   # where
''';

void main() {
  test('embedded Postgres is the socket its data directory names', () {
    final settings = developmentPostgresSettings(
      configYaml: _embedded,
      passwordsYaml: _passwords,
      serverDirectory: '/srv/kaname_server',
      readFile: _confAt('/srv/kaname_server/.serverpod/development/pgdata'),
    );

    expect(
      settings.host,
      '/srv/kaname_server/.serverpod/development/run/.s.PGSQL.5432',
    );
    expect(settings.isUnixSocket, isTrue);
    expect(settings.port, 5432);
    expect(settings.database, 'kaname');
    expect(settings.user, 'postgres');
    expect(settings.password, 'from-development');
    expect(settings.requireSsl, isFalse);
  });

  test('the last port line of postgresql.conf wins', () {
    final settings = developmentPostgresSettings(
      configYaml: _embedded,
      passwordsYaml: _passwords,
      serverDirectory: '/s',
      readFile: _confAt(
        '/s/.serverpod/development/pgdata',
        "$_conf\nport = 6543\n",
      ),
    );

    expect(settings.host, endsWith('.s.PGSQL.6543'));
  });

  test('without postgresql.conf the server never started the database', () {
    expect(
      () => developmentPostgresSettings(
        configYaml: _embedded,
        passwordsYaml: _passwords,
        serverDirectory: '/s',
        readFile: _noFiles,
      ),
      throwsA(
        isA<DevelopmentSettingsException>().having(
          (e) => e.message,
          'message',
          contains('/s/.serverpod/development/pgdata'),
        ),
      ),
    );
  });

  test('a conf without port or socket directory is refused', () {
    expect(
      () => developmentPostgresSettings(
        configYaml: _embedded,
        passwordsYaml: _passwords,
        serverDirectory: '/s',
        readFile: _confAt('/s/.serverpod/development/pgdata', '# nothing\n'),
      ),
      throwsA(isA<DevelopmentSettingsException>()),
    );
  });

  test('an external database is reached as configured over TCP', () {
    final settings = developmentPostgresSettings(
      configYaml: '''
database:
  host: db.example
  port: 5433
  name: kaname
  user: kaname
  requireSsl: true
''',
      passwordsYaml: 'shared:\n  database: "only-shared"\n',
      serverDirectory: '/s',
      readFile: _noFiles,
    );

    expect(settings.host, 'db.example');
    expect(settings.port, 5433);
    expect(settings.isUnixSocket, isFalse);
    expect(settings.requireSsl, isTrue);
    expect(settings.password, 'only-shared');
  });

  test('no password anywhere leaves it null; the string never prints it', () {
    final settings = developmentPostgresSettings(
      configYaml: _embedded,
      passwordsYaml: '',
      serverDirectory: '/s',
      readFile: _confAt('/s/.serverpod/development/pgdata'),
    );

    expect(settings.password, isNull);
    final withPassword = developmentPostgresSettings(
      configYaml: _embedded,
      passwordsYaml: _passwords,
      serverDirectory: '/s',
      readFile: _confAt('/s/.serverpod/development/pgdata'),
    );
    expect('$withPassword', isNot(contains('from-development')));
  });

  test('a configuration without a database section is refused', () {
    expect(
      () => developmentPostgresSettings(
        configYaml: 'redis:\n  enabled: true\n',
        passwordsYaml: _passwords,
        serverDirectory: '/s',
        readFile: _noFiles,
      ),
      throwsA(isA<DevelopmentSettingsException>()),
    );
  });

  test('postgresql.conf is read from the configured dataPath', () {
    final settings = developmentPostgresSettings(
      configYaml: _embedded.replaceFirst(
        '.serverpod/development/pgdata',
        'elsewhere/pg',
      ),
      passwordsYaml: _passwords,
      serverDirectory: '/s',
      readFile: _confAt('/s/elsewhere/pg'),
    );

    expect(settings.host, '/s/elsewhere/run/.s.PGSQL.5432');
  });
}

/// Reads [conf] as the `postgresql.conf` of [dataDirectory] and nothing else.
String? Function(String path) _confAt(String dataDirectory, [String? conf]) =>
    (path) => path == '$dataDirectory/postgresql.conf' ? conf ?? _conf : null;

String? _noFiles(String path) => null;
