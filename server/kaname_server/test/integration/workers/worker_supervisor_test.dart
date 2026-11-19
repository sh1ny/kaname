import 'dart:async';

import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/workers/worker_messages.dart';
import 'package:kaname_server/src/workers/worker_process.dart';
import 'package:kaname_server/src/workers/worker_supervisor.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:test/test.dart';

/// A worker the test controls: it runs until the test makes it exit.
final class FakeWorker implements WorkerProcess {
  final StreamController<Object?> _replies = StreamController<Object?>();
  final Completer<String> _exited = Completer<String>();

  /// Every message the supervisor sent, as encoded maps.
  final List<Map<String, Object?>> sent = [];

  /// Whether the supervisor killed the worker.
  bool killed = false;

  @override
  Stream<Object?> get replies => _replies.stream;

  @override
  Future<String> get exited => _exited.future;

  @override
  void send(Map<String, Object?> message) => sent.add(message);

  @override
  void kill() {
    killed = true;
    exit('killed');
  }

  /// Makes the worker exit with [reason], as a crash.
  void exit([String reason = 'isolate exited']) {
    if (!_exited.isCompleted) _exited.complete(reason);
  }

  /// Delivers [message] from the worker.
  void reply(WorkerMessage message) =>
      _replies.add(workerOutboxCodec().encode(message));
}

/// A clock the test moves by hand; every wait completes at once and is
/// recorded.
final class FakeClock {
  DateTime time = DateTime.utc(2026, 1, 1);
  final List<Duration> delays = [];

  DateTime now() => time;

  Future<void> delay(Duration duration) async => delays.add(duration);

  void advance(Duration duration) => time = time.add(duration);
}

const _settings = PostgresConnectionSettings(
  host: 'db',
  port: 5432,
  database: 'kaname',
  user: 'kaname',
  password: 'secret',
  requireSsl: false,
);

/// Lets everything that can run without a new event run.
Future<void> settle() => pumpEventQueue(times: 200);

