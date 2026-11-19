/// Imports one SDE build into the development database.
///
/// Run it with `mise run sde:import -- <zip>|--latest [--r38-report <path>]`.
///
/// **Precondition:** the development server is running (`mise run
/// server:dev`). It starts the embedded Postgres this tool connects to,
/// through the socket the server's data directory names; the tool has no
/// Serverpod session of its own and starts no database. When the socket or
/// the database cannot be reached, the tool says so and exits with 1.
///
/// The tool runs `ImportSdeJob` against the `development` database in its
/// own process, then prints the import record. With `--r38-report` it also
/// writes the R38 field report from the record's field check. A build that
/// is already stored is skipped; the report is then taken from the record of
/// the import that stored it.
///
/// Exit codes: 0 when the import succeeded or was skipped, 1 when it failed
/// or the database could not be used, 64 for a bad command line.
library;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kaname_server/src/static_data/development_postgres_settings.dart';
import 'package:kaname_server/src/static_data/import_record_view.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_server/src/static_data/scratch_root.dart';
import 'package:kaname_server/src/static_data/sde_import_args.dart';
import 'package:kaname_server/src/static_data/sde_import_render.dart';
import 'package:kaname_server/src/workers/compute_worker.dart';
import 'package:kaname_server/src/workers/worker_messages.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:path/path.dart' as p;

const String _precondition =
    'The development server must be running (mise run server:dev): it starts '
    'the embedded Postgres this task connects to.';

Future<void> main(List<String> args) async {
  exitCode = await _run(args);
}

Future<int> _run(List<String> args) async {
  switch (parseSdeImportArgs(args)) {
    case SdeImportHelp():
      stdout.writeln(sdeImportUsage);
      return 0;
    case SdeImportUsageError(:final message):
      stderr
        ..writeln('sde:import: $message')
        ..writeln()
        ..writeln(sdeImportUsage);
      return sdeImportUsageExitCode;
    case final SdeImportRun request:
      return _import(request);
  }
}

PostgresConnectionSettings _settings() {
  final directory = Directory.current.path;
  return developmentPostgresSettings(
    configYaml: File(p.join(directory, 'config', 'development.yaml'))
        .readAsStringSync(),
    passwordsYaml: File(p.join(directory, 'config', 'passwords.yaml'))
        .readAsStringSync(),
    serverDirectory: directory,
    readFile: (path) {
      final file = File(path);
      return file.existsSync() ? file.readAsStringSync() : null;
    },
  );
}

Future<int> _import(SdeImportRun request) async {
  final PostgresConnectionSettings settings;
  try {
    settings = _settings();
  } on Object catch (error) {
    stderr
      ..writeln('Cannot locate the development database: $error.')
      ..writeln(_precondition);
    return 1;
  }

  final spec = switch (request.source) {
    LocalZipSource(:final path) => LocalZipSource(_fromCallerDirectory(path)),
    final other => other,
  };
  final PostgresStaticDataStore store;
  try {
    store = await PostgresStaticDataStore.open(settings);
  } on Object catch (error) {
    stderr
      ..writeln('Cannot connect to the development database: $error')
      ..writeln(_precondition);
    return 1;
  }
  final client = http.Client();
  final scratchRoot = sdeScratchRootFor(settings);
  final job = ImportSdeJob(
    store: store,
    source: defaultSdeSourceFactory(spec, client, scratchRoot),
    scratchRoot: scratchRoot,
  );
  final ImportResult result;
  try {
    result = await job.run(); // The job closes the store.
  } finally {
    client.close();
  }
  final recordId = job.recordId;
  if (recordId == null) {
    stderr.writeln(
      'The import left no record: '
      '${result is ImportFailed ? result.reason : 'no reason given'}.',
    );
    return 1;
  }

  // The job's own record, and the record that holds the build's reports when
  // the job stored nothing because the build was already there.
  final ImportRecordView? record;
  final ImportRecordView? reportRecord;
  try {
    final reader = await PostgresStaticDataStore.open(settings);
    try {
      record = await reader.importRecord(recordId);
      reportRecord = switch (result) {
        ImportSucceeded() => record,
        ImportSkipped(build: final int build) =>
          await reader.latestSucceededImportOf(build),
        _ => null,
      };
    } finally {
      await reader.close();
    }
  } on Object catch (error) {
    stderr
      ..writeln('The import ended, but its record cannot be read: $error')
      ..writeln(_precondition);
    return 1;
  }
  if (record == null) {
    stderr.writeln('The import left no record.');
    return 1;
  }
  stdout.writeln(switch (result) {
    ImportSucceeded(:final build, :final state) =>
      'Result: build $build stored as ${state.name}',
    ImportSkipped(:final reason) => 'Result: skipped ($reason)',
    ImportFailed(:final reason) => 'Result: failed ($reason)',
  });
  stdout.write(renderImportSummary(record));

  if (request.r38ReportPath case final String path) {
    if (reportRecord == null) {
      stderr.writeln(
        'No R38 report: this import stored no build, and no succeeded '
        'import of its build is on record.',
      );
      return 1;
    }
    final target = File(_fromCallerDirectory(path));
    await target.parent.create(recursive: true);
    await target.writeAsString(renderR38Report(reportRecord));
    stdout.writeln('R38 report written to ${target.path}');
  }
  return switch (result) {
    ImportFailed() => 1,
    ImportSucceeded() || ImportSkipped() => 0,
  };
}

/// Mise runs the task in the server package; paths the user typed refer to
/// the directory they ran mise from.
String _fromCallerDirectory(String path) {
  final base = Platform.environment['MISE_ORIGINAL_CWD'];
  return base == null ? path : p.normalize(p.absolute(base, path));
}
