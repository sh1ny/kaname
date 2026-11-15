import 'dart:io';

import 'package:kaname_tools/kaname_tools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The runner labels the jobs may use, held as matrix values (D12).
const _runners = {'ubuntu-24.04', 'windows-2025', 'macos-15'};

/// The Linux desktop build's apt packages (A5, task 5.1).
const _aptPackages = [
  'clang',
  'cmake',
  'ninja-build',
  'pkg-config',
  'libgtk-3-dev',
  'libstdc++-12-dev',
];

/// A runner label such as `ubuntu-24.04`, `windows-2025` or `macos-15`.
final _runnerLabel = RegExp(r'(ubuntu|windows|macos)-(\d|latest)');

/// A `uses:` line pinned to a 40-hex SHA with a `# vX.Y.Z` comment.
final _pinnedUses = RegExp(
  r'^\s*-?\s*uses:\s+[\w.-]+/[\w./-]+@[0-9a-f]{40}\s+# v\d+\.\d+\.\d+\s*$',
);

/// Reads [relative] from the repository root, or fails the test.
String _readRepoFile(String relative) {
  final root = RealFileSystem.locate(Directory.current.path)?.root;
  if (root == null) fail('no workspace root above the test cwd');
  final file = File(p.join(root, relative));
  if (!file.existsSync()) fail('$relative does not exist');
  return file.readAsStringSync();
}

/// Converts parsed YAML into plain Dart maps and lists.
Object? _plain(Object? node) => switch (node) {
  final YamlMap map => {
    for (final MapEntry(:key, :value) in map.entries) '$key': _plain(value),
  },
  final YamlList list => [for (final item in list) _plain(item)],
  _ => node,
};

Map<String, Object?> _asMap(Object? value, String what) => switch (value) {
  final Map<String, Object?> map => map,
  _ => fail('$what is not a map: $value'),
};

List<Object?> _asList(Object? value, String what) => switch (value) {
  final List<Object?> list => list,
  _ => fail('$what is not a list: $value'),
};

/// One job of the workflow: its id and plain map.
final class _Job {
  _Job(this.id, this.map);

  final String id;
  final Map<String, Object?> map;

  List<Map<String, Object?>> get steps => [
    for (final step in _asList(map['steps'], '$id steps'))
      _asMap(step, '$id step'),
  ];

  /// Every `run` string, in order.
  List<String> get runs => [
    for (final step in steps)
      if (step['run'] case final String run) run,
  ];

  Map<String, Object?> get strategy => _asMap(map['strategy'], '$id strategy');

  Map<String, Object?> get matrix => _asMap(strategy['matrix'], '$id matrix');

  /// The matrix `include` entries, or one empty entry for a job without a
  /// matrix.
  List<Map<String, Object?>> get combinations => map['strategy'] == null
      ? [<String, Object?>{}]
      : [
          for (final entry in _asList(matrix['include'], '$id include'))
            _asMap(entry, '$id include entry'),
        ];

  /// The job's name for [combination], with `${{ matrix.key }}` resolved.
  String nameFor(Map<String, Object?> combination) {
    final template = (map['name'] as String?) ?? id;
    return template.replaceAllMapped(
      RegExp(r'\$\{\{\s*matrix\.(\w+)\s*\}\}'),
      (match) => '${combination[match[1]]}',
    );
  }

  /// The runner label for [combination].
  String runnerFor(Map<String, Object?> combination) {
    final runsOn = map['runs-on'];
    if (runsOn is! String) fail('$id runs-on is not a string: $runsOn');
    return runsOn.replaceAllMapped(
      RegExp(r'\$\{\{\s*matrix\.(\w+)\s*\}\}'),
      (match) => '${combination[match[1]]}',
    );
  }

  /// The first step that uses [action], or `null`.
  Map<String, Object?>? stepUsing(String action) {
    for (final step in steps) {
      if (step['uses'] case final String uses
          when uses.startsWith('$action@')) {
        return step;
      }
    }
    return null;
  }

  /// The index of the first step whose `run` contains [command], or -1.
  int runIndex(String command) => steps.indexWhere(
    (step) => (step['run'] as String?)?.contains(command) ?? false,
  );
}

