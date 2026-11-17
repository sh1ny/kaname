/// Runs the grid benchmark in headless Chrome for every renderer and thread
/// mode and writes one JSON file per row.
///
/// For each row (`skwasm-threaded`, `skwasm-single`, `canvaskit`) the runner
/// serves `build/web` with `kaname_tools serve` (adding `--no-isolation` for
/// the single-threaded row), opens headless Chrome at
/// `/?bench=1&renderer=<renderer>&threads=<threads>`, polls
/// `window.gridBenchResult` and writes
/// `build/grid-bench/<renderer>-<threads>.json` (`skwasm-multi.json`,
/// `skwasm-single.json`, `canvaskit-na.json`) plus `summary.json`.
///
/// A row fails, with the reason in its file and in `summary.json`, when Chrome
/// does not launch, the page throws or crashes, the page publishes an abort
/// document, or no result arrives within `--timeout` (ten minutes by default).
/// The other rows still run.
///
/// ```sh
/// mise run bench:spike                       # build, then run every row
///
/// mise run build:spike                       # build only; then, on that build:
/// mise run bench:spike:run                   # full run
/// mise run bench:spike:run -- --smoke        # scaled-down run, not judged
/// mise run bench:spike:run -- --row skwasm-threaded \
///   --extra-chrome-arg=--js-flags=--no-experimental-wasm-gc
/// ```
///
/// Runner arguments go to `bench:spike:run`: `bench:spike` runs its sub-tasks
/// and passes none on.
///
/// Exit codes: 0 every row produced a result, 1 at least one row failed, 64
/// usage error, 66 the build directory is missing, 69 Chrome is unavailable.
/// The runner judges nothing: the S4 verdict inside each file is the page's.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:puppeteer/puppeteer.dart';

import 'bench_model.dart';
import 'chrome.dart';
import 'serve_process.dart';

/// The fixed viewport every row uses.
const _viewport = DeviceViewport(width: 1600, height: 900);

/// Chrome arguments the runner always adds. SwiftShader keeps WebGL working
/// when the machine has no GPU (WSL); the row file records what is used.
const _baseChromeArgs = <String>[
  '--enable-unsafe-swiftshader',
  '--disable-background-timer-throttling',
  '--disable-renderer-backgrounding',
  '--disable-backgrounding-occluded-windows',
];

ArgParser _parser() => ArgParser()
  ..addFlag(
    'smoke',
    negatable: false,
    help:
        'Open ?bench=smoke (scaled-down durations); the result is not judged.',
  )
  ..addMultiOption(
    'row',
    help:
        'Run only this row; repeat for several. '
        'Default: every row.',
    allowed: {
      for (final row in benchRows) ...[row.name, row.fileStem],
    }.toList(),
  )
  ..addMultiOption(
    'extra-chrome-arg',
    help:
        'An extra Chrome argument, repeatable, for example '
        '--extra-chrome-arg=--js-flags=--no-experimental-wasm-gc.',
  )
  ..addOption(
    'chrome',
    help: 'Chrome executable. Default: CHROME_EXECUTABLE, else Chrome for Testing.',
  )
  ..addOption(
    'chrome-cache',
    defaultsTo: defaultChromeCachePath,
    help: 'Where Chrome for Testing is downloaded.',
  )
  ..addOption('web', defaultsTo: 'build/web', help: 'The built spike to serve.')
  ..addOption(
    'out',
    defaultsTo: 'build/grid-bench',
    help: 'Directory for the row files and summary.json.',
  )
  ..addOption(
    'timeout-seconds',
    defaultsTo: '600',
    help: 'Per-row limit for the result to appear.',
  )
  ..addOption(
    'repo-root',
    defaultsTo: '../..',
    help: 'Workspace root, where kaname_tools resolves.',
  )
  ..addFlag(
    'no-sandbox',
    negatable: false,
    help: 'Pass --no-sandbox to Chrome (needed as root or without user namespaces).',
  )
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this usage.');

