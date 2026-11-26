import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_secure_storage_windows/flutter_secure_storage_windows.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Checks that the Windows keyring leaves an unreadable committed file alone.
///
/// The test uses only the public facade and the package's own plugin class,
/// so the same file compiles and runs against the hosted package and the
/// patched fork. It writes synthetic bytes that DPAPI cannot unprotect and
/// never touches the user's keyring.
void main() {
  const invalidData = [1, 2, 3];

  test(
    'An unreadable committed Windows credential file stays intact',
    () async {
      final directory = await Directory.systemTemp.createTemp('kaname-dpapi-');
      addTearDown(() => directory.delete(recursive: true));
      final committed = File(
        p.join(directory.path, 'flutter_secure_storage.dat'),
      );
      await committed.writeAsBytes(invalidData);

      // `flutter test` does not run the generated Dart plugin registrant, so
      // register the package's own Windows class, as the registrant does in
      // the app. Only the support directory is replaced.
      final previousStorage = FlutterSecureStoragePlatform.instance;
      final previousPaths = PathProviderPlatform.instance;
      addTearDown(() {
        FlutterSecureStoragePlatform.instance = previousStorage;
        PathProviderPlatform.instance = previousPaths;
      });
      FlutterSecureStorageWindows.registerWith();
      // The facade picks options by target platform, which tests set to
      // Android. Select Windows so it sends the app's Windows options.
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final provider = _FixtureSupportPath(directory.path);
      PathProviderPlatform.instance = provider;

      var failed = false;
      try {
        await const FlutterSecureStorage().read(key: 'synthetic-key');
      } on Object {
        failed = true;
      }

      expect(
        provider.wasRead,
        isTrue,
        reason: 'The facade did not reach the fixture.',
      );
      expect(failed, isTrue, reason: 'Unreadable storage must fail closed.');
      expect(
        await committed.exists(),
        isTrue,
        reason: 'The backend removed the unreadable committed file.',
      );
      expect(await committed.readAsBytes(), invalidData);
    },
    skip: !Platform.isWindows,
  );
}

final class _FixtureSupportPath extends PathProviderPlatform {
  _FixtureSupportPath(this.path);

  final String path;
  bool wasRead = false;

  @override
  Future<String> getApplicationSupportPath() async {
    wasRead = true;
    return path;
  }
}
