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

    test('web build bundles the engine and its output is checked', () {
      final build = job('build');
      final web = build.combinations.firstWhere((c) => c['target'] == 'web');
      expect(web['command'], contains('--no-web-resources-cdn'));
      final buildIndex = build.steps.indexWhere(
        (s) => (s['run'] as String?)?.contains('matrix.command') ?? false,
      );
      final check = build.steps.indexWhere(
        (s) => s['run'] == 'mise run webbuild:check',
      );
      expect(check, greaterThan(buildIndex));
      expect(build.steps[check]['if'], contains("matrix.target == 'web'"));
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
      const toolTasks = [
        'check',
        'licences',
        'sbom',
        'signoff',
        'server:setup',
        'server:drift',
        'test:server',
        'stack:up',
        'stack:test',
      ];
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

    test('job timeouts are check 30, build 45, server 20, stack 45, others '
        '10 minutes', () {
      final expected = {
        'check': 30,
        'build': 45,
        'server': 20,
        'stack': 45,
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
      // The check-name rules list every job, including the Linux-only two.
      expect(header, contains('`server`'));
      expect(header, contains('`stack`'));
    });
  });

  group('server job', () {
    test('runs on linux only, separate from check', () {
      final server = job('server');
      expect(server.map.containsKey('strategy'), isFalse);
      expect(server.runnerFor({}), 'ubuntu-24.04');
      expect(server.map['name'] ?? 'server', 'server');
      expect(server.map.containsKey('needs'), isFalse);
    });

    test('sets up secrets, starts and awaits the dev Redis, then drift and '
        'tests', () {
      final server = job('server');
      final setup = server.runIndex('mise run server:setup');
      final drift = server.runIndex('mise run server:drift');
      final tests = server.runIndex('mise run test:server');
      expect(server.runIndex('mise run resolve'), isNonNegative);
      expect(server.runIndex('mise run resolve'), lessThan(setup));
      final redis = server.steps.indexWhere(
        (s) =>
            ((s['name'] as String?) ?? '').contains('Redis') &&
            ((s['run'] as String?) ?? '').contains('docker compose'),
      );
      expect(redis, isNonNegative, reason: 'no named Redis step');
      final step = server.steps[redis];
      expect(step['working-directory'], 'server/kaname_server');
      // Compose waits for the healthcheck, so the step fails if Redis never
      // becomes healthy.
      expect(step['run'], contains('up'));
      expect(step['run'], contains('--wait'));
      expect(setup, isNonNegative);
      expect(redis, greaterThan(setup));
      expect(drift, greaterThan(redis));
      expect(tests, greaterThan(drift));
    });

    test('no step forces a later step past a failure', () {
      for (final step in job('server').steps) {
        expect('${step['continue-on-error'] ?? ''}', isNot('true'));
      }
    });

    test('check never runs the server tests and keeps fail-fast off', () {
      final check = job('check');
      expect(check.strategy['fail-fast'], isFalse);
      for (final run in check.runs) {
        expect(run, isNot(contains('test:server')));
        expect(run, isNot(contains('server:drift')));
      }
      for (final MapEntry(key: id, value: other) in jobs.entries) {
        if (id == 'server') continue;
        for (final run in other.runs) {
          expect(run, isNot(contains('test:server')), reason: id);
        }
      }
    });
  });

  group('stack job', () {
    test('runs on linux only', () {
      final stack = job('stack');
      expect(stack.map.containsKey('strategy'), isFalse);
      expect(stack.runnerFor({}), 'ubuntu-24.04');
      expect(stack.map['name'] ?? 'stack', 'stack');
    });

    test('generates placeholder secrets at run time, then builds the web app '
        'and runs the stack tests', () {
      final stack = job('stack');
      final secrets = stack.steps.indexWhere(
        (s) =>
            ((s['name'] as String?) ?? '').toLowerCase().contains('secret') &&
            ((s['run'] as String?) ?? '').contains('deploy/.env'),
      );
      expect(secrets, isNonNegative, reason: 'no secrets step');
      final script = stack.steps[secrets]['run'] as String;
      for (final name in [
        'POSTGRES_PASSWORD',
        'REDIS_PASSWORD',
        'SERVERPOD_SERVICE_SECRET',
      ]) {
        expect(script, contains(name));
      }
      // Generated here, never committed or copied from the example.
      expect(script, contains('openssl rand'));
      expect(script, isNot(contains('change-me')));
      final up = stack.runIndex('mise run stack:up');
      final test = stack.runIndex('mise run stack:test');
      expect(secrets, lessThan(up));
      expect(test, greaterThan(up));
      expect(stack.runIndex('mise run resolve'), lessThan(up));
      // stack:up builds the web app on the host before it starts Compose.
      final mise = _readRepoFile('mise.toml');
      final stackUp = RegExp(r'\[tasks\."stack:up"\][\s\S]*?\n\n')
          .firstMatch(mise)
          ?.group(0);
      expect(stackUp, isNotNull);
      expect(stackUp, contains('task = "build:web"'));
      // build:web checks its own output, so the stack's build is covered.
      final buildWeb = RegExp(r'\[tasks\."build:web"\][\s\S]*?\n\n')
          .firstMatch(mise)
          ?.group(0);
      expect(buildWeb, contains('task = "webbuild:check"'));
      expect(
        stackUp!.indexOf('build:web'),
        lessThan(stackUp.indexOf('docker compose')),
      );
    });

    test('prints every service log on failure and always removes the stack '
        'and its volumes', () {
      final stack = job('stack');
      final test = stack.runIndex('mise run stack:test');
      final logs = stack.steps.indexWhere(
        (s) =>
            ((s['run'] as String?) ?? '').contains('compose') &&
            ((s['run'] as String?) ?? '').contains(' logs'),
      );
      final down = stack.steps.indexWhere(
        (s) => ((s['run'] as String?) ?? '').contains(' down'),
      );
      expect(logs, greaterThan(test));
      expect(down, greaterThan(logs));
      expect(stack.steps[logs]['if'], 'failure()');
      expect(stack.steps[down]['if'], 'always()');
      final logRun = stack.steps[logs]['run'] as String;
      expect(logRun, contains('deploy/compose.yaml'));
      // No service filter: every service's log is printed.
      expect(logRun, isNot(matches(RegExp(r'logs\b.*\b(server|postgres)\b'))));
      final downRun = stack.steps[down]['run'] as String;
      expect(downRun, contains('deploy/compose.yaml'));
      expect(downRun, matches(RegExp(r'down\b.*(\s-v\b|--volumes)')));
      // Compose is the last step: nothing after it can leave the stack up.
      expect(down, stack.steps.length - 1);
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