Future<void> main(List<String> args) async {
  final parser = _parser();
  final ArgResults results;
  final Duration timeout;
  final List<BenchRow> rows;
  try {
    results = parser.parse(args);
    if (results.flag('help')) {
      stdout.writeln('Usage: dart run tool/bench.dart [options]\n');
      stdout.writeln(parser.usage);
      return;
    }
    if (results.rest.isNotEmpty) {
      throw FormatException('Unexpected arguments: ${results.rest.join(' ')}');
    }
    final seconds = int.tryParse(results.option('timeout-seconds')!);
    if (seconds == null || seconds <= 0) {
      throw const FormatException(
        '--timeout-seconds must be a positive number.',
      );
    }
    timeout = Duration(seconds: seconds);
    rows = selectRows(results.multiOption('row'));
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln(parser.usage);
    exitCode = 64;
    return;
  }

  final webDirectory = Directory(results.option('web')!).absolute;
  if (!File('${webDirectory.path}/index.html').existsSync()) {
    stderr.writeln(
      '${webDirectory.path} has no index.html; run `mise run build:spike` first.',
    );
    exitCode = 66;
    return;
  }

  final ({String executable, String source}) chrome;
  try {
    chrome = await resolveChrome(
      explicit: results.option('chrome'),
      cachePath: results.option('chrome-cache')!,
      log: stderr.writeln,
    );
  } on Object catch (e) {
    stderr.writeln('Chrome is unavailable: $e');
    exitCode = 69;
    return;
  }
  stderr.writeln('Chrome: ${chrome.executable} (${chrome.source})');

  final smoke = results.flag('smoke');
  final chromeArgs = [
    ..._baseChromeArgs,
    if (results.flag('no-sandbox')) '--no-sandbox',
    ...results.multiOption('extra-chrome-arg'),
  ];
  final outDirectory = Directory(results.option('out')!)
    ..createSync(recursive: true);
  final repoRoot = Directory(results.option('repo-root')!).absolute.path;

  final outcomes = <RowOutcome>[];
  for (final row in rows) {
    stderr.writeln('Row ${row.name}: running${smoke ? ' (smoke)' : ''}...');
    final outcome = await _runRow(
      row: row,
      smoke: smoke,
      timeout: timeout,
      repoRoot: repoRoot,
      webDirectory: webDirectory.path,
      chromeExecutable: chrome.executable,
      chromeArgs: chromeArgs,
    );
    outcomes.add(outcome);
    _writeJson(
      File('${outDirectory.path}/${row.fileStem}.json'),
      outcome.toJson(),
    );
    stderr.writeln(
      'Row ${row.name}: ${outcome.succeeded ? 'done' : 'FAILED: ${outcome.failure}'}',
    );
  }
  _writeJson(File('${outDirectory.path}/summary.json'), summaryJson(outcomes));

  for (final outcome in outcomes) {
    stdout.writeln(
      '${outcome.row.name}: ${outcome.succeeded ? 'done' : 'failed (${outcome.failure})'}',
    );
  }
  stdout.writeln('Wrote ${outDirectory.path}');
  if (outcomes.any((o) => !o.succeeded)) exitCode = 1;
}

void _writeJson(File file, Map<String, Object?> document) {
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(document)}\n',
  );
}

