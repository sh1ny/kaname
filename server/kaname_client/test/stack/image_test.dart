@Tags(['stack'])
library;

import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';

import 'support/stack_support.dart';

/// A cold image build installs Flutter and compiles the server.
const _slow = Timeout(Duration(minutes: 25));

/// The repository files a checkout holds: tracked, plus untracked and not
/// ignored, as paths relative to [root].
Future<List<String>> _checkoutFiles(String root) async {
  final result = await run('git', [
    'ls-files',
    '--cached',
    '--others',
    '--exclude-standard',
    '-z',
  ], workingDirectory: root);
  if (result.exitCode != 0) fail('git ls-files failed: ${result.output}');
  return [
    for (final path in result.output.split('\x00'))
      if (path.isNotEmpty && File('$root/$path').existsSync()) path,
  ];
}

/// Copies the repository's checkout files into a new temporary directory and
/// returns it. The caller deletes it.
Future<Directory> _copyCheckout() async {
  final root = repositoryRoot();
  final copy = await Directory.systemTemp.createTemp('kaname-image-test-');
  for (final path in await _checkoutFiles(root)) {
    final target = File('${copy.path}/$path');
    target.parent.createSync(recursive: true);
    File('$root/$path').copySync(target.path);
  }
  return copy;
}

/// Builds the server image from [context] and tags it [tag].
Future<CommandResult> _build(Directory context, String tag) => run(
  'docker',
  [
    'build',
    '--platform',
    'linux/amd64',
    '--progress=plain',
    '--file',
    'deploy/server.Dockerfile',
    '--tag',
    tag,
    '.',
  ],
  workingDirectory: context.path,
  timeout: const Duration(minutes: 20),
);

/// Writes [content] to [path] under [directory], creating parent folders.
void _plant(Directory directory, String path, String content) {
  File('${directory.path}/$path')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content);
}

void main() {
  final suffix = Random().nextInt(1 << 32).toRadixString(16);
  final tag = 'kaname-image-test:$suffix';
  final secret = 'KANAME-IMAGE-TEST-SECRET-$suffix';
  final copies = <Directory>[];
  var imageBuilt = false;

  /// A fresh copy of the checkout, deleted when the suite ends.
  Future<Directory> checkout() async {
    final copy = await _copyCheckout();
    copies.add(copy);
    return copy;
  }

  tearDownAll(() async {
    if (imageBuilt) await run('docker', ['rmi', '--force', tag]);
    for (final copy in copies) {
      await copy.delete(recursive: true);
    }
  });

  group('Given an image built from a checkout that holds development '
      'secrets', () {
    late CommandResult build;

    setUpAll(() async {
      final context = await checkout();
      // What `mise run server:setup` leaves in a developer's checkout.
      _plant(
        context,
        'server/kaname_server/config/passwords.yaml',
        'shared:\n  sentinel: $secret\n',
      );
      _plant(context, 'server/kaname_server/.env', 'SENTINEL=$secret\n');
      _plant(context, 'server/kaname_server/.env.local', 'SENTINEL=$secret\n');
      _plant(context, 'deploy/.env', 'SENTINEL=$secret\n');
      _plant(
        context,
        'server/kaname_server/.serverpod/development/state',
        '$secret\n',
      );
      // `--no-cache` so the log shows every step's output.
      build = await run(
        'docker',
        [
          'build',
          '--no-cache',
          '--platform',
          'linux/amd64',
          '--progress=plain',
          '--file',
          'deploy/server.Dockerfile',
          '--tag',
          tag,
          '.',
        ],
        workingDirectory: context.path,
        timeout: const Duration(minutes: 20),
      );
      imageBuilt = build.exitCode == 0;
    });

    test('when the build log is read then the Dart that compiled the server '
        'is the mise one and the workspace resolved with the lockfile '
        'enforced', () {
      expect(build.exitCode, 0, reason: build.output);
      // The tests run on the Dart that mise installs from the same mise.lock.
      final dart = Platform.version.split(' ').first;
      expect(build.output, contains('Dart SDK version: $dart '));
      expect(build.output, contains('flutter pub get --enforce-lockfile'));
      expect(build.output, contains('Got dependencies'));
      expect(build.output, contains('dart build cli'));
    }, timeout: _slow);

    test('when the image is searched then it holds no passwords.yaml and no '
        '.env file and none of the planted secret', () async {
      expect(imageBuilt, isTrue, reason: build.output);
      final found = await run('docker', [
        'run',
        '--rm',
        '--platform',
        'linux/amd64',
        '--entrypoint',
        'sh',
        tag,
        '-c',
        // `find` lists secret-named files; `grep` lists files that hold the
        // planted value. Both must print nothing. Guard: config/ is there.
        "find / -xdev \\( -name 'passwords*.yaml' -o -name '.env*' \\) "
            '-print 2>/dev/null; '
            "grep -rIl --exclude-dir=proc --exclude-dir=sys '$secret' / "
            '2>/dev/null; '
            'ls /app/config',
      ]);
      expect(found.exitCode, 0, reason: found.output);
      final lines = found.output
          .split('\n')
          .where((line) => line.isNotEmpty)
          .toList();
      expect(lines, contains('production.yaml'));
      expect(
        lines.where((line) => line.contains('/')),
        isEmpty,
        reason: 'paths of secret files or files holding the secret',
      );
      expect(lines.where((line) => line.contains('passwords')), isEmpty);
    }, timeout: _slow);
  }, timeout: _slow);

  group(
    'Given a checkout whose pubspec.lock does not satisfy the pubspecs',
    () {
      test('when the image is built then it fails at dependency resolution and '
          'resolves no new version', () async {
        const unlocked = 'rxdart';
        final lock = File('${repositoryRoot()}/pubspec.lock')
            .readAsStringSync();
        expect(
          lock,
          isNot(contains('\n  $unlocked:\n')),
          reason: 'pick another package that the lockfile does not hold',
        );
        final context = await checkout();
        final pubspec = File(
          '${context.path}/server/kaname_client/pubspec.yaml',
        );
        final text = pubspec.readAsStringSync();
        expect(text, contains('dependencies:\n'));
        pubspec.writeAsStringSync(
          text.replaceFirst(
            'dependencies:\n',
            'dependencies:\n  $unlocked: any\n',
          ),
        );

        final build = await _build(context, '$tag-stale');

        expect(build.exitCode, isNot(0));
        expect(build.output, contains('flutter pub get --enforce-lockfile'));
        expect(build.output, contains('Unable to satisfy `pubspec.yaml`'));
        expect(
          build.output,
          isNot(contains('dart build cli --target')),
          reason: 'the build stopped before compiling',
        );
        // No image was produced by the failed build.
        final images = await run('docker', ['images', '--quiet', '$tag-stale']);
        expect(images.output.trim(), isEmpty);
      }, timeout: _slow);
    },
  );
}
