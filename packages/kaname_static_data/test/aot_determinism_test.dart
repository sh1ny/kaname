@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:test/test.dart';

/// Verifies assumption A1: the AOT-compiled builder writes the same bytes as
/// the builder on the Dart VM, from one SDE archive.
///
/// Both sides run [buildBundleFromZip], so the archive's decoding, the
/// import's selection of records, their typed projection and the release
/// date's choice are compared as well as the bundle's writer.
void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('kaname_bundle_aot_'));
  tearDown(() => temp.deleteSync(recursive: true));

  test("AOT-compiled builder gives the VM's bytes", () async {
    final fixture = SdeFixture.complete(build: 4242);
    fixture.files['_sde.jsonl'] = [
      {'_key': 'sde', 'buildNumber': 4242, 'releaseDate': '2026-03-04'},
      {'_key': 'sde', 'buildNumber': 4242, 'releaseDate': 'ignored'},
    ];
    fixture.files['categories.jsonl']!.addAll([
      // A duplicate typed key: the import keeps the first record.
      {
        '_key': 9001,
        'name': {'en': 'Duplicate'},
      },
      // A wrong-typed value: the import stores `null`.
      {
        '_key': 9003,
        'name': {'en': 'Odd category'},
        'published': 'yes',
      },
      const RawLine('{not json'),
    ]);
    final zip = fixture.writeTo(temp, 'sde.zip');
    final scratch = Directory('${temp.path}/scratch')..createSync();

    final executable = '${temp.path}/build_zip';
    final compile = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'exe',
      '--output',
      executable,
      'test/support/build_zip_main.dart',
    ]);
    expect(
      compile.exitCode,
      0,
      reason: 'dart compile exe failed:\n${compile.stdout}${compile.stderr}',
    );

    final run = await Process.run(executable, [
      zip.path,
      scratch.path,
    ], stdoutEncoding: null);
    expect(run.exitCode, 0, reason: '${run.stderr}');

    final compiled = Uint8List.fromList(run.stdout as List<int>);
    final onVm = await buildBundleFromZip(zip, scratchRoot: scratch);
    expect(compiled, isNotEmpty);
    expect(compiled, onVm.bytes);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
