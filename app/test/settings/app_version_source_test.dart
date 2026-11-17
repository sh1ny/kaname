import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/settings/data/app_version_source.dart';
import 'package:package_info_plus/package_info_plus.dart';

PackageInfo _info({String version = '0.0.1', String build = '1'}) =>
    PackageInfo(
      appName: 'Kaname',
      packageName: 'kaname',
      version: version,
      buildNumber: build,
    );

void main() {
  test('formats the version as version+build', () async {
    final source = PackageInfoAppVersionSource(loader: () async => _info());
    expect(await source.read(), '0.0.1+1');
  });

  test('omits an empty build number', () async {
    final source = PackageInfoAppVersionSource(
      loader: () async => _info(build: ''),
    );
    expect(await source.read(), '0.0.1');
  });

  test('a throwing loader reads as unknown and does not throw', () async {
    final source = PackageInfoAppVersionSource(
      loader: () async => throw StateError('no platform'),
    );
    expect(await source.read(), 'unknown');
    expect(unknownAppVersion, 'unknown');
  });

  test('loads the platform info once', () async {
    var calls = 0;
    final source = PackageInfoAppVersionSource(
      loader: () async {
        calls++;
        return _info();
      },
    );
    await source.read();
    await source.read();
    expect(calls, 1);
  });
}
