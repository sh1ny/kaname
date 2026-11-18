/// The pure parts of the headless benchmark runner: the row matrix, the page
/// URL, the classification of what the page published, and the row files.
///
/// Kept free of `dart:io` and puppeteer so the VM tests can cover it.
library;

import 'dart:convert';

/// The schema version of the runner's own row and summary files (separate from
/// the page's `schemaVersion`, which is C6).
const runnerSchemaVersion = 1;

/// One benchmark combination: a renderer with a thread mode.
final class BenchRow {
  /// Creates a row.
  const BenchRow({
    required this.name,
    required this.renderer,
    required this.threads,
    required this.isolation,
  });

  /// The name `--row` accepts, for example `skwasm-threaded`.
  final String name;

  /// The `?renderer=` value: `skwasm` or `canvaskit`.
  final String renderer;

  /// The thread mode: `multi`, `single` or `na` (CanvasKit). Only `single`
  /// reaches the page, as `?threads=single`: the bootstrap knows no other
  /// value.
  final String threads;

  /// Whether `kaname_tools serve` sends the COOP/COEP headers (`false` adds
  /// `--no-isolation`).
  final bool isolation;

  /// The file stem under `build/grid-bench/`: `<renderer>-<threads>`.
  String get fileStem => '$renderer-$threads';

  /// The page path with its query for a full run or, with [smoke], the
  /// scaled-down one. Adds `&threads=single` for the single-threaded row only.
  String path({required bool smoke}) =>
      '/?bench=${smoke ? 'smoke' : '1'}&renderer=$renderer'
      '${threads == 'single' ? '&threads=single' : ''}';
}

/// The rows in run order.
const benchRows = <BenchRow>[
  BenchRow(
    name: 'skwasm-threaded',
    renderer: 'skwasm',
    threads: 'multi',
    isolation: true,
  ),
  BenchRow(
    name: 'skwasm-single',
    renderer: 'skwasm',
    threads: 'single',
    isolation: false,
  ),
  BenchRow(
    name: 'canvaskit',
    renderer: 'canvaskit',
    threads: 'na',
    isolation: true,
  ),
];

/// Returns the rows that [selection] names, all rows when it is empty.
///
/// A name matches a [BenchRow.name] or a [BenchRow.fileStem]. Throws an
/// [ArgumentError] for a name that matches no row.
List<BenchRow> selectRows(List<String> selection) {
  if (selection.isEmpty) return benchRows;
  return [
    for (final wanted in selection)
      benchRows.firstWhere(
        (row) => row.name == wanted || row.fileStem == wanted,
        orElse: () => throw ArgumentError.value(
          wanted,
          'row',
          'Unknown row; use one of '
              '${benchRows.map((r) => r.name).join(', ')}.',
        ),
      ),
  ];
}

/// The result of reading `window.gridBenchResult` once.
sealed class BenchPoll {
  const BenchPoll();
}

/// Nothing is published yet.
final class BenchPending extends BenchPoll {
  /// Creates the pending state.
  const BenchPending();
}

/// The page published a complete result: `schemaVersion` 1 with a `verdict`.
final class BenchDone extends BenchPoll {
  /// Creates a done state around the published [document].
  const BenchDone(this.document);

  /// The published document.
  final Map<String, Object?> document;
}

/// The page published an abort document, or a document the runner cannot use.
final class BenchAborted extends BenchPoll {
  /// Creates an aborted state with a human-readable [reason].
  const BenchAborted(this.reason, {this.document});

  /// Why the row cannot count.
  final String reason;

  /// The published document, when there was one.
  final Map<String, Object?>? document;
}

