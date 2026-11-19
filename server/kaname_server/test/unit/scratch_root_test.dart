import 'dart:io';

import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/scratch_root.dart';
import 'package:test/test.dart';

PostgresConnectionSettings _settings({
  String host = '/run/a/.s.PGSQL.5432',
  int port = 5432,
  String database = 'kaname',
  String? password = 'secret-password',
  bool isUnixSocket = true,
}) => PostgresConnectionSettings(
  host: host,
  port: port,
  database: database,
  user: 'postgres',
  password: password,
  requireSsl: false,
  isUnixSocket: isUnixSocket,
);

void main() {
  final base = Directory('/tmp/base');

  test('the same database always gets the same directory', () {
    expect(
      sdeScratchRootFor(_settings(), base: base).path,
      sdeScratchRootFor(_settings(), base: base).path,
    );
    expect(
      sdeScratchRootFor(_settings(), base: base).path,
      matches(RegExp(r'^/tmp/base/kaname_sde_import/[0-9a-f]{16}$')),
    );
  });

  test('another database, socket, host or port gets another directory', () {
    final paths = {
      sdeScratchRootFor(_settings(), base: base).path,
      sdeScratchRootFor(_settings(database: 'other'), base: base).path,
      sdeScratchRootFor(
        _settings(host: '/run/b/.s.PGSQL.5432'),
        base: base,
      ).path,
      sdeScratchRootFor(
        _settings(host: 'db', isUnixSocket: false),
        base: base,
      ).path,
      sdeScratchRootFor(
        _settings(host: 'db', port: 5433, isUnixSocket: false),
        base: base,
      ).path,
    };

    expect(paths, hasLength(5));
  });

  test('the password and user are not part of the directory', () {
    final one = sdeScratchRootFor(_settings(password: 'one'), base: base);
    final other = sdeScratchRootFor(_settings(password: 'two'), base: base);

    expect(one.path, other.path);
    expect(one.path, isNot(contains('secret')));
  });

  test('a socket path and the TCP port do not mix', () {
    // The port in a socket's settings is for display only.
    expect(
      sdeScratchRootFor(_settings(port: 1), base: base).path,
      sdeScratchRootFor(_settings(port: 2), base: base).path,
    );
  });

  test('the base defaults to the system temp directory', () {
    expect(
      sdeScratchRootFor(_settings()).path,
      startsWith(Directory.systemTemp.path),
    );
  });
}
