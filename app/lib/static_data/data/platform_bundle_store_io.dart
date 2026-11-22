/// The native platform's bundle store and opener.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'bundle_opener_io.dart';
import 'bundle_store.dart';
import 'file_bundle_store.dart';

/// The bundle opener of this platform.
BundleOpener createPlatformBundleOpener() => const IsolateBundleOpener();

/// The bundle store of this platform: one file in the `static_data`
/// directory under the app's support directory, checked by [opener].
///
/// Throws when the platform has no support directory.
Future<BundleStore> createPlatformBundleStore(BundleOpener opener) async {
  final support = await getApplicationSupportDirectory();
  return FileBundleStore(
    directory: Directory(p.join(support.path, 'static_data')),
    opener: opener,
  );
}
