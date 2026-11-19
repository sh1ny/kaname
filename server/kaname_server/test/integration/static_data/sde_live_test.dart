@Tags(['sde-live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/migrated_database.dart';
import '../test_tools/serverpod_test_tools.dart';

/// Imports CCP's latest build into a scratch database through the production
/// path and prints what it measured (design task 8.2).
///
/// Opt-in: it downloads the build (about 100 MB) from CCP, so it is tagged
/// `sde-live` and runs only with `mise run test:sde-live`, never in
/// `test:server` or in CI. The printed Markdown holds the build number, the
/// record counts, the sizes, the import and whole-build delete times, the
/// reports, and a pass or fail per Resource Bounds cap. When the environment
/// variable `SDE_LIVE_REPORT` names a file, the Markdown is written there as
/// well.
void main() {
  withServerpod('Given a migrated scratch database', (
    sessionBuilder,
    endpoints,
  ) {
    late Session session;
    late PostgresConnectionSettings settings;

    setUp(() async {
      session = sessionBuilder.build();
      settings = await migratedDatabaseSettings(session);
      await session.db.unsafeExecute(
        'TRUNCATE ${PostgresStaticDataStore.writtenTables.keys.join(', ')}',
      );
    });

    test(
      'when CCP\'s latest build is imported then it is stored within every '
      'resource bound and removable in one transaction',
      timeout: const Timeout(Duration(hours: 3)),
      () async {
        final client = http.Client();
        addTearDown(client.close);
        final source = _MeasuringSource(CcpSdeSource(client: client));
        final store = await PostgresStaticDataStore.open(settings);

        final importTimer = Stopwatch()..start();
        final result = await ImportSdeJob(store: store, source: source).run();
        importTimer.stop();

        if (result is! ImportSucceeded) {
          fail('the import did not succeed: ${_describe(result)}');
        }
        final delete = await _deleteBuild(settings, result.build);
        final markdown = renderLiveReport(
          result: result,
          measured: source.measured,
          importDuration: importTimer.elapsed,
          delete: delete,
        );
        // The block is the test's output.
        // ignore: avoid_print
        print(markdown);
        final path = Platform.environment['SDE_LIVE_REPORT'];
        if (path != null && path.isNotEmpty) {
          File(path).writeAsStringSync(markdown);
        }

        final failed = [
          for (final cap in capChecks(
            source.measured,
            importTimer.elapsed,
            const SdeLimits(),
          ))
            if (!cap.passed) cap.name,
        ];
        expect(failed, isEmpty, reason: 'caps exceeded');
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}

String _describe(ImportResult result) => switch (result) {
  ImportSucceeded() => 'succeeded',
  ImportFailed(:final reason) => 'failed: $reason',
  ImportSkipped(:final reason) => 'skipped: $reason',
};

/// What was counted while the job read the build.
final class Measured {
  /// The zip file's size.
  int zipBytes = 0;

  /// The sum of the entries' declared unpacked sizes.
  int unpackedBytes = 0;

  /// The largest entry's declared unpacked size.
  int largestEntryBytes = 0;

  /// The longest line read, in bytes.
  int longestLineBytes = 0;

  /// How long opening took: the download and reading the zip's directory.
  Duration openDuration = Duration.zero;
}

/// A source that passes everything to [_inner] and measures the archive.
final class _MeasuringSource implements SdeSource {
  _MeasuringSource(this._inner);

  final SdeSource _inner;

  /// The measurements, complete once the import has read the archive.
  final Measured measured = Measured();

  @override
  SdeSourceKind get kind => _inner.kind;

  @override
  Future<int?> announcedBuild() => _inner.announcedBuild();

  @override
  Future<SdeArchive> open() async {
    final timer = Stopwatch()..start();
    final archive = await _inner.open();
    measured.openDuration = timer.elapsed;
    if (archive is ZipSdeArchive) {
      measured
        ..zipBytes = archive.zipBytes
        ..unpackedBytes = archive.declaredUnpackedBytes
        ..largestEntryBytes = archive.largestEntryBytes;
    }
    return _MeasuringArchive(archive, measured);
  }
}

final class _MeasuringArchive implements SdeArchive {
  _MeasuringArchive(this._inner, this._measured);

  final SdeArchive _inner;
  final Measured _measured;

  @override
  List<String> get fileNames => _inner.fileNames;

  @override
  Stream<SdeLine> lines(String fileName) => _inner.lines(fileName).map((line) {
    if (line is SdeTextLine) {
      final bytes = utf8.encode(line.text).length;
      if (bytes > _measured.longestLineBytes) {
        _measured.longestLineBytes = bytes;
      }
    }
    return line;
  });

  @override
  Future<void> close() => _inner.close();
}

/// How the whole-build delete went.
final class DeleteMeasurement {
  /// Creates the measurement.
  const DeleteMeasurement({required this.rows, required this.duration});

  /// The rows deleted, including the `sde_build` row.
  final int rows;

  /// How long the single transaction took.
  final Duration duration;
}

/// Deletes every row of [build] from every table the store writes except the
/// import records, in one transaction, and times it: the stand-in for
/// removing a staged build.
Future<DeleteMeasurement> _deleteBuild(
  PostgresConnectionSettings settings,
  int build,
) async {
  final connection = await pg.Connection.open(
    pg.Endpoint(
      host: settings.host,
      port: settings.port,
      database: settings.database,
      username: settings.user,
      password: settings.password,
      isUnixSocket: settings.isUnixSocket,
    ),
    settings: const pg.ConnectionSettings(sslMode: pg.SslMode.disable),
  );
  try {
    // The build row goes last, after every table that holds its rows.
    final tables = [
      for (final table in PostgresStaticDataStore.writtenTables.keys)
        if (table != 'sde_import' && table != 'sde_build') table,
      'sde_build',
    ];
    final timer = Stopwatch()..start();
    var rows = 0;
    await connection.runTx((tx) async {
      for (final table in tables) {
        final result = await tx.execute(
          'DELETE FROM "$table" WHERE "build" = \$1',
          parameters: [build],
        );
        rows += result.affectedRows;
      }
    });
    timer.stop();
    return DeleteMeasurement(rows: rows, duration: timer.elapsed);
  } finally {
    await connection.close();
  }
}

/// One Resource Bounds cap and whether the measurement stayed within it.
final class CapCheck {
  /// Creates the check.
  const CapCheck(this.name, this.measured, this.cap, {required this.passed});

  /// The cap's name.
  final String name;

  /// The measured value, formatted.
  final String measured;

  /// The cap, formatted.
  final String cap;

  /// Whether the measurement is within the cap.
  final bool passed;
}

/// Compares [measured] and [importDuration] with the caps of [limits].
List<CapCheck> capChecks(
  Measured measured,
  Duration importDuration,
  SdeLimits limits,
) => [
  CapCheck(
    'Download size',
    SdeLimits.describeBytes(measured.zipBytes),
    SdeLimits.describeBytes(limits.maxDownloadBytes),
    passed: measured.zipBytes <= limits.maxDownloadBytes,
  ),
  CapCheck(
    'Largest entry, unpacked',
    SdeLimits.describeBytes(measured.largestEntryBytes),
    SdeLimits.describeBytes(limits.maxEntryBytes),
    passed: measured.largestEntryBytes <= limits.maxEntryBytes,
  ),
  CapCheck(
    'All entries, unpacked',
    SdeLimits.describeBytes(measured.unpackedBytes),
    SdeLimits.describeBytes(limits.maxTotalBytes),
    passed: measured.unpackedBytes <= limits.maxTotalBytes,
  ),
  CapCheck(
    'Longest line',
    SdeLimits.describeBytes(measured.longestLineBytes),
    SdeLimits.describeBytes(limits.maxLineBytes),
    passed: measured.longestLineBytes <= limits.maxLineBytes,
  ),
  CapCheck(
    'Whole import',
    _seconds(importDuration),
    SdeLimits.describeDuration(limits.importTimeout),
    passed: importDuration <= limits.importTimeout,
  ),
];

String _seconds(Duration duration) =>
    '${(duration.inMilliseconds / 1000).toStringAsFixed(1)} s';

String _mib(int bytes) =>
    '${(bytes / SdeLimits.mebibyte).toStringAsFixed(1)} MiB';

/// The Markdown block for an import of [result].
String renderLiveReport({
  required ImportSucceeded result,
  required Measured measured,
  required Duration importDuration,
  required DeleteMeasurement delete,
}) {
  final report = result.report;
  final out = StringBuffer()
    ..writeln('## SDE live import: build ${result.build}')
    ..writeln()
    ..writeln('| Measure | Value |')
    ..writeln('| --- | ---: |')
    ..writeln('| Build | ${result.build} (${result.state.name}) |')
    ..writeln(
      '| Zip downloaded | ${measured.zipBytes} bytes '
      '(${_mib(measured.zipBytes)}) |',
    )
    ..writeln(
      '| Unpacked (sum of entries) | ${measured.unpackedBytes} bytes '
      '(${_mib(measured.unpackedBytes)}) |',
    )
    ..writeln('| Download and open | ${_seconds(measured.openDuration)} |')
    ..writeln('| Whole import | ${_seconds(importDuration)} |')
    ..writeln(
      '| Whole-build delete, one transaction | ${_seconds(delete.duration)} '
      '(${delete.rows} rows) |',
    )
    ..writeln()
    ..writeln('### Resource bounds')
    ..writeln()
    ..writeln('| Cap | Measured | Limit | Result |')
    ..writeln('| --- | ---: | ---: | --- |');
  for (final cap in capChecks(measured, importDuration, const SdeLimits())) {
    out.writeln(
      '| ${cap.name} | ${cap.measured} | ${cap.cap} | '
      '${cap.passed ? 'pass' : 'FAIL'} |',
    );
  }
  final total = report.fileCounts.values.fold(0, (sum, n) => sum + n);
  out
    ..writeln()
    ..writeln(
      '### Records per file ($total records in '
      '${report.fileCounts.length} files)',
    )
    ..writeln()
    ..writeln('| File | Records |')
    ..writeln('| --- | ---: |');
  for (final MapEntry(:key, :value) in report.fileCounts.entries) {
    out.writeln('| $key | $value |');
  }
  final drift = report.drift;
  out
    ..writeln()
    ..writeln('### Drift')
    ..writeln();
  if (drift.isEmpty) {
    out.writeln('None: the build matches the known files and fields.');
  } else {
    if (drift.newFiles.isNotEmpty) {
      out.writeln('- New files: ${drift.newFiles.join(', ')}');
    }
    for (final FieldCount(:file, :field, :records) in drift.newFields) {
      out.writeln('- New field: $file `$field` ($records records)');
    }
    for (final FieldCount(:file, :field, :records) in drift.wrongTypedFields) {
      out.writeln('- Wrong type: $file `$field` ($records records)');
    }
    if (drift.missingFiles.isNotEmpty) {
      out.writeln(
        '- Known files missing from the build: '
        '${drift.missingFiles.join(', ')}',
      );
    }
  }
  final bad = report.badRecords;
  out
    ..writeln()
    ..writeln('### Bad records')
    ..writeln();
  if (bad.total == 0) {
    out.writeln('None.');
  } else {
    out.writeln('${bad.total} skipped:');
    for (final MapEntry(:key, :value) in bad.files.entries) {
      out.writeln('- $key: ${value.count}');
    }
  }
  final known = report.knownIds;
  out
    ..writeln()
    ..writeln('### Known ids')
    ..writeln()
    ..writeln(
      '${known.checked} checked, '
      '${known.passed ? 'all found' : '${known.findings.length} findings'}.',
    );
  for (final finding in known.findings) {
    out.writeln(
      '- ${finding.known.name} (${finding.known.id}): '
      '${finding.isMissing ? 'missing' : 'other kind'}',
    );
  }
  final check = report.fieldCheck;
  out
    ..writeln()
    ..writeln('### Industry and logistics field check')
    ..writeln()
    ..writeln(
      '${check.results.length - check.missing.length} of '
      '${check.results.length} declared fields present: '
      '${check.isComplete ? 'no gap' : 'gap'}.',
    );
  for (final missing in check.missing) {
    out.writeln('- Missing: ${missing.field.file} `${missing.field.path}`');
  }
  return out.toString();
}
