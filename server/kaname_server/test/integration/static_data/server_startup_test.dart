/// The production startup order of `serve`, which `run` uses: the first
/// announcement's limit runs while the pod's startup is still held after its
/// API listener accepts subscriptions (pre-ship round 33; C29).
library;

import 'dart:async';

import 'package:kaname_client/kaname_client.dart' as wire;
import 'package:kaname_server/server.dart' show serve;
import 'package:kaname_server/src/generated/serverpod.dart';
import 'package:test/test.dart';

import '../support/scratch_database.dart';
import '../support/server_process.dart';

void main() {
  test('a maxConnectionCount below 16 refuses start', () async {
    final database = await ScratchDatabase.create();
    addTearDown(database.drop);
    final server = await ServerProcess.start(
      arguments: ['--apply-migrations'],
      environment: {
        'SERVERPOD_DATABASE_NAME': database.name,
        'SERVERPOD_DATABASE_MAX_CONNECTION_COUNT': '15',
      },
    );
    addTearDown(server.stop);
    expect(
      await server.exitCode.timeout(const Duration(seconds: 35)),
      isNonZero,
    );
    expect(server.output, contains('maxConnectionCount must be at least 16'));
    expect(await server.get('/livez'), isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a client subscribed while startup is held after the API listener '
      'binds gets none within 20 s, before startup ends', () async {
    final database = await ScratchDatabase.create();
    addTearDown(database.drop);
    final pod = _HeldPod(
      ['--mode', 'test', '--apply-migrations'],
      configOverride: (config) => config.copyWith(
        database: (config.database! as PostgresDatabaseConfig).withName(
          database.name,
        ),
      ),
    );
    final served = serve(pod);
    addTearDown(() async {
      if (!pod.hold.isCompleted) pod.hold.complete();
      await served;
      await pod.shutdown(exitProcess: false);
    });
    await pod.listening.future;

    final client = wire.Client('http://127.0.0.1:${pod.server.port}/');
    addTearDown(client.close);
    final first = Completer<wire.BundleAnnouncement>();
    final subscription = client.staticData.bundleAnnouncements().listen(
      (event) {
        if (!first.isCompleted) first.complete(event);
      },
      onError: (Object error) {
        if (!first.isCompleted) first.completeError(error);
      },
    );
    addTearDown(subscription.cancel);
    final event = await first.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => fail('no first event within 20 s of subscribing'),
    );

    expect(event, isA<wire.BundleAnnouncementNone>());
    expect(pod.hold.isCompleted, isFalse, reason: 'startup is still held');
  }, timeout: const Timeout(Duration(minutes: 2)));
}

/// A pod whose `start` does not return until [hold] completes, although its
/// API listener already accepts subscriptions: the production startup with
/// later startup work held, as when it waits on the database.
final class _HeldPod extends Serverpod {
  _HeldPod(super.args, {super.configOverride});

  /// Completes when the API listener accepts connections.
  final Completer<void> listening = Completer<void>();

  /// Ends the held startup.
  final Completer<void> hold = Completer<void>();

  @override
  Future<void> start({bool runInGuardedZone = true}) async {
    await super.start(runInGuardedZone: false);
    listening.complete();
    await hold.future;
  }
}
