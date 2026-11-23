import 'dart:io';

import 'package:kaname_server/src/generated/endpoints.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:path/path.dart' as p;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

void main() {
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
}