void main() {
  late String raw;
  late Map<String, Object?> workflow;
  late Map<String, _Job> jobs;

  setUpAll(() {
    raw = _readRepoFile('.github/workflows/ci.yml');
    workflow = _asMap(_plain(loadYaml(raw)), 'ci.yml');
    jobs = {
      for (final MapEntry(:key, :value) in _asMap(
        workflow['jobs'],
        'jobs',
      ).entries)
        key: _Job(key, _asMap(value, 'job $key')),
    };
  });

  _Job job(String id) => jobs[id] ?? fail('no job $id');

  group('ci.yml', () {
    test('triggers on pull_request and push to main only, never pull_request_target', () {
      final on = _asMap(workflow['on'], 'on');
      expect(on.keys, unorderedEquals(['pull_request', 'push']));
      for (final trigger in ['pull_request', 'push']) {
        expect(_asMap(on[trigger], trigger)['branches'], ['main']);
      }
      final code = raw
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('#'));
      expect(code.join('\n'), isNot(contains('pull_request_target')));
    });

    test('concurrency groups by workflow and ref and cancels in progress', () {
      final concurrency = _asMap(workflow['concurrency'], 'concurrency');
      final group = concurrency['group'] as String;
      expect(group, contains('github.workflow'));
      expect(group, contains('github.ref'));
      expect(concurrency['cancel-in-progress'], isTrue);
    });

    test(
      'no workflow step names a Flutter, Dart, Java, Node or OpenSpec version',
      () {
        final versionedTool = RegExp(
          r'\b(flutter|dart|java|node|openspec)\b[\s@=:-]*v?\d+(\.\d+)*',
          caseSensitive: false,
        );
        const setupActions = [
          'subosito/flutter-action',
          'actions/setup-java',
          'actions/setup-node',
          'dart-lang/setup-dart',
        ];
        const versionInputs = {
          'flutter-version',
          'java-version',
          'node-version',
          'dart-version',
          'sdk',
          'channel',
          'tool_versions',
          'mise_toml',
        };
        for (final MapEntry(key: id, value: job) in jobs.entries) {
          for (final step in job.steps) {
            final uses = (step['uses'] as String?) ?? '';
            for (final action in setupActions) {
              expect(uses, isNot(startsWith(action)), reason: id);
            }
            final inputs = switch (step['with']) {
              final Map<String, Object?> map => map,
              _ => const <String, Object?>{},
            };
            for (final input in inputs.keys) {
              expect(versionInputs, isNot(contains(input)), reason: id);
            }
            if (step['run'] case final String run) {
              expect(versionedTool.hasMatch(run), isFalse, reason: '$id: $run');
            }
          }
        }
      },
    );

    test(
      'every job sets up tools through the pinned mise action in locked mode',
      () {
        for (final MapEntry(key: id, value: job) in jobs.entries) {
          final setup = job.stepUsing('jdx/mise-action');
          if (setup == null) fail('$id has no jdx/mise-action step');
          final inputs = _asMap(setup['with'], '$id mise-action with');
          // Locked mode is mise-action's own behaviour when mise.lock exists,
          // so no input may turn it off or change the install arguments.
          expect(inputs.keys, everyElement(isIn(['version', 'cache'])));
          expect(
            inputs['version'],
            matches(RegExp(r'^\d{4}\.\d+\.\d+$')),
            reason: '$id: mise version must be exact',
          );
          final setupIndex = job.steps.indexOf(setup);
          final firstRun = job.steps.indexWhere((s) => s['run'] != null);
          expect(setupIndex, lessThan(firstRun), reason: id);
        }
      },
    );

    test('check job runs resolve then check on linux, windows and macos with '
        'fail-fast off', () {
      final check = job('check');
      expect(check.strategy['fail-fast'], isFalse);
      expect(
        {
          for (final c in check.combinations)
            check.nameFor(c): check.runnerFor(c),
        },
        {
          'check (linux)': 'ubuntu-24.04',
          'check (windows)': 'windows-2025',
          'check (macos)': 'macos-15',
        },
      );
      final resolve = check.runIndex('mise run resolve');
      final run = check.runIndex('mise run check');
      expect(resolve, isNonNegative);
      expect(run, greaterThan(resolve));
    });

    test('build job builds six targets on their runner families with fail-fast '
        'off', () {
      final build = job('build');
      expect(build.strategy['fail-fast'], isFalse);
      final names = {
        for (final c in build.combinations)
          build.nameFor(c): build.runnerFor(c),
      };
      expect(names, {
        'build (web)': 'ubuntu-24.04',
        'build (linux)': 'ubuntu-24.04',
        'build (android)': 'ubuntu-24.04',
        'build (windows)': 'windows-2025',
        'build (macos)': 'macos-15',
        'build (ios)': 'macos-15',
      });
      expect(build.runIndex('mise run resolve'), isNonNegative);
      final buildStep = build.steps.firstWhere(
        (s) => (s['run'] as String?)?.contains('matrix.command') ?? false,
        orElse: () => fail('no step running the matrix command'),
      );
      expect(buildStep['run'], contains('mise exec --'));
      expect(buildStep['working-directory'], 'app');
      final commands = {
        for (final c in build.combinations) c['target']: c['command'],
      };
      for (final command in commands.values) {
        expect(command, contains('--release'));
      }
      expect(commands, {
        'web': contains('flutter build web'),
        'linux': contains('flutter build linux'),
        'android': contains('flutter build apk'),
        'windows': contains('flutter build windows'),
        'macos': contains('flutter build macos'),
        'ios': contains('flutter build ios'),
      });
      // Only the Linux target needs the desktop toolchain from apt.
      final apt = build.steps.firstWhere(
        (s) => (s['run'] as String?)?.contains('apt-get install') ?? false,
        orElse: () => fail('no apt-get install step'),
      );
      expect(apt['if'], contains("matrix.target == 'linux'"));
      for (final package in _aptPackages) {
        expect(apt['run'], contains(package));
      }
    });

    test('ios build passes --no-codesign', () {
      final ios = job('build').combinations
          .singleWhere((c) => c['target'] == 'ios');
      expect(ios['command'], contains('--no-codesign'));
      for (final c in job('build').combinations) {
        if (c['target'] != 'ios') {
          expect(c['command'], isNot(contains('--no-codesign')));
        }
      }
    });

    test('spec job runs spec:validate on linux', () {
      final spec = job('spec');
      expect(spec.runnerFor({}), 'ubuntu-24.04');
      expect(spec.runIndex('mise run spec:validate'), isNonNegative);
    });

    test('licences job runs the check before generating and uploading the SBOM '
        'for 90 days', () {
      final licences = job('licences');
      expect(licences.runnerFor({}), 'ubuntu-24.04');
      final check = licences.runIndex('mise run licences');
      final sbom = licences.runIndex('mise run sbom');
      final upload = licences.steps.indexWhere(
        (s) => ((s['uses'] as String?) ?? '').startsWith(
          'actions/upload-artifact@',
        ),
      );
      expect(check, isNonNegative);
      expect(sbom, greaterThan(check));
      expect(upload, greaterThan(sbom));
      final inputs = _asMap(licences.steps[upload]['with'], 'upload with');
      expect(inputs['name'], 'sbom-cyclonedx');
      expect(inputs['path'], 'build/sbom/kaname.cdx.json');
      expect(inputs['retention-days'], 90);
      expect(inputs['if-no-files-found'], 'error');
      // No step may force the upload after a failed licence check.
      for (final step in licences.steps) {
        expect('${step['if'] ?? ''}', isNot(contains('always()')));
      }
    });

    test('signoff job runs only on pull_request with full history and the PR '
        'author', () {
      final signoff = job('signoff');
      expect(signoff.runnerFor({}), 'ubuntu-24.04');
      expect(
        signoff.map['if'],
        contains("github.event_name == 'pull_request'"),
      );
      final checkout = signoff.stepUsing('actions/checkout');
      if (checkout == null) fail('signoff has no checkout step');
      expect(_asMap(checkout['with'], 'checkout with')['fetch-depth'], 0);
      final step = signoff.steps.firstWhere(
        (s) => (s['run'] as String?)?.contains('mise run signoff') ?? false,
        orElse: () => fail('no signoff step'),
      );
      final run = step['run'] as String;
      expect(run, contains('--base'));
      expect(run, contains('--head'));
      expect(run, contains('--pr-author'));
      // Event values reach the shell through env, never inline in the script.
      expect(run, isNot(contains(r'${{')));
      final env = _asMap(step['env'], 'signoff env');
      expect(
        env.values,
        containsAll([
          r'${{ github.event.pull_request.base.sha }}',
          r'${{ github.event.pull_request.head.sha }}',
          r'${{ github.event.pull_request.user.login }}',
        ]),
      );
    });

    test('every job that runs a kaname_tools task resolves the workspace '
        'first', () {
      // `dart run kaname_tools` in an unresolved workspace makes dart's own
      // pub resolve it, which fails on the Flutter app package.
      const toolTasks = ['check', 'licences', 'sbom', 'signoff'];
      for (final MapEntry(key: id, value: job) in jobs.entries) {
        final runs = [
          for (final step in job.steps)
            if (step['run'] case final String run) run,
        ];
        final firstTool = runs.indexWhere(
          (run) => toolTasks.any((task) => run.contains('mise run $task')),
        );
        if (firstTool == -1) continue;
        final resolve = runs.indexWhere(
          (run) => run.contains('mise run resolve'),
        );
        expect(resolve, isNot(-1), reason: '$id never runs mise run resolve');
        expect(
          resolve,
          lessThan(firstTool),
          reason: '$id runs a kaname_tools task before mise run resolve',
        );
      }
    });

    test('job timeouts are check 30, build 45, others 10 minutes', () {
      final expected = {
        'check': 30,
        'build': 45,
        'spec': 10,
        'licences': 10,
        'signoff': 10,
      };
      expect(jobs.keys, unorderedEquals(expected.keys));
      for (final MapEntry(:key, :value) in expected.entries) {
        expect(job(key).map['timeout-minutes'], value, reason: key);
      }
    });

    test('every uses is pinned to a 40-hex SHA with a version comment', () {
      final usesLines = raw
          .split('\n')
          .where((line) => RegExp(r'^\s*-?\s*uses:').hasMatch(line))
          .toList();
      expect(usesLines, isNotEmpty);
      for (final line in usesLines) {
        expect(line, matches(_pinnedUses));
      }
      for (final job in jobs.values) {
        for (final step in job.steps) {
          if (step['uses'] case final String uses) {
            expect(uses, matches(RegExp(r'@[0-9a-f]{40}$')), reason: uses);
          }
        }
      }
    });

    test('workflow permissions are contents read and no job raises them', () {
      expect(workflow['permissions'], {'contents': 'read'});
      for (final MapEntry(key: id, value: job) in jobs.entries) {
        expect(job.map.containsKey('permissions'), isFalse, reason: id);
      }
    });

    test('job names never contain a runner label', () {
      for (final job in jobs.values) {
        for (final combination in job.combinations) {
          final name = job.nameFor(combination);
          expect(name, isNot(matches(_runnerLabel)), reason: name);
        }
      }
      // Runner labels appear only in matrix values and `runs-on`.
      for (final job in jobs.values) {
        for (final combination in job.combinations) {
          expect(_runners, contains(job.runnerFor(combination)));
        }
      }
    });

    test('caches the pub cache keyed on OS and pubspec.lock', () {
      for (final MapEntry(key: id, value: job) in jobs.entries) {
        if (job.runIndex('mise run resolve') < 0) continue;
        final cache = job.stepUsing('actions/cache');
        if (cache == null) fail('$id resolves but has no actions/cache step');
        final inputs = _asMap(cache['with'], '$id cache with');
        expect(inputs['key'], contains('runner.os'));
        expect(inputs['key'], contains("hashFiles('pubspec.lock')"));
      }
    });

    test('header comment carries the pinning, token and check-name rules', () {
      final header = raw
          .split('\n')
          .takeWhile((line) => line.startsWith('#'))
          .join('\n');
      expect(header, contains('full SHA'));
      expect(header, contains('contents: read'));
      expect(header, contains('pull_request_target'));
      expect(header, contains('required status checks'));
      expect(header, contains('runner label'));
    });
  });

  group('dependabot.yml', () {
    test('enables only github-actions, weekly, at the repository root', () {
      final config = _asMap(
        _plain(loadYaml(_readRepoFile('.github/dependabot.yml'))),
        'dependabot.yml',
      );
      expect(config['version'], 2);
      final updates = _asList(config['updates'], 'updates');
      expect(updates, hasLength(1));
      final update = _asMap(updates.single, 'update');
      expect(update['package-ecosystem'], 'github-actions');
      expect(update['directory'], '/');
      expect(_asMap(update['schedule'], 'schedule')['interval'], 'weekly');
    });
  });
}
