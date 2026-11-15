import 'package:test/test.dart';

import 'support/harness.dart';
import 'support/in_memory_file_system.dart';

void main() {
  late InMemoryFileSystem fs;

  setUp(() => fs = validRepository());

  test('unlisted or non-workspace pubspec fails with its path', () async {
    fs
      ..writeFile(
        'packages/kaname_unlisted/pubspec.yaml',
        pubspecSource('kaname_unlisted'),
      )
      ..writeFile(
        'tools/kaname_loose/pubspec.yaml',
        pubspecSource('kaname_loose', resolution: null),
      )
      ..writeFile(
        'pubspec.yaml',
        'name: kaname_workspace\n'
            'workspace:\n'
            '  - app\n'
            '  - packages/kaname_core\n'
            '  - tools/kaname_tools\n'
            '  - tools/kaname_loose\n',
      );

    final result = await runTool(fs, ['workspace']);

    expect(result.code, 1);
    expect(result.err, contains('packages/kaname_unlisted'));
    expect(result.err, contains('tools/kaname_loose'));
    expect(result.err, isNot(contains('packages/kaname_core')));
  });

  test('symlinked, build and plugin-symlink pubspecs are ignored', () async {
    fs
      ..writeFile('app/build/web/pubspec.yaml', pubspecSource('generated'))
      ..writeFile(
        'app/ios/.symlinks/plugins/some_plugin/pubspec.yaml',
        pubspecSource('some_plugin'),
      )
      ..writeFile(
        'app/linux/flutter/ephemeral/.plugin_symlinks/other/pubspec.yaml',
        pubspecSource('other'),
      )
      ..writeFile(
        'app/.plugin_symlinks/third/pubspec.yaml',
        pubspecSource('third'),
      )
      ..writeFile('app/.dart_tool/cache/pubspec.yaml', pubspecSource('cache'))
      ..writeFile('elsewhere/pubspec.yaml', pubspecSource('behind_a_link'))
      ..addLink('packages/linked', target: 'elsewhere')
      ..addLink('app/pubspec_link', target: 'elsewhere');

    final result = await runTool(fs, ['workspace']);

    expect(result.err, isEmpty);
    expect(result.code, 0);
  });

  test('current layout reports app, core and tools and passes', () async {
    final result = await runTool(fs, ['workspace']);

    expect(result.err, isEmpty);
    expect(result.code, 0);
    expect(
      result.out.trim().split('\n'),
      unorderedEquals([
        'kaname_app at app/',
        'kaname_core at packages/kaname_core/',
        'kaname_tools at tools/kaname_tools/',
      ]),
    );
  });

  test('missing prefix or directory mismatch fails with rule', () async {
    fs
      ..writeFile('packages/helpers/pubspec.yaml', pubspecSource('helpers'))
      ..writeFile(
        'app_packages/kaname_widgets/pubspec.yaml',
        pubspecSource('kaname_ui'),
      )
      ..writeFile(
        'packages/group/kaname_deep/pubspec.yaml',
        pubspecSource('kaname_deep'),
      )
      ..writeFile('pubspec.yaml', '''
name: kaname_workspace
workspace:
  - app
  - packages/kaname_core
  - tools/kaname_tools
  - packages/helpers
  - app_packages/kaname_widgets
  - packages/group/kaname_deep
''');

    final result = await runTool(fs, ['workspace']);

    expect(result.code, 1);
    expect(
      result.err,
      allOf(
        contains('packages/helpers'),
        contains('"helpers"'),
        contains('kaname_ prefix'),
      ),
    );
    expect(
      result.err,
      allOf(
        contains('app_packages/kaname_widgets'),
        contains('directory name'),
        contains('"kaname_ui"'),
      ),
    );
    expect(
      result.err,
      allOf(contains('packages/group/kaname_deep'), contains('misplaced')),
    );
  });

  test('listed member outside the package folders or without a pubspec '
      'fails', () async {
    fs
      ..writeFile('misc/helpers/pubspec.yaml', pubspecSource('kaname_helpers'))
      ..writeFile('pubspec.yaml', '''
name: kaname_workspace
workspace:
  - app
  - packages/kaname_core
  - tools/kaname_tools
  - misc/helpers
  - packages/kaname_ghost
''');

    final result = await runTool(fs, ['workspace']);

    expect(result.code, 1);
    final lines = result.err.trim().split('\n');
    expect(
      lines,
      contains(
        allOf(contains('misc/helpers'), contains('misplaced workspace member')),
      ),
    );
    expect(
      lines,
      contains(
        allOf(contains('packages/kaname_ghost'), contains('no pubspec.yaml')),
      ),
    );
  });

  test('app package not named kaname_app fails', () async {
    fs.writeFile('app/pubspec.yaml', pubspecSource('kaname_client'));

    final result = await runTool(fs, ['workspace']);

    expect(result.code, 1);
    expect(
      result.err,
      allOf(
        contains('app'),
        contains('"kaname_client"'),
        contains('kaname_app'),
      ),
    );
  });

  test('format directories refuse a member path that is not a plain '
      'package path', () async {
    for (final member in ['packages/kaname_x; touch pwned', 'misc/helpers']) {
      fs.writeFile(
        'pubspec.yaml',
        'name: kaname_workspace\n'
            'workspace:\n'
            '  - app\n'
            '  - "$member"\n',
      );

      final result = await runTool(fs, ['workspace', '--format-dirs']);

      expect(result.code, 1, reason: member);
      expect(result.out, isEmpty, reason: member);
      expect(result.err, contains(member));
    }
  });

  test('format directories are workspace members only', () async {
    fs
      ..writeFile('.claude/skills/x/pubspec.yaml', pubspecSource('skill'))
      ..writeFile('brand/tools/pubspec.yaml', pubspecSource('brand'));

    final result = await runTool(fs, ['workspace', '--format-dirs']);

    expect(result.err, isEmpty);
    expect(result.code, 0);
    expect(result.out, 'app\npackages/kaname_core\ntools/kaname_tools\n');
  });

  test('missing required file fails with its path', () async {
    fs
      ..deleteFile('.github/pull_request_template.md')
      ..deleteFile('SECURITY.md');

    final result = await runTool(fs, ['workspace']);

    expect(result.code, 1);
    expect(result.err, contains('.github/pull_request_template.md'));
    expect(result.err, contains('SECURITY.md'));
    expect(result.err, isNot(contains('LICENSE')));
  });

  test('missing licence policy fails with its path', () async {
    fs.deleteFile('licence-policy.yaml');

    final result = await runTool(fs, ['workspace']);

    expect(result.code, 1);
    expect(
      result.err,
      contains('licence-policy.yaml: required file is missing'),
    );
  });
}
