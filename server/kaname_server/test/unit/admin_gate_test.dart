import 'dart:io';

import 'package:kaname_server/src/generated/endpoints.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/admin_gate.dart';
import 'package:path/path.dart' as p;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

const _right = 'accepted-admin-gate-test-key-01234567890';
const _wrong = 'rejected-admin-gate-test-key-01234567890';

void main() {
  late DateTime now;
  late List<String> logs;

  setUp(() {
    now = DateTime.utc(2026, 1, 1, 12);
    logs = [];
  });

  AdminGate gate([String? key = _right]) => AdminGate(
    key: key,
    log: (_, message) => logs.add(message),
    now: () => now,
  );

  test('A3: a password map without adminKey returns null', () async {
    final directory = await Directory.systemTemp.createTemp('kaname-key-');
    addTearDown(() => directory.delete(recursive: true));
    final configDir = await Directory(p.join(directory.path, 'config'))
        .create();
    await File(p.join(configDir.path, 'passwords.yaml')).writeAsString('''
test:
  kanameProbe: 'test-value'
''');
    final pod = Serverpod(
      ['--mode', 'test'],
      Protocol(),
      Endpoints(),
      serverDirectory: directory,
      config: ServerpodConfig(
        apiServer: ServerConfig(
          port: 0,
          publicHost: 'localhost',
          publicPort: 0,
          publicScheme: 'http',
        ),
      ),
    );
    await pod.start(runInGuardedZone: false);
    addTearDown(() => pod.shutdown(exitProcess: false));

    expect(pod.getPassword('kanameProbe'), 'test-value');
    expect(pod.getPassword('adminKey'), isNull);
  });

  test('a configured 40-character key is accepted', () {
    final gatekeeper = gate();
    expect(gatekeeper.configured, isTrue);
    expect(gatekeeper.check(_right), AdminKeyResult.accepted);
    expect(logs, isEmpty);
  });

  test('a wrong key is rejected and logged without either key', () {
    final gatekeeper = gate();
    expect(gatekeeper.check(_wrong), AdminKeyResult.rejected);
    expect(gatekeeper.check(_right), AdminKeyResult.accepted);
    expect(logs.single, contains('rejected'));
    expect(logs.single, isNot(contains(_right)));
    expect(logs.single, isNot(contains(_wrong)));
  });

  test(
    'a 12-character key is logged once at startup and stays unconfigured',
    () {
      const short = 'short-secret';
      final gatekeeper = gate(short);
      expect(gatekeeper.configured, isFalse);
      expect(gatekeeper.check(short), AdminKeyResult.notConfigured);
      expect(gatekeeper.check(_wrong), AdminKeyResult.notConfigured);
      expect(logs.single, contains('shorter than 32'));
      expect(logs.single, isNot(contains(short)));
    },
  );

  test('the pause log line names no key and is logged only once', () {
    final gatekeeper = gate();
    for (var i = 0; i < 10; i++) {
      gatekeeper.check(_wrong);
    }
    expect(gatekeeper.check(_right), AdminKeyResult.tooManyAttempts);
    expect(gatekeeper.check(_wrong), AdminKeyResult.tooManyAttempts);
    final pause = logs.where((line) => line.contains('paused')).single;
    expect(pause, isNot(contains(_right)));
    expect(pause, isNot(contains(_wrong)));
  });

  test('the right key acts 61 seconds after the pause started', () {
    final gatekeeper = gate();
    for (var i = 0; i < 10; i++) {
      gatekeeper.check(_wrong);
    }
    now = now.add(const Duration(seconds: 59));
    expect(gatekeeper.check(_right), AdminKeyResult.tooManyAttempts);
    now = now.add(const Duration(seconds: 2));
    expect(gatekeeper.check(_right), AdminKeyResult.accepted);
  });

  test('nine and nine wrong keys 80 seconds apart start no pause', () {
    final gatekeeper = gate();
    for (var i = 0; i < 9; i++) {
      expect(gatekeeper.check(_wrong), AdminKeyResult.rejected);
    }
    now = now.add(const Duration(seconds: 80));
    for (var i = 0; i < 9; i++) {
      expect(gatekeeper.check(_wrong), AdminKeyResult.rejected);
    }
    expect(gatekeeper.check(_right), AdminKeyResult.accepted);
    expect(logs.where((line) => line.contains('paused')), isEmpty);
  });
}
