import 'dart:io';

import 'package:kaname_tools/kaname_tools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The server image's Dockerfile and its Dockerfile-specific ignore file.
const _dockerfile = 'deploy/server.Dockerfile';
const _dockerignore = 'deploy/server.Dockerfile.dockerignore';

/// Directories whose Dockerfiles are not the repository's own.
const _skippedDirs = {
  '.claude',
  '.git',
  '.dart_tool',
  '.specwright-local',
  'build',
  'node_modules',
};

/// A base image pinned as `name:tag@sha256:<64 hex>`.
final _pinnedImage = RegExp(r'^[\w./-]+:[\w.-]+@sha256:[0-9a-f]{64}$');

/// A Flutter or Dart version stated in a Dockerfile line.
final _toolchainVersions = [
  RegExp(r'\bdart:\d'),
  RegExp(r'(FLUTTER|DART)_(SDK_)?VERSION', caseSensitive: false),
  RegExp(r'flutter_linux_\d'),
  RegExp(r'(dart|flutter)\D{0,40}\d+\.\d+\.\d+', caseSensitive: false),
  RegExp(r'\d+\.\d+\.\d+\D{0,40}(dart|flutter)', caseSensitive: false),
];

/// The repository root, or fails the test.
String _root() {
  final root = RealFileSystem.locate(Directory.current.path)?.root;
  if (root == null) fail('no workspace root above the test cwd');
  return root;
}

/// Reads [relative] from the repository root, or fails the test.
String _readRepoFile(String relative) {
  final file = File(p.join(_root(), relative));
  if (!file.existsSync()) fail('$relative does not exist');
  return file.readAsStringSync();
}

/// Every Dockerfile in the repository, as paths relative to the root.
List<String> _dockerfiles() {
  final root = _root();
  final found = <String>[];
  void walk(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        if (!_skippedDirs.contains(name)) walk(entity);
      } else if (entity is File &&
          name.contains('Dockerfile') &&
          !name.endsWith('.dockerignore')) {
        found.add(p.relative(entity.path, from: root));
      }
    }
  }

  walk(Directory(root));
  return found..sort();
}

/// The instruction lines of [dockerfile]: continuations joined, comments and
/// blank lines dropped.
List<String> _instructions(String dockerfile) {
  final lines = <String>[];
  final pending = StringBuffer();
  for (final raw in dockerfile.split('\n')) {
    final line = raw.trim();
    if (pending.isEmpty && (line.isEmpty || line.startsWith('#'))) continue;
    if (line.endsWith(r'\')) {
      pending.write('${line.substring(0, line.length - 1).trim()} ');
    } else {
      pending.write(line);
      lines.add(pending.toString());
      pending.clear();
    }
  }
  return lines;
}

/// The instructions of each build stage, split at the `FROM` lines.
List<List<String>> _stages(String dockerfile) {
  final stages = <List<String>>[];
  for (final line in _instructions(dockerfile)) {
    if (line.toUpperCase().startsWith('FROM ')) stages.add([]);
    if (stages.isNotEmpty) stages.last.add(line);
  }
  return stages;
}

/// The image a stage starts from.
String _baseImage(List<String> stage) => stage.first.split(RegExp(r'\s+'))[1];

void main() {
  group('server image Dockerfile', () {
    test('no Dockerfile states a Flutter or Dart version', () {
      final files = _dockerfiles();
      expect(files, contains(_dockerfile));
      for (final file in files) {
        for (final line in _instructions(_readRepoFile(file))) {
          for (final pattern in _toolchainVersions) {
            expect(
              pattern.hasMatch(line),
              isFalse,
              reason: '$file states a toolchain version: $line',
            );
          }
        }
      }
    });

    test('the build stage installs a checksummed mise and installs locked', () {
      final text = _readRepoFile(_dockerfile);
      final build = _stages(text).first.join('\n');
      final ciVersions = {
        for (final m in RegExp(
          r'^\s*version:\s*(\d+\.\d+\.\d+)\s*$',
          multiLine: true,
        ).allMatches(_readRepoFile('.github/workflows/ci.yml')))
          m.group(1),
      };
      final version = RegExp(r'MISE_VERSION=(\S+)')
          .firstMatch(build)
          ?.group(1)
          ?.replaceFirst('v', '');
      expect(version, isNotNull, reason: 'the stage sets MISE_VERSION');
      expect(ciVersions, contains(version), reason: 'same mise as CI pins');
      expect(build, matches(RegExp(r'sha256sum\s+(-c|--check)')));
      expect(build, matches(RegExp(r'[0-9a-f]{64}')));
      expect(build, matches(RegExp(r'mise install\b[^\n]*flutter')));
      expect(build, anyOf(contains('--locked'), contains('MISE_LOCKED')));
    });

    test('the build stage resolves the lockfile as committed', () {
      final build = _stages(_readRepoFile(_dockerfile)).first.join('\n');
      expect(build, contains('pub get --enforce-lockfile'));
      expect(build, contains('dart build cli'));
      expect(build, contains('mise.lock'));
    });

    test('every stage starts from an image pinned by digest', () {
      for (final stage in _stages(_readRepoFile(_dockerfile))) {
        expect(_baseImage(stage), matches(_pinnedImage));
      }
    });

    test('the runtime stage is slim Debian with curl, running non-root', () {
      final stages = _stages(_readRepoFile(_dockerfile));
      expect(stages.length, greaterThanOrEqualTo(2));
      final runtime = stages.last;
      expect(_baseImage(runtime), startsWith('debian:'));
      expect(_baseImage(runtime), contains('-slim@sha256:'));
      expect(runtime.join('\n'), matches(RegExp(r'install\b[^\n]*\bcurl\b')));
      final users = runtime
          .where((line) => line.toUpperCase().startsWith('USER '))
          .map((line) => line.substring(5).trim().split(':').first)
          .toList();
      expect(users, isNotEmpty);
      expect(users.last, isNot(anyOf('root', '0')));
    });
  });

  group('server image build context', () {
    late List<String> rules;
    setUp(() {
      rules = [
        for (final line in _readRepoFile(_dockerignore).split('\n'))
          if (line.trim().isNotEmpty && !line.trim().startsWith('#'))
            line.trim(),
      ];
    });

    test('denies everything first', () {
      expect(rules.first, anyOf('*', '**'));
    });

    test('never admits secrets or generated state', () {
      final first = rules.indexOf('**/config/passwords*.yaml');
      final env = rules.indexOf('**/.env*');
      final state = rules.indexOf('**/.serverpod/');
      for (final index in [first, env, state]) {
        expect(index, isNonNegative);
      }
      // Exclusions come after every allow rule so none re-admits a secret.
      final lastAllow = rules.lastIndexWhere((r) => r.startsWith('!'));
      expect(first, greaterThan(lastAllow));
      expect(env, greaterThan(lastAllow));
      expect(state, greaterThan(lastAllow));
      for (final rule in rules.where((r) => r.startsWith('!'))) {
        expect(rule, isNot(contains('passwords')));
        expect(rule, isNot(contains('.env')));
      }
    });
  });
}