/// Runs one row and always returns an outcome; every failure becomes a
/// `failed` row, and the server and Chrome are stopped on every path.
Future<RowOutcome> _runRow({
  required BenchRow row,
  required bool smoke,
  required Duration timeout,
  required String repoRoot,
  required String webDirectory,
  required String chromeExecutable,
  required List<String> chromeArgs,
}) async {
  final stopwatch = Stopwatch()..start();
  ServeProcess? server;
  Browser? browser;
  var url = row.path(smoke: smoke);
  final consoleErrors = <String>[];
  RunnerEnvironment? environment;
  Map<String, Object?>? document;
  String? failure;
  try {
    server = await ServeProcess.start(
      repoRoot: repoRoot,
      directory: webDirectory,
      isolation: row.isolation,
    );
    url = server.url.resolve(row.path(smoke: smoke)).toString();

    browser = await puppeteer.launch(
      executablePath: chromeExecutable,
      headless: true,
      args: chromeArgs,
      defaultViewport: _viewport,
    );
    final chromeVersion = await browser.version;
    final page = await browser.newPage();
    await page.setViewport(_viewport);

    String? pageError;
    final subscriptions = [
      page.onConsole.listen((message) {
        if (message.type == ConsoleMessageType.error) {
          consoleErrors.add(message.text ?? message.toString());
        }
      }),
      page.onError.listen((error) {
        pageError ??= '$error';
      }),
    ];
    try {
      await page.goto(url, wait: Until.load, timeout: timeout);
      final poll = await _poll(page, () => pageError, timeout);
      switch (poll) {
        case BenchDone(document: final published):
          document = published;
        case BenchAborted(:final reason, document: final published):
          failure = reason;
          document = published;
        case BenchPending():
          failure = 'No result within ${timeout.inSeconds} s.';
      }
    } on _PageFailed catch (e) {
      failure = e.message;
    } finally {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    }
    environment = await _readEnvironment(
      page,
      chromeExecutable: chromeExecutable,
      chromeVersion: chromeVersion,
      chromeArgs: chromeArgs,
    );
  } on Object catch (e) {
    failure =
        '${failure == null ? '' : '$failure; '}${e is StateError ? e.message : e}';
  } finally {
    try {
      await browser?.close();
    } on Object catch (e) {
      stderr.writeln('Closing Chrome failed: $e');
    }
    await server?.stop();
  }
  if (failure != null && consoleErrors.isNotEmpty) {
    final shown = consoleErrors.take(5).join(' | ');
    failure = '$failure Console errors: $shown';
  }
  return RowOutcome(
    row: row,
    url: url,
    smoke: smoke,
    elapsed: stopwatch.elapsed,
    failure: failure,
    result: document,
    environment: environment,
    consoleErrors: consoleErrors,
  );
}

/// A page-level failure that ends polling at once.
final class _PageFailed implements Exception {
  const _PageFailed(this.message);
  final String message;
}

/// Polls `window.gridBenchResult` every second until it is complete, aborted,
/// [pageError] returns a message ([_PageFailed]) or [timeout] passes ([BenchPending]).
Future<BenchPoll> _poll(
  Page page,
  String? Function() pageError,
  Duration timeout,
) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (pageError() case final String error) {
      throw _PageFailed('Page error: $error');
    }
    final String? json;
    try {
      json = await page.evaluate<String?>(
        '() => window.gridBenchResult == null '
        '? null : JSON.stringify(window.gridBenchResult)',
      );
    } on Object catch (e) {
      throw _PageFailed('Reading the result failed: $e');
    }
    final poll = classifyResult(json);
    if (poll is! BenchPending) return poll;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  return const BenchPending();
}

/// Reads the page-side environment facts (A3); every field stays `null` when
/// the page cannot answer within five seconds.
Future<RunnerEnvironment> _readEnvironment(
  Page page, {
  required String chromeExecutable,
  required String chromeVersion,
  required List<String> chromeArgs,
}) async {
  Map<String, Object?>? facts;
  try {
    final json = await page
        .evaluate<String>('''() => {
          let webgl = null;
          try {
            const gl = document.createElement('canvas').getContext('webgl');
            const info = gl && gl.getExtension('WEBGL_debug_renderer_info');
            webgl = info ? gl.getParameter(info.UNMASKED_RENDERER_WEBGL) : null;
          } catch (e) {}
          return JSON.stringify({
            userAgent: navigator.userAgent,
            webglRenderer: webgl,
            crossOriginIsolated: window.crossOriginIsolated,
          });
        }''')
        .timeout(const Duration(seconds: 5));
    if (jsonDecode(json) case final Map<String, Object?> decoded) {
      facts = decoded;
    }
  } on Object catch (e) {
    stderr.writeln('Reading the environment failed: $e');
  }
  return RunnerEnvironment(
    chromeExecutable: chromeExecutable,
    chromeVersion: chromeVersion,
    launchArgs: chromeArgs,
    viewportWidth: _viewport.width,
    viewportHeight: _viewport.height,
    deviceScaleFactor: _viewport.deviceScaleFactor,
    userAgent: facts?['userAgent'] as String?,
    webglRenderer: facts?['webglRenderer'] as String?,
    crossOriginIsolated: facts?['crossOriginIsolated'] as bool?,
  );
}
