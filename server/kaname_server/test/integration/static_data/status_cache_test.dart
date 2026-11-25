import 'dart:async';

import 'package:kaname_client/kaname_client.dart' as api;
import 'package:kaname_server/src/static_data/read_work_tokens.dart';
import 'package:kaname_server/src/static_data/static_data_access.dart';
import 'package:kaname_server/src/static_data/static_data_status_cache.dart';
import 'package:serverpod/serverpod.dart' show PostgresDatabaseConfig;
import 'package:test/test.dart';

import '../support/announcer_support.dart';
import '../support/in_process_pod.dart';
import '../support/migrated_database.dart';
import '../support/tcp_proxy.dart';

final class _Read {
  _Read(this.beforeStatement);

  final void Function() beforeStatement;
  final result = Completer<int>();
}

final class _Fixture {
  final clock = FakeClock();
  final reads = <_Read>[];
  late final tokens = ReadWorkTokens(clock: clock);
  late final cache = StaticDataStatusCache<int>(
    clock: clock,
    tokens: tokens,
    read: (beforeStatement) {
      final read = _Read(beforeStatement);
      reads.add(read);
      return read.result.future;
    },
  );
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'a disconnected Postgres answers with only the public status error',
    () async {
      final source = await InProcessPod.start();
      addTearDown(source.stop);
      final database = await source.pod.withSession(migratedDatabaseSettings);
      final proxy = database.isUnixSocket
          ? await TcpProxy.startToUnixSocket(database.host)
          : await TcpProxy.start(database.host, database.port);
      addTearDown(proxy.close);
      final server = await InProcessPod.start(
        configOverride: (config) => config.copyWith(
          healthCheckInterval: Duration.zero,
          futureCallExecutionEnabled: false,
          database: PostgresDatabaseConfig(
            host: '127.0.0.1',
            port: proxy.port,
            user: database.user,
            password: database.password ?? '',
            name: config.database!.name,
          ),
        ),
      );
      addTearDown(server.stop);
      final client = api.Client(server.baseUrl);
      addTearDown(client.close);
      await proxy.close();
      await expectLater(
        client.staticData.status(),
        throwsA(
          isA<api.StaticDataStatusUnavailable>().having(
            (error) => error.toJson(),
            'public fields',
            {'__className__': 'StaticDataStatusUnavailable'},
          ),
        ),
      );
    },
  );

  test('Postgres unreachable answers status unavailable with no host, port or exception text', () async {
    final f = _Fixture();
    final first = f.cache.status();
    f.reads.single.result.completeError(StateError('host:5432 secret'));
    expect(await first, isNull);
    expect(await f.cache.status(), isNull);
    expect(f.reads, hasLength(1));
    f.clock.elapse(const Duration(seconds: 1));
    final retry = f.cache.status();
    expect(f.reads, hasLength(2));
    f.reads.last.result.complete(7);
    expect(await retry, 7);
  });

  test("a call joining after the first caller timed out gets the answer of the read's own session", () async {
    final f = _Fixture();
    final first = f.cache.status();
    f.clock.elapse(const Duration(seconds: 5));
    expect(await first, isNull);
    final second = f.cache.status();
    expect(f.reads, hasLength(1));
    f.reads.single.result.complete(42);
    expect(await second, 42);
    expect(await f.cache.status(), 42);
  });

  test('2,000 calls in a second cost at most two reads and a call beyond 256 waiters fails at once', () async {
    final f = _Fixture();
    final waiting = List.generate(256, (_) => f.cache.status());
    expect(await f.cache.status(), isNull);
    expect(f.reads, hasLength(1));
    f.reads.single.result.complete(1);
    expect(await Future.wait(waiting), everyElement(1));
    for (var i = 0; i < 1743; i++) {
      expect(await f.cache.status(), 1);
    }
    expect(f.reads, hasLength(1));
    f.clock.elapse(const Duration(seconds: 1));
    final next = f.cache.status();
    expect(f.reads, hasLength(2));
    f.reads.last.result.complete(2);
    expect(await next, 2);
  });

  test(
    '2,000 calls during an outage all fail and try the database at most twice',
    () async {
      final f = _Fixture();
      final first = f.cache.status();
      f.reads.single.result.completeError(StateError('unreachable'));
      expect(await first, isNull);
      for (var i = 1; i < 2000; i++) {
        expect(await f.cache.status(), isNull);
      }
      expect(f.reads, hasLength(1));
      f.clock.elapse(const Duration(seconds: 1));
      final retry = f.cache.status();
      f.reads.last.result.completeError(StateError('still unreachable'));
      expect(await retry, isNull);
      expect(f.reads, hasLength(2));
    },
  );

  test('a lost reply fails callers at their 5 s or the 12 s owner deadline and sends no further statement', () async {
    final f = _Fixture();
    final first = f.cache.status();
    final read = f.reads.single;
    read.beforeStatement();
    f.clock.elapse(const Duration(seconds: 5));
    expect(await first, isNull);
    final second = f.cache.status();
    f.clock.elapse(const Duration(seconds: 5));
    expect(await second, isNull);
    final late = f.cache.status();
    f.clock.elapse(const Duration(seconds: 2));
    expect(await late, isNull);
    expect(read.beforeStatement, throwsA(isA<TimeoutException>()));
    read.result.complete(99);
    await _flush();
    expect(await f.cache.status(), isNull);
    f.clock.elapse(const Duration(seconds: 1));
    final retry = f.cache.status();
    expect(f.reads, hasLength(2));
    f.reads.last.result.complete(2);
    expect(await retry, 2);
  });
  test(
    'a 20 s data query is ended at 1 s and its callers get status unavailable',
    () async {
      final server = await InProcessPod.start();
      addTearDown(server.stop);
      final locked = Completer<void>();
      final unlock = Completer<void>();
      final holder = server.pod.withSession(
        (session) => session.db.transaction((tx) async {
          await session.db.unsafeExecute(
            'LOCK TABLE sde_setting_write IN ACCESS EXCLUSIVE MODE',
            transaction: tx,
          );
          locked.complete();
          await unlock.future.timeout(const Duration(seconds: 20));
        }),
      );
      addTearDown(() async {
        unlock.complete();
        await holder;
      });
      await locked.future;

      final failure = Completer<Object>();
      final access = StaticDataAccess(
        withSession: <T>(action) async {
          try {
            return await server.pod.withSession(action);
          } catch (error) {
            failure.complete(error);
            rethrow;
          }
        },
      );
      StaticDataAccess.installForTest(server.pod, access);
      final client = api.Client(server.baseUrl);
      addTearDown(client.close);
      final elapsed = Stopwatch()..start();
      await expectLater(
        client.staticData.status(),
        throwsA(isA<api.StaticDataStatusUnavailable>()),
      );
      expect(elapsed.elapsed, lessThan(const Duration(seconds: 4)));
      expect(
        (await failure.future).toString(),
        contains('canceling statement due to statement timeout'),
      );
    },
  );

  test(
    'a session checkout failing at 3 s fails every joined call at 3 s',
    () async {
      final f = _Fixture();
      final first = f.cache.status();
      f.clock.elapse(const Duration(seconds: 2));
      final second = f.cache.status();
      f.clock.elapse(const Duration(seconds: 1));
      f.reads.single.result.completeError(StateError('checkout failed'));
      expect(await Future.wait([first, second]), [null, null]);
      expect(
        f.clock.now(),
        DateTime.utc(2026, 1, 1).add(const Duration(seconds: 3)),
      );
    },
  );

  test('a hung checkout fails callers by 5 s or 12 s and keeps its token until the session future completes', () async {
    final f = _Fixture();
    final first = f.cache.status();
    f.clock.elapse(const Duration(seconds: 5));
    expect(await first, isNull);
    f.clock.elapse(const Duration(seconds: 5));
    final late = f.cache.status();
    f.clock.elapse(const Duration(seconds: 2));
    expect(await late, isNull);
    f.clock.elapse(const Duration(seconds: 1));
    final second = f.cache.status();
    expect(f.reads, hasLength(2));
    f.cache.invalidate();
    expect(await f.cache.status(), isNull);
    expect(f.reads, hasLength(2));
    f.reads.first.result.complete(1);
    await _flush();
    f.cache.invalidate();
    final third = f.cache.status();
    expect(f.reads, hasLength(3));
    f.reads.last.result.complete(3);
    expect(await third, 3);
    f.reads[1].result.complete(2);
    expect(await second, 2);
    expect(await f.cache.status(), 3);
  });

  test('two reads holding both tokens start no third read and an unrelated query completes', () async {
    final f = _Fixture();
    final first = f.cache.status();
    f.cache.invalidate();
    final second = f.cache.status();
    f.cache.invalidate();
    expect(await f.cache.status(), isNull);
    expect(f.reads, hasLength(2));
    expect(await f.tokens.tryRun(ReadWorkKind.operation, (_) async => 17), 17);
    f.reads[0].result.complete(1);
    f.reads[1].result.complete(2);
    expect(await first, 1);
    expect(await second, 2);
  });

  test('a stalled read admits at most 256 waiters, the rest fail at once, and health still answers', () async {
    final server = await InProcessPod.start();
    addTearDown(server.stop);
    final client = api.Client(server.baseUrl);
    addTearDown(client.close);
    final f = _Fixture();
    final waiting = List.generate(256, (_) => f.cache.status());
    for (var i = 0; i < 20; i++) {
      expect(await f.cache.status(), isNull);
    }
    final report = await client.health.check();
    expect(report.postgres, api.DependencyStatus.up);
    expect(f.reads, hasLength(1));
    f.clock.elapse(const Duration(seconds: 5));
    expect(await Future.wait(waiting), everyElement(isNull));
    f.reads.single.result.complete(1);
    await _flush();
  });

  test(
    'a call joins the current-generation read while both tokens are held',
    () async {
      final f = _Fixture();
      final old = f.cache.status();
      f.cache.invalidate();
      final current = f.cache.status();
      final joiner = f.cache.status();
      expect(f.reads, hasLength(2));
      f.reads.last.result.complete(2);
      expect(await Future.wait([current, joiner]), [2, 2]);
      f.reads.first.result.complete(1);
      expect(await old, 1);
      expect(await f.cache.status(), 2);
    },
  );
  test(
    'a cached answer is returned at once with every waiter place taken',
    () async {
      final f = _Fixture();
      final old = List.generate(255, (_) => f.cache.status());
      f.cache.invalidate();
      final current = f.cache.status();
      final hit = Completer<int?>();
      unawaited(
        f.reads.last.result.future.then<void>((_) {
          scheduleMicrotask(() {
            unawaited(f.cache.status().then(hit.complete));
          });
        }),
      );
      f.reads.last.result.complete(2);
      expect(await hit.future, 2);
      expect(await current, 2);
      expect(f.reads, hasLength(2));
      f.reads.first.result.complete(1);
      expect(await Future.wait(old), everyElement(1));
      expect(await f.cache.status(), 2);
    },
  );

  test(
    'a completed read holds its token through the last statement grace',
    () async {
      final f = _Fixture();
      final old = f.cache.status();
      f.reads.single.beforeStatement();
      f.cache.invalidate();
      final current = f.cache.status();
      f.clock.elapse(const Duration(milliseconds: 500));
      f.reads.first.result.complete(1);
      expect(await old, 1);
      f.cache.invalidate();
      expect(await f.cache.status(), isNull);
      expect(f.reads, hasLength(2));
      f.clock.elapse(const Duration(milliseconds: 500));
      f.cache.invalidate();
      final next = f.cache.status();
      expect(f.reads, hasLength(3));
      f.reads.last.result.complete(3);
      expect(await next, 3);
      f.reads[1].result.complete(2);
      expect(await current, 2);
      expect(await f.cache.status(), 3);
    },
  );

  test('the waiter budget spans an invalidated read and frees a place when a waiter answers', () async {
    final f = _Fixture();
    final old = List.generate(255, (_) => f.cache.status());
    f.clock.elapse(const Duration(seconds: 1));
    f.cache.invalidate();
    final current = f.cache.status();
    expect(await f.cache.status(), isNull);
    expect(f.reads, hasLength(2));
    f.clock.elapse(const Duration(seconds: 4));
    expect(await Future.wait(old), everyElement(isNull));
    final joiner = f.cache.status();
    expect(f.reads, hasLength(2));
    f.reads.last.result.complete(2);
    expect(await Future.wait([current, joiner]), [2, 2]);
    f.reads.first.result.complete(1);
    await _flush();
    expect(await f.cache.status(), 2);
  });

  test('invalidation prevents joining or reusing an older generation even if it finishes last', () async {
    final f = _Fixture();
    final old = f.cache.status();
    f.cache.invalidate();
    final current = f.cache.status();
    expect(f.reads, hasLength(2));
    f.reads.last.result.complete(2);
    expect(await current, 2);
    f.reads.first.result.complete(1);
    expect(await old, 1);
    expect(await f.cache.status(), 2);
    f.cache.invalidate();
    final afterWrite = f.cache.status();
    expect(f.reads, hasLength(3));
    f.reads.last.result.complete(3);
    expect(await afterWrite, 3);
  });
}
