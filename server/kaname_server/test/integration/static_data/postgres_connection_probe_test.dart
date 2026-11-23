import 'dart:async';

import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../support/in_process_pod.dart';
import '../support/migrated_database.dart';
import '../support/tcp_proxy.dart';
import '../test_tools/serverpod_test_tools.dart';

const _connectTimeout = Duration(seconds: 3);
const _probeDeadline = Duration(seconds: 5);

// A11 (postgres 3.6.0): a withheld handshake timed out at about 3 s.
// Graceful close was still pending after 200 ms with the reply held;
// forced close ended the query and close within the same reporter second
// without releasing the reply.

void main() {
  withServerpod('Postgres connection assumptions', (sessions, _) {
    late PostgresConnectionSettings database;
    late TcpProxy proxy;

    setUp(() async {
      database = await migratedDatabaseSettings(sessions.build());
      proxy = await _proxyTo(database);
      addTearDown(proxy.close);
    });

    test('A11: a silent handshake is bounded by connectTimeout', () async {
      proxy.holdTargetReads();
      final clock = Stopwatch()..start();
      await expectLater(
        _open(database, proxy),
        throwsA(isA<TimeoutException>()),
      );
      expect(proxy.connections, 1);
      expect(clock.elapsed, greaterThanOrEqualTo(_connectTimeout));
      expect(clock.elapsed, lessThan(_probeDeadline));
    });

    for (final force in [false, true]) {
      test('A11: force=$force with a withheld query reply', () async {
        final connection = await _open(database, proxy);
        addTearDown(() => connection.close(force: true));
        proxy.holdTargetReads();
        final before = proxy.bytesFromClients;
        final query = connection.execute('SELECT 42');
        final result = query.then<Object>(
          (rows) => rows,
          onError: (Object error) => error,
        );
        await _until(() => proxy.bytesFromClients > before);

        final close = connection.close(force: force);
        if (force) {
          expect(await result.timeout(_probeDeadline), isA<pg.PgException>());
        } else {
          const hold = Duration(milliseconds: 200);
          await expectLater(
            close.timeout(hold),
            throwsA(isA<TimeoutException>()),
          );
          proxy.releaseTargetReads();
          final rows = await result.timeout(_probeDeadline) as pg.Result;
          expect(rows.single.single, 42);
        }
        await close.timeout(_probeDeadline);
      });
    }

    test(
      'A12: statement_timeout ends a query and resets for the next borrower',
      () async {
        final pool = pg.Pool<void>.withEndpoints(
          [_endpoint(database, proxy)],
          settings: const pg.PoolSettings(
            maxConnectionCount: 1,
            sslMode: pg.SslMode.disable,
          ),
        );
        addTearDown(pool.close);
        const backend =
            "SELECT pg_backend_pid(), current_setting('statement_timeout')";
        final initial = (await pool.execute(backend)).single;
        final clock = Stopwatch();
        await expectLater(
          pool.runTx((tx) async {
            expect((await tx.execute(backend)).single, initial);
            await tx.execute("SET LOCAL statement_timeout = '1s'");
            clock.start();
            await tx.execute('SELECT pg_sleep(30)');
          }),
          throwsA(
            isA<pg.ServerException>().having(
              (error) => error.message,
              'message',
              contains('statement timeout'),
            ),
          ),
        );
        expect(clock.elapsed, greaterThanOrEqualTo(const Duration(seconds: 1)));
        expect(clock.elapsed, lessThan(_probeDeadline));
        expect((await pool.execute(backend)).single, initial);
      },
    );

    test('A12: cutting a socket during a query fails the caller', () async {
      final connection = await _open(database, proxy);
      addTearDown(() => connection.close(force: true));
      final observer = sessions.build();
      final pid = (await connection.execute('SELECT pg_backend_pid()'))
          .single
          .single;
      Future<bool> sleeping() async {
        final rows = await observer.db.unsafeQuery(
          "SELECT count(*) FROM pg_stat_activity "
          "WHERE pid = @pid AND state = 'active' AND query = 'SELECT pg_sleep(30)'",
          parameters: QueryParameters.named({'pid': pid}),
        );
        return rows.single.single == 1;
      }

      final result = expectLater(
        connection.runTx((tx) async {
          await tx.execute("SET LOCAL statement_timeout = '1s'");
          await tx.execute('SELECT pg_sleep(30)');
        }),
        throwsA(isA<pg.PgException>()),
      );
      await _until(sleeping);
      final clock = Stopwatch()..start();
      await proxy.close();
      await result.timeout(_probeDeadline);
      await _until(() async => !await sleeping());
      expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
    });

    for (final holdReplies in [false, true]) {
      test(
        'A13: replaces a pooled backend after '
        '${holdReplies ? 'a lost reply' : 'a clean cancellation'}',
        () => _probePooledTimeout(
          database,
          proxy,
          observer: sessions.build(),
          holdReplies: holdReplies,
        ),
        timeout: const Timeout(Duration(seconds: 95)),
      );
    }

    test(
      'A14: a read-only repeatable-read transaction rejects writes',
      () async {
        final session = sessions.build();
        await session.db.unsafeExecute('CREATE TABLE read_only_probe (id int)');
        await expectLater(
          session.db.transaction(
            (tx) async {
              await session.db.unsafeExecute(
                'SET TRANSACTION READ ONLY',
                transaction: tx,
              );
              final isolation = await session.db.unsafeQuery(
                'SHOW transaction_isolation',
                transaction: tx,
              );
              expect(isolation.single.single, 'repeatable read');
              await session.db.unsafeExecute(
                'INSERT INTO read_only_probe VALUES (1)',
                transaction: tx,
              );
            },
            settings: const TransactionSettings(
              isolationLevel: IsolationLevel.repeatableRead,
            ),
          ),
          throwsA(
            isA<DatabaseQueryException>().having(
              (error) => error.code,
              'SQLSTATE',
              '25006',
            ),
          ),
        );
        expect(
          await session.db.unsafeQuery('SELECT id FROM read_only_probe'),
          isEmpty,
        );
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}

const _backendSnapshot = '''
SELECT pid, backend_start, current_setting('transaction_read_only'),
       nullif(current_setting('kaname.probe', true), '')
FROM pg_stat_activity WHERE pid = pg_backend_pid()
''';

Future<void> _probePooledTimeout(
  PostgresConnectionSettings database,
  TcpProxy proxy, {
  required Session observer,
  required bool holdReplies,
}) async {
  final server = await InProcessPod.start(
    configOverride: (config) => config.copyWith(
      // A new wire connection in this trial is the driver's CancelRequest,
      // not the framework's one-minute health check or future call poller.
      healthCheckInterval: Duration.zero,
      futureCallExecutionEnabled: false,
      sessionLogs: config.sessionLogs.copyWith(consoleEnabled: false),
      database: PostgresDatabaseConfig(
        host: '127.0.0.1',
        port: proxy.port,
        user: database.user,
        password: database.password ?? '',
        name: config.database!.name,
        maxConnectionCount: 16,
      ),
    ),
  );
  addTearDown(server.stop);
  Future<DatabaseResultRow> snapshot() => server.pod.withSession(
    (session) async => (await session.db.unsafeQuery(_backendSnapshot)).single,
  );

  final idle = await snapshot();
  final clock = Stopwatch();
  final dispatched = Completer<int>();
  final call = server.pod
      .withSession((session) async {
        await session.db.transaction((tx) async {
          await session.db.unsafeExecute(
            'SET TRANSACTION READ ONLY',
            transaction: tx,
          );
          await session.db.unsafeExecute(
            "SET LOCAL kaname.probe = 'interrupted'",
            transaction: tx,
          );
          final active = (await session.db.unsafeQuery(
            _backendSnapshot,
            transaction: tx,
          )).single;
          expect(active, [idle[0], idle[1], 'on', 'interrupted']);
          if (holdReplies) proxy.holdTargetReads();
          clock.start();
          dispatched.complete(proxy.connections);
          await session.db.unsafeQuery('SELECT pg_sleep(90)', transaction: tx);
        });
      })
      .whenComplete(clock.stop);
  final failure = expectLater(
    call,
    throwsA(
      holdReplies
          ? anyOf(
              isA<TimeoutException>(),
              isA<DatabaseQueryException>().having(
                (error) => error.message,
                'message',
                contains('Query cancellation failed'),
              ),
            )
          : isA<DatabaseQueryException>().having(
              (error) => error.message,
              'message',
              contains('canceling statement'),
            ),
    ),
  );

  try {
    final connectionsBeforeCancel = await dispatched.future.timeout(
      _probeDeadline,
    );
    await _until(
      () => proxy.connections > connectionsBeforeCancel,
      timeout: const Duration(seconds: 67),
      interval: const Duration(milliseconds: 100),
    );
    final cancelAt = clock.elapsed;
    expect(cancelAt, greaterThanOrEqualTo(const Duration(seconds: 59)));
    expect(cancelAt, lessThan(const Duration(seconds: 66)));
    await failure;
    expect(
      clock.elapsed,
      greaterThanOrEqualTo(Duration(seconds: holdReplies ? 74 : 59)),
    );
    expect(clock.elapsed, lessThan(Duration(seconds: holdReplies ? 82 : 67)));
    print('A13 (held=$holdReplies): cancel $cancelAt, end ${clock.elapsed}');
  } finally {
    proxy.releaseTargetReads();
  }

  final replacement = await snapshot();
  await _until(() async {
    final rows = await observer.db.unsafeQuery(
      'SELECT count(*) FROM pg_stat_activity '
      'WHERE pid = @pid AND backend_start = @started',
      parameters: QueryParameters.named({'pid': idle[0], 'started': idle[1]}),
    );
    return rows.single.single == 0;
  });
  expect(replacement.take(2), isNot(orderedEquals(idle.take(2))));
  expect(replacement.skip(2), orderedEquals(idle.skip(2)));
}

Future<TcpProxy> _proxyTo(PostgresConnectionSettings database) =>
    database.isUnixSocket
    ? TcpProxy.startToUnixSocket(database.host)
    : TcpProxy.start(database.host, database.port);

Future<pg.Connection> _open(
  PostgresConnectionSettings database,
  TcpProxy proxy,
) => pg.Connection.open(
  _endpoint(database, proxy),
  settings: const pg.ConnectionSettings(
    sslMode: pg.SslMode.disable,
    connectTimeout: _connectTimeout,
  ),
);

pg.Endpoint _endpoint(PostgresConnectionSettings database, TcpProxy proxy) =>
    pg.Endpoint(
      host: '127.0.0.1',
      port: proxy.port,
      database: database.database,
      username: database.user,
      password: database.password,
    );

Future<void> _until(
  FutureOr<bool> Function() condition, {
  Duration timeout = _probeDeadline,
  Duration interval = const Duration(milliseconds: 10),
}) async {
  final clock = Stopwatch()..start();
  while (!await condition()) {
    if (clock.elapsed >= timeout) fail('Probe condition never became true');
    await Future<void>.delayed(interval);
  }
}
