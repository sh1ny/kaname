import 'dart:io';

import 'package:kaname_static_data/kaname_static_data.dart';

/// Builds the bundle of the SDE zip named by the first argument, with the
/// scratch directory named by the second, and writes its bytes to standard
/// output.
///
/// `aot_determinism_test.dart` compiles this with `dart compile exe` and
/// compares its output with the bundle the Dart VM builds from the same zip
/// (assumption A1).
Future<void> main(List<String> args) async {
  final built = await buildBundleFromZip(
    File(args[0]),
    scratchRoot: Directory(args[1]),
  );
  stdout.add(built.bytes);
  await stdout.flush();
}
