/// Downloads Chrome for Testing and prints the path of its executable.
///
/// ```sh
/// mise run spike:chrome
/// export CHROME_EXECUTABLE="$(mise run spike:chrome 2>/dev/null)"
/// ```
///
/// Standard output carries only the executable path; progress goes to standard
/// error. Exit codes: 0 success, 64 usage error, 69 download failure.
library;

import 'dart:io';

import 'package:args/args.dart';

import 'chrome.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'cache-path',
      defaultsTo: defaultChromeCachePath,
      help: 'Directory that holds the Chrome for Testing download.',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this usage.');
  final ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln(parser.usage);
    exitCode = 64;
    return;
  }
  if (results.flag('help')) {
    stdout.writeln(parser.usage);
    return;
  }
  try {
    final chrome = await resolveChrome(
      cachePath: results.option('cache-path')!,
      log: stderr.writeln,
    );
    stdout.writeln(chrome.executable);
  } on Object catch (e) {
    stderr.writeln('Cannot get Chrome: $e');
    exitCode = 69;
  }
}
