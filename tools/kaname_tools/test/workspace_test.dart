import 'dart:io';

import 'package:kaname_tools/kaname_tools.dart';
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

  test('current layout reports every workspace member and exits 0', () async {
    final repository = RealFileSystem.locate(Directory.current.path);
    expect(repository, isNotNull, reason: 'no workspace root above the cwd');
    final out = StringBuffer();
    final err = StringBuffer();

    final code = await runCli(
      ['workspace'],
      fileSystem: repository!,
      output: CliOutput(out: out, err: err),
    );

    expect(err.toString(), isEmpty);
    expect(code, 0);
    expect(
      out.toString().trim().split('\n'),
      unorderedEquals([
        'kaname_app at app/',
        'kaname_ember_ui at app_packages/kaname_ember_ui/',
        'kaname_core at packages/kaname_core/',
        'kaname_esi at packages/kaname_esi/',
        'kaname_esi_scheduler at packages/kaname_esi_scheduler/',
        'kaname_static_data at packages/kaname_static_data/',
        'kaname_static_data_bundle at packages/kaname_static_data_bundle/',
        'kaname_tools at tools/kaname_tools/',
        'kaname_server at server/kaname_server/',
        'kaname_client at server/kaname_client/',
        'kaname_grid_spike at spikes/kaname_grid_spike/',
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
      ..writeFile('server/api/pubspec.yaml', pubspecSource('api'))
      ..writeFile(
        'server/kaname_gateway/pubspec.yaml',
        pubspecSource('kaname_edge'),
      )
      ..writeFile(
        'server/group/kaname_deep/pubspec.yaml',
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
  - server/api
  - server/kaname_gateway
  - server/group/kaname_deep
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
    expect(
      result.err,
      allOf(
        contains('server/api'),
        contains('"api"'),
        contains('kaname_ prefix'),
      ),
    );
    expect(
      result.err,
      allOf(
        contains('server/kaname_gateway'),
        contains('directory name'),
        contains('"kaname_edge"'),
      ),
    );
    expect(
      result.err,
      allOf(contains('server/group/kaname_deep'), contains('misplaced')),
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

  test('spikes root accepts kaname_ members', () async {
    fs
      ..writeFile(
        'spikes/kaname_grid_spike/pubspec.yaml',
        pubspecSource('kaname_grid_spike'),
      )
      ..writeFile(
        'pubspec.yaml',
        'name: kaname_workspace\n'
            'workspace:\n'
            '  - app\n'
            '  - packages/kaname_core\n'
            '  - tools/kaname_tools\n'
            '  - spikes/kaname_grid_spike\n',
      );

    final accepted = await runTool(fs, ['workspace']);

    expect(accepted.err, isEmpty);
    expect(accepted.code, 0);

    fs
      ..writeFile('spikes/helpers/pubspec.yaml', pubspecSource('helpers'))
      ..writeFile(
        'pubspec.yaml',
        'name: kaname_workspace\n'
            'workspace:\n'
            '  - app\n'
            '  - packages/kaname_core\n'
            '  - tools/kaname_tools\n'
            '  - spikes/kaname_grid_spike\n'
            '  - spikes/helpers\n',
      );

    final refused = await runTool(fs, ['workspace']);

    expect(refused.code, 1);
    expect(
      refused.err,
      allOf(
        contains('spikes/helpers'),
        contains('"helpers"'),
        contains('kaname_ prefix'),
      ),
    );
    expect(refused.err, isNot(contains('spikes/kaname_grid_spike')));
  });

  test('format dirs accept spikes members', () async {
    fs
      ..writeFile(
        'spikes/kaname_grid_spike/pubspec.yaml',
        pubspecSource('kaname_grid_spike'),
      )
      ..writeFile(
        'pubspec.yaml',
        'name: kaname_workspace\n'
            'workspace:\n'
            '  - app\n'
            '  - packages/kaname_core\n'
            '  - tools/kaname_tools\n'
            '  - spikes/kaname_grid_spike\n',
      );

    final accepted = await runTool(fs, ['workspace', '--format-dirs']);

    expect(accepted.err, isEmpty);
    expect(accepted.code, 0);
    expect(
      accepted.out,
      'app\npackages/kaname_core\nspikes/kaname_grid_spike\n'
      'tools/kaname_tools\n',
    );

    for (final member in [
      'spikes/kaname_x; touch pwned',
      'spikes/Kaname_upper',
    ]) {
      fs.writeFile(
        'pubspec.yaml',
        'name: kaname_workspace\n'
            'workspace:\n'
            '  - app\n'
            '  - "$member"\n',
      );

      final refused = await runTool(fs, ['workspace', '--format-dirs']);

      expect(refused.code, 1, reason: member);
      expect(refused.out, isEmpty, reason: member);
      expect(refused.err, contains(member));
    }
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

  test('root workspace lists kaname_server and kaname_client and the lockfile '
      'holds serverpod_cli as a dev dependency', () {
    final repository = RealFileSystem.locate(Directory.current.path);
    expect(repository, isNotNull, reason: 'no workspace root above the cwd');

    expect(
      workspaceMemberDirectories(repository!),
      containsAll(['server/kaname_server', 'server/kaname_client']),
    );
    // A workspace lockfile marks only the root's own dependencies as direct,
    // so the dev dependency is read from the server pubspec and the lockfile
    // must hold the resolved package.
    final server = Pubspec.load(
      repository,
      'server/kaname_server/pubspec.yaml',
    );
    expect(
      server.dependencies.where(
        (dependency) =>
            dependency.name == 'serverpod_cli' &&
            dependency.section == DependencySection.devDependencies,
      ),
      hasLength(1),
    );
    expect([
      for (final package in readLockedPackages(repository)) package.name,
    ], contains('serverpod_cli'));
  });
}