/// Classifies the JSON text that the page's `JSON.stringify(gridBenchResult)`
/// returned: `null` or empty while pending.
///
/// An abort document is `{schemaVersion: 1, aborted: <reason>}`. A complete
/// document has `schemaVersion` 1 and a `verdict`. Anything else (invalid JSON,
/// another schema version, neither key) is [BenchAborted] with the reason, so
/// the row fails instead of waiting for the timeout.
BenchPoll classifyResult(String? json) {
  if (json == null || json.isEmpty || json == 'null') {
    return const BenchPending();
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException catch (e) {
    return BenchAborted('Published result is not JSON: ${e.message}');
  }
  return switch (decoded) {
    {'schemaVersion': 1, 'aborted': final Object reason} &&
        final Map<String, Object?> document =>
      BenchAborted('Benchmark aborted: $reason', document: document),
    {'schemaVersion': 1, 'verdict': _} && final Map<String, Object?> document =>
      BenchDone(document),
    {'schemaVersion': final Object? version} &&
        final Map<String, Object?> document =>
      BenchAborted(
        'Unexpected result (schemaVersion $version, neither verdict nor '
        'aborted).',
        document: document,
      ),
    _ => BenchAborted('Published result is not a JSON object.'),
  };
}

/// Environment facts the runner records next to the page's own (A3).
final class RunnerEnvironment {
  /// Creates the record.
  const RunnerEnvironment({
    required this.chromeExecutable,
    required this.chromeVersion,
    required this.launchArgs,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.deviceScaleFactor,
    this.userAgent,
    this.webglRenderer,
    this.crossOriginIsolated,
  });

  /// The Chrome binary that ran the page.
  final String chromeExecutable;

  /// Chrome's product string, for example `HeadlessChrome/156.0.8078.80`.
  final String chromeVersion;

  /// The arguments the runner added to Chrome's defaults.
  final List<String> launchArgs;

  /// The fixed viewport width in CSS pixels.
  final int viewportWidth;

  /// The fixed viewport height in CSS pixels.
  final int viewportHeight;

  /// The fixed device pixel ratio.
  final num deviceScaleFactor;

  /// `navigator.userAgent` of the page, when it could be read.
  final String? userAgent;

  /// `UNMASKED_RENDERER_WEBGL`, when it could be read.
  final String? webglRenderer;

  /// `crossOriginIsolated` of the page, when it could be read.
  final bool? crossOriginIsolated;

  /// The JSON form written into a row file.
  Map<String, Object?> toJson() => {
    'chromeExecutable': chromeExecutable,
    'chromeVersion': chromeVersion,
    'launchArgs': launchArgs,
    'viewport': {
      'width': viewportWidth,
      'height': viewportHeight,
      'deviceScaleFactor': deviceScaleFactor,
    },
    'userAgent': userAgent,
    'webglRenderer': webglRenderer,
    'crossOriginIsolated': crossOriginIsolated,
  };
}

/// The outcome of one row.
final class RowOutcome {
  /// Creates an outcome. A row with a [failure] has status `failed`.
  const RowOutcome({
    required this.row,
    required this.url,
    required this.smoke,
    required this.elapsed,
    this.failure,
    this.result,
    this.environment,
    this.consoleErrors = const [],
  });

  /// The row.
  final BenchRow row;

  /// The page URL that was opened.
  final String url;

  /// Whether this was a smoke run.
  final bool smoke;

  /// Wall-clock time of the row, including launch.
  final Duration elapsed;

  /// Why the row failed, or `null` when it succeeded.
  final String? failure;

  /// The published document (complete, or the abort document).
  final Map<String, Object?>? result;

  /// What the runner recorded about Chrome and the page.
  final RunnerEnvironment? environment;

  /// Console errors seen while the page ran.
  final List<String> consoleErrors;

  /// Whether the row produced a complete result.
  bool get succeeded => failure == null;

  /// The row file: status, reason, environment and the page's document.
  Map<String, Object?> toJson() => {
    'runnerSchemaVersion': runnerSchemaVersion,
    'row': row.name,
    'renderer': row.renderer,
    'threads': row.threads,
    'status': succeeded ? 'done' : 'failed',
    'reason': failure,
    'smoke': smoke,
    'url': url,
    'elapsedSeconds': elapsed.inMilliseconds / 1000,
    'environment': environment?.toJson(),
    'consoleErrors': consoleErrors,
    'result': result,
  };
}

/// The `summary.json` document: one entry per row run.
Map<String, Object?> summaryJson(List<RowOutcome> outcomes) => {
  'runnerSchemaVersion': runnerSchemaVersion,
  'rows': [
    for (final outcome in outcomes)
      {
        'row': outcome.row.name,
        'file': '${outcome.row.fileStem}.json',
        'status': outcome.succeeded ? 'done' : 'failed',
        'reason': outcome.failure,
        'smoke': outcome.smoke,
        'verdictPassed': switch (outcome.result) {
          {'verdict': {'passed': final bool passed}} => passed,
          _ => null,
        },
      },
  ],
};
