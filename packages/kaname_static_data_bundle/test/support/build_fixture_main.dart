import 'dart:io';

import 'bundle_fixture.dart';

/// Builds the fixture's bundle and writes its bytes to standard output.
///
/// `aot_determinism_test.dart` compiles this with `dart compile exe` and
/// compares its output with the bundle the Dart VM builds (assumption A1).
Future<void> main() async {
  stdout.add(fixtureBuilder().build().bytes);
  await stdout.flush();
}