void main() {
  late FakeClock clock;
  late List<FakeWorker> workers;
  late List<(WorkerLogLevel, String)> logs;
  late List<String> sweepReasons;
  late Future<bool> Function(String) sweep;
  late WorkerSupervisor supervisor;

  setUp(() {
    clock = FakeClock();
    workers = [];
    logs = [];
    sweepReasons = [];
    sweep = (reason) async => true;
    supervisor = WorkerSupervisor(
      name: 'compute',
      spawn: (name) async {
        final worker = FakeWorker();
        workers.add(worker);
        return worker;
      },
      resolveSettings: () async => _settings,
      sweep: (reason) {
        sweepReasons.add(reason);
        return sweep(reason);
      },
      log: (level, message) => logs.add((level, message)),
      now: clock.now,
      delay: clock.delay,
    );
  });
  tearDown(() => supervisor.stop());

  Iterable<String> exitLogs() => [
    for (final (level, message) in logs)
      if (level == WorkerLogLevel.error &&
          message.contains('exited unexpectedly'))
        message,
  ];

  /// Crashes the running worker and lets the supervisor restart it.
  Future<void> crash(String reason) async {
    workers.last.exit(reason);
    await settle();
  }

  test('restart delay doubles to 60 s', () async {
    supervisor.start();
    await settle();
    expect(workers, hasLength(1));

    for (var i = 0; i < 8; i++) {
      await crash('boom $i');
    }

    expect(clock.delays, [
      for (final seconds in [1, 2, 4, 8, 16, 32, 60, 60])
        Duration(seconds: seconds),
    ]);
    expect(workers, hasLength(9));
    expect(exitLogs(), hasLength(8));
    for (var i = 0; i < 8; i++) {
      expect(
        exitLogs().elementAt(i),
        allOf(contains('"compute"'), contains('boom $i')),
      );
    }
  });

  test('delay starts over after 5 minutes of uptime', () async {
    supervisor.start();
    await settle();
    await crash('quick 1');
    await crash('quick 2');
    await crash('quick 3');
    expect(clock.delays, [
      const Duration(seconds: 1),
      const Duration(seconds: 2),
      const Duration(seconds: 4),
    ]);

    clock.advance(const Duration(minutes: 5));
    await crash('after a long run');
    await crash('quick again');

    expect(clock.delays.skip(3), [
      const Duration(seconds: 1),
      const Duration(seconds: 2),
    ]);
  });

  test('delay keeps growing when a run is just under 5 minutes', () async {
    supervisor.start();
    await settle();
    await crash('one');
    clock.advance(const Duration(minutes: 4, seconds: 59));
    await crash('two');

    expect(clock.delays, [
      const Duration(seconds: 1),
      const Duration(seconds: 2),
    ]);
  });

  test('a spawn that keeps failing is logged and retried on the same '
      'schedule', () async {
    var attempts = 0;
    final failing = WorkerSupervisor(
      name: 'compute',
      spawn: (name) async {
        attempts++;
        throw const WorkerSpawnException('no spawn');
      },
      resolveSettings: () async => _settings,
      sweep: (reason) async => true,
      log: (level, message) => logs.add((level, message)),
      now: clock.now,
      // Four waits pass at once; the fifth never ends, so the loop yields.
      delay: (duration) {
        clock.delays.add(duration);
        return clock.delays.length <= 4
            ? Future<void>.value()
            : Completer<void>().future;
      },
    )..start();
    await settle();
    await failing.stop();

    expect(attempts, 5);
    expect(clock.delays, [
      const Duration(seconds: 1),
      const Duration(seconds: 2),
      const Duration(seconds: 4),
      const Duration(seconds: 8),
      const Duration(seconds: 16),
    ]);
    expect(
      logs.where(
        (l) => l.$1 == WorkerLogLevel.error && l.$2.contains('no spawn'),
      ),
      isNotEmpty,
    );
    expect(failing.isRunning, isFalse);
  });

  group('after a crash the lock is retried', () {
    test('every second until it is free, then the records are marked '
        'failed once', () async {
      var calls = 0;
      sweep = (reason) async => ++calls == 3;
      supervisor.start();
      await settle();

      await crash('boom');

      expect(sweepReasons, [
        'worker crashed',
        'worker crashed',
        'worker crashed',
      ]);
      // Two waits between three tries, plus the restart wait.
      expect(
        clock.delays.where((d) => d == WorkerSupervisor.lockRetryInterval),
        hasLength(3),
      );
      expect(
        logs.any((l) => l.$2.contains('marked running imports failed')),
        isTrue,
      );
    });

    test(
      'for 30 s, then the records are left for the next lock holder',
      () async {
        sweep = (reason) async => false;
        supervisor.start();
        await settle();

        await crash('boom');

        // Tries at 0 s, 1 s, ..., 30 s.
        expect(sweepReasons, hasLength(31));
        expect(logs.any((l) => l.$2.contains('still held after 30 s')), isTrue);
        await settle();
        expect(sweepReasons, hasLength(31));
      },
    );

    test('a failing sweep is logged and retried', () async {
      var calls = 0;
      sweep = (reason) async {
        if (++calls == 1) throw StateError('Postgres is down');
        return true;
      };
      supervisor.start();
      await settle();

      await crash('boom');

      expect(sweepReasons, hasLength(2));
      expect(
        logs.any(
          (l) =>
              l.$1 == WorkerLogLevel.warning &&
              l.$2.contains('Postgres is down'),
        ),
        isTrue,
      );
    });
  });

  test('the import is not sent again after a crash', () async {
    supervisor.start();
    await supervisor.ready;
    final answer = supervisor.runImport(const CcpLatestSource());
    await settle();
    final first = workers.single;
    expect(first.sent.map((m) => m['type']), [
      WorkerStart.typeName,
      RunImport.typeName,
    ]);

    await crash('boom');

    final reply = await answer;
    expect(reply, isA<WorkerError>());
    expect((reply as WorkerError).reason, 'worker crashed');
    expect(workers, hasLength(2));
    expect(workers.last.sent.map((m) => m['type']), [WorkerStart.typeName]);
  });

  test(
    'the start message carries the name and the resolved settings',
    () async {
      supervisor.start();
      await supervisor.ready;

      final start =
          workerInboxDecode(workers.single.sent.single) as WorkerStart;

      expect(start.workerName, 'compute');
      expect(start.postgres.host, 'db');
      expect(start.postgres.password, 'secret');
    },
  );

  test('a reply completes its request and a worker log line is forwarded '
      'with the worker name', () async {
    supervisor.start();
    await supervisor.ready;
    final answer = supervisor.runImport(const CcpLatestSource());
    await settle();
    final id = workerInboxDecode(workers.single.sent.last) as RunImport;

    workers.single
      ..reply(
        const WorkerLog(
          workerName: 'compute',
          level: WorkerLogLevel.warning,
          message: 'import failed: boom',
        ),
      )
      ..reply(
        ImportFinished(
          requestId: id.requestId,
          outcome: ImportOutcome.succeeded,
          build: 7,
        ),
      );

    expect((await answer as ImportFinished).build, 7);
    expect(
      logs,
      contains((
        WorkerLogLevel.warning,
        'worker "compute": import failed: boom',
      )),
    );
  });

  test(
    'a request while no worker runs is answered with a typed error',
    () async {
      final reply = await supervisor.runImport(const CcpLatestSource());

      expect(reply, isA<WorkerError>());
      expect(supervisor.isRunning, isFalse);
    },
  );

  test('stop kills the worker, answers pending requests and starts no '
      'restart', () async {
    supervisor.start();
    await supervisor.ready;
    final answer = supervisor.runImport(const CcpLatestSource());
    await settle();

    await supervisor.stop();

    expect(workers.single.killed, isTrue);
    expect((await answer as WorkerError).reason, 'worker stopped');
    expect(workers, hasLength(1));
    expect(exitLogs(), isEmpty);
    expect(supervisor.isRunning, isFalse);
  });
}

/// Decodes a message the supervisor sent to a worker.
WorkerMessage workerInboxDecode(Map<String, Object?> json) =>
    workerInboxCodec().decode(json);
