@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'support/bundle_fixture.dart';

/// Verifies assumption A1: the AOT-compiled builder writes the same bytes as
/// the builder on the Dart VM.
void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('kaname_bundle_aot_'));
  tearDown(() => temp.deleteSync(recursive: true));

  test("AOT-compiled builder gives the VM's bytes", () async {
    final executable = '${temp.path}/build_fixture';
    final compile = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'exe',
      '--output',
      executable,
      'test/support/build_fixture_main.dart',
    ]);
    expect(
      compile.exitCode,
      0,
      reason: 'dart compile exe failed:\n${compile.stdout}${compile.stderr}',
    );

    final run = await Process.run(executable, const [], stdoutEncoding: null);
    expect(run.exitCode, 0, reason: '${run.stderr}');

    final compiled = Uint8List.fromList(run.stdout as List<int>);
    expect(compiled, fixtureBuilder().build().bytes);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
