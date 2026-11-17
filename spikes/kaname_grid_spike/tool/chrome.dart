/// Finds or downloads the Chrome binary the runner and the Chrome tests use.
library;

import 'dart:io';

import 'package:puppeteer/puppeteer.dart';

/// Where Chrome for Testing is cached, relative to the spike package; `build/`
/// is ignored by git.
const defaultChromeCachePath = 'build/chrome-for-testing';

/// Returns the Chrome executable to use and says how it was chosen.
///
/// Order: [explicit] (`--chrome`), then the `CHROME_EXECUTABLE` environment
/// variable, then Chrome for Testing downloaded by puppeteer into [cachePath]
/// (a no-op when already there). Progress goes to [log]. Throws a
/// [StateError] when a named executable does not exist.
Future<({String executable, String source})> resolveChrome({
  String? explicit,
  String cachePath = defaultChromeCachePath,
  void Function(String message)? log,
}) async {
  final fromEnvironment = Platform.environment['CHROME_EXECUTABLE'];
  final (named, source) = switch ((explicit, fromEnvironment)) {
    (final String path, _) when path.isNotEmpty => (path, '--chrome'),
    (_, final String path) when path.isNotEmpty => (path, 'CHROME_EXECUTABLE'),
    _ => (null, 'download'),
  };
  if (named != null) {
    if (!File(named).existsSync()) {
      throw StateError('$source names $named, which does not exist.');
    }
    return (executable: File(named).absolute.path, source: source);
  }
  var lastPercent = -10;
  final info = await downloadChrome(
    cachePath: Directory(cachePath).absolute.path,
    onDownloadProgress: (received, total) {
      if (total <= 0) return;
      final percent = received * 100 ~/ total;
      if (percent >= lastPercent + 10) {
        lastPercent = percent;
        log?.call('Downloading Chrome for Testing: $percent%');
      }
    },
  );
  log?.call('Chrome for Testing ${info.version}');
  return (
    executable: File(info.executablePath).absolute.path,
    source: 'download',
  );
}
