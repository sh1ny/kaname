import 'dart:io';

import 'package:kaname_tools/kaname_tools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _appId = 'io.github.sh1ny.kaname';

/// Every value assigned to `PRODUCT_BUNDLE_IDENTIFIER` in [source], except the
/// `.RunnerTests` test targets.
List<String> _appBundleIds(String source) => [
  for (final match in RegExp(
    r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;\s]+)',
  ).allMatches(source))
    if (!match[1]!.endsWith('.RunnerTests')) match[1]!,
];

void main() {
  test('six platform folders and io.github.sh1ny.kaname IDs', () {
    final root = RealFileSystem.locate(Directory.current.path)?.root;
    expect(root, isNotNull, reason: 'no workspace root above the test cwd');
    final app = p.join(root!, 'app');
    String read(String relative) =>
        File(p.join(app, relative)).readAsStringSync();

    for (final platform in [
      'android',
      'ios',
      'linux',
      'macos',
      'web',
      'windows',
    ]) {
      expect(
        Directory(p.join(app, platform)).existsSync(),
        isTrue,
        reason: 'app/$platform is missing',
      );
    }

    final gradle = read('android/app/build.gradle.kts');
    expect(
      RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(gradle)?[1],
      _appId,
    );
    expect(RegExp(r'namespace\s*=\s*"([^"]+)"').firstMatch(gradle)?[1], _appId);

    final ios = _appBundleIds(read('ios/Runner.xcodeproj/project.pbxproj'));
    expect(ios, isNotEmpty);
    expect(ios, everyElement(_appId));

    final macos = [
      ..._appBundleIds(read('macos/Runner/Configs/AppInfo.xcconfig')),
      ..._appBundleIds(read('macos/Runner.xcodeproj/project.pbxproj')),
    ];
    expect(macos, isNotEmpty);
    expect(macos, everyElement(_appId));
  });
}
