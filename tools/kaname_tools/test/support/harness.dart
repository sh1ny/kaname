import 'package:kaname_tools/kaname_tools.dart';

import 'in_memory_file_system.dart';

/// The outcome of one in-memory `kaname_tools` run.
typedef CliResult = ({int code, String out, String err});

/// Runs `kaname_tools` with [args] over [fileSystem] and captures its output.
Future<CliResult> runTool(
  InMemoryFileSystem fileSystem,
  List<String> args,
) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runCli(
    args,
    fileSystem: fileSystem,
    output: CliOutput(out: out, err: err),
  );
  return (code: code, out: out.toString(), err: err.toString());
}

/// Source of a pubspec for a fixture package called [name].
String pubspecSource(
  String name, {
  String? resolution = 'workspace',
  List<String> dependencies = const [],
  List<String> devDependencies = const [],
}) {
  final lines = [
    'name: $name',
    'publish_to: none',
    if (resolution != null) 'resolution: $resolution',
    'environment:',
    '  sdk: ^3.13.0',
    if (dependencies.isNotEmpty) ...['dependencies:', ...dependencies],
    if (devDependencies.isNotEmpty) ...[
      'dev_dependencies:',
      ...devDependencies,
    ],
  ];
  return '${lines.join('\n')}\n';
}

/// A repository that satisfies every check: the app, core and tools
/// packages, a root workspace listing them, and all required files.
InMemoryFileSystem validRepository() => InMemoryFileSystem()
  ..writeFile(
    'pubspec.yaml',
    'name: kaname_workspace\n'
        'environment:\n'
        '  sdk: ^3.13.0\n'
        'workspace:\n'
        '  - app\n'
        '  - packages/kaname_core\n'
        '  - tools/kaname_tools\n',
  )
  ..writeFile('app/pubspec.yaml', pubspecSource('kaname_app'))
  ..writeFile('app/lib/main.dart', '// app\n')
  ..writeFile('packages/kaname_core/pubspec.yaml', pubspecSource('kaname_core'))
  ..writeFile('packages/kaname_core/lib/kaname_core.dart', '// core\n')
  ..writeFile('tools/kaname_tools/pubspec.yaml', pubspecSource('kaname_tools'))
  ..writeFile('tools/kaname_tools/lib/kaname_tools.dart', '// tools\n')
  ..writeFile('LICENSE')
  ..writeFile('THIRD_PARTY_NOTICES')
  ..writeFile('licence-policy.yaml')
  ..writeFile('CONTRIBUTING.md')
  ..writeFile('SECURITY.md')
  ..writeFile('.github/pull_request_template.md');
