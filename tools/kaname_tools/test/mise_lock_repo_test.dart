import 'dart:convert';
import 'dart:io';

import 'package:kaname_tools/kaname_tools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The platforms `mise.lock` must cover: the three CI runner families
/// (Linux also covers WSL).
const _platforms = ['linux-x64', 'windows-x64', 'macos-arm64'];

/// One `[[tools.<name>]]` entry of `mise.lock`, with the keys this test
/// checks.
final class _LockedTool {
  _LockedTool(this.name);

  final String name;
  String? backend;
  String? sidecarPath;
  String? sidecarDigest;
  String? provenanceRepository;

  /// Checksums by platform, from `[tools.<name>."platforms.<platform>"]`.
  final Map<String, String> checksums = {};

  bool get isNpm => backend?.startsWith('npm:') ?? false;
}

final _toolHeader = RegExp(r'^\[\[tools\.(.+)\]\]$');
final _platformHeader = RegExp(r'^\[tools\.(.+)\."platforms\.([^"]+)"\]$');
final _provenanceHeader = RegExp(r'^\[tools\.(.+)\.provenance\]$');
final _stringValue = RegExp(r'^(\w+) = "([^"]*)"$');
final _inlineValue = RegExp(r'(\w+) = "([^"]*)"');

/// Reads the generated `mise.lock` [source] into its tool entries.
///
/// The file is written by `mise lock` in a fixed shape, so this reads only
/// the headers and `key = "value"` lines the checks need. Any other table
/// header fails the test, so a format change is noticed rather than
/// skipped.
List<_LockedTool> _parseLock(String source) {
  final tools = <_LockedTool>[];
  _LockedTool? current;
  String? section; // null, 'tool', 'platform:<p>' or 'provenance'.
  for (final raw in const LineSplitter().convert(source)) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (_toolHeader.firstMatch(line) case final match?) {
      current = _LockedTool(match[1]!.replaceAll('"', ''));
      tools.add(current);
      section = 'tool';
      continue;
    }
    if (_platformHeader.firstMatch(line) case final match?) {
      section = 'platform:${match[2]}';
      continue;
    }
    if (_provenanceHeader.firstMatch(line) case final _?) {
      section = 'provenance';
      continue;
    }
    if (line.startsWith('[')) fail('unexpected mise.lock table: $line');
    final tool = current;
    if (tool == null) continue; // Top-level keys such as lockfile_version.
    switch ((section, _stringValue.firstMatch(line))) {
      case ('tool', final match?) when match[1] == 'backend':
        tool.backend = match[2];
      case ('provenance', final match?) when match[1] == 'repository':
        tool.provenanceRepository = match[2];
      case (final String s, final match?)
          when s.startsWith('platform:') && match[1] == 'checksum':
        tool.checksums[s.substring('platform:'.length)] = match[2]!;
      case ('tool', _) when line.startsWith('aube = {'):
        final values = {
          for (final m in _inlineValue.allMatches(line)) m[1]!: m[2]!,
        };
        tool.sidecarPath = values['path'];
        tool.sidecarDigest = values['digest'];
      default:
        break;
    }
  }
  return tools;
}

/// Runs [executable] with [arguments] in [root], failing the test on a
/// non-zero exit.
String _run(String root, String executable, List<String> arguments) {
  final result = Process.runSync(
    executable,
    arguments,
    workingDirectory: root,
    runInShell: Platform.isWindows,
  );
  if (result.exitCode != 0) {
    fail(
      '$executable ${arguments.join(' ')} exited ${result.exitCode}: '
      '${result.stderr}',
    );
  }
  return result.stdout as String;
}

void main() {
  test('mise.lock covers three platforms and every sidecar is committed', () {
    final root = RealFileSystem.locate(Directory.current.path)?.root;
    if (root == null) fail('no workspace root above the test cwd');
    final lockFile = File(p.join(root, 'mise.lock'));
    if (!lockFile.existsSync()) fail('mise.lock does not exist');

    final tools = _parseLock(lockFile.readAsStringSync());
    expect(tools, isNotEmpty, reason: 'mise.lock locks no tool');
    for (final tool in tools) {
      if (tool.isNpm) {
        expect(tool.sidecarPath, isNotNull, reason: '${tool.name}: no sidecar');
        expect(
          tool.sidecarDigest,
          startsWith('sha256:'),
          reason: '${tool.name}: no sidecar digest',
        );
        expect(
          tool.provenanceRepository,
          isNotNull,
          reason:
              '${tool.name}: no provenance pin (run mise install --force '
              'on it after mise lock)',
        );
      } else {
        for (final platform in _platforms) {
          expect(
            tool.checksums[platform],
            startsWith('sha256:'),
            reason: '${tool.name}: no checksum for $platform',
          );
        }
      }
    }

    final listing = jsonDecode(
      _run(root, 'mise', ['lock', '--sidecars', '--json']),
    ) as List<Object?>;
    final tracked = const LineSplitter()
        .convert(_run(root, 'git', ['ls-files', '--', '.mise']))
        .toSet();
    for (final lockEntry in listing) {
      if (lockEntry case {'sidecars': final List<Object?> sidecars}) {
        for (final sidecar in sidecars) {
          if (sidecar case {
            'path': final String path,
            'tool': final String t,
          }) {
            final directory = Directory(p.join(root, path));
            expect(directory.existsSync(), isTrue, reason: '$t: $path missing');
            final files = directory
                .listSync(recursive: true)
                .whereType<File>()
                .map(
                  (f) =>
                      p.posix.joinAll(p.split(p.relative(f.path, from: root))),
                );
            expect(files, isNotEmpty, reason: '$t: $path is empty');
            for (final file in files) {
              expect(tracked, contains(file), reason: '$file is not committed');
            }
          } else {
            fail('unexpected sidecar entry: $sidecar');
          }
        }
      } else {
        fail('unexpected mise lock --sidecars entry: $lockEntry');
      }
    }
  });
}
