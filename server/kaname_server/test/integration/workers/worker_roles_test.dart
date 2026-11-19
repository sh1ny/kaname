import 'package:test/test.dart';

import '../support/scratch_database.dart';
import '../support/server_process.dart';

/// Starting a server process compiles it, which takes a while.
const _slow = Timeout(Duration(minutes: 3));

/// Lines the server writes only when it has started static-data work: the
/// start hook's lines and the compute worker's.
final _workerTraces = RegExp(
  r'worker "compute"|static data: (no active|first)',
);

void main() {
  test('maintenance step starts no worker and exits', () async {
    final database = await ScratchDatabase.create();
    addTearDown(database.drop);
    final server = await ServerProcess.start(
      arguments: ['--role', 'maintenance', '--apply-migrations'],
      environment: {'SERVERPOD_DATABASE_NAME': database.name},
    );
    addTearDown(server.stop);

    final exitCode = await server.exitCode.timeout(const Duration(minutes: 2));

    expect(exitCode, 0, reason: server.output);
    expect(server.output, isNot(contains(_workerTraces)));
  }, timeout: _slow);

  test('test run mode starts no worker', () async {
    final database = await ScratchDatabase.create();
    addTearDown(database.drop);
    final server = await ServerProcess.start(
      arguments: ['--apply-migrations'],
      environment: {'SERVERPOD_DATABASE_NAME': database.name},
    );
    addTearDown(server.stop);
    await server.waitForStatus('/readyz', 200);
    // The hook's decision is logged after the server has started.
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!server.output.contains('static data: not started') &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    expect(server.output, contains('static data: not started'));
    expect(server.output, isNot(contains(_workerTraces)));
  }, timeout: _slow);
}
