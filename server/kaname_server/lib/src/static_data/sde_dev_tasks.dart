/// The runs of the development tasks `sde:diff` and `sde:rollback`.
///
/// The tools in `tool/` only read the command line and open the development
/// database; the behaviour lives here so the integration tests reach it
/// through the same seam.
library;

import 'package:kaname_static_data/kaname_static_data.dart';

import 'postgres_static_data_store.dart';
import 'sde_diff_args.dart';
import 'sde_diff_render.dart';

/// Opens a store on the database the task works on.
typedef StoreOpener = Future<PostgresStaticDataStore> Function();

/// Compares the two builds [request] names and prints the report to [out].
///
/// The comparison only reads, in one repeatable-read read-only transaction
/// (D7): it stores nothing and takes no lock. Returns the exit code: 0 when
/// compared; 1, with the reason on [err], when a build is not stored
/// (`build not stored: N`), the comparison failed or the database cannot be
/// opened (the [precondition] is then added).
Future<int> runSdeDiff(
  SdeDiffRun request, {
  required StoreOpener open,
  required StringSink out,
  required StringSink err,
  required String precondition,
}) async {
  final PostgresStaticDataStore store;
  try {
    store = await open();
  } on Object catch (error) {
    err
      ..writeln('Cannot connect to the development database: $error')
      ..writeln(precondition);
    return 1;
  }
  try {
    final report = await store.differ().compare(
      request.fromBuild,
      request.toBuild,
    );
    out.write(renderBuildDiff(report));
    return 0;
  } on BuildNotStoredException catch (error) {
    err.writeln('sde:diff: $error');
    return 1;
  } on Object catch (error) {
    err.writeln('sde:diff: the comparison failed: $error');
    return 1;
  } finally {
    await store.close();
  }
}

/// Rolls back to the previous build and prints the outcome.
///
/// Runs [RollbackJob], which takes the store's lock without waiting and
/// closes the store. Returns the exit code: 0 and `from`/`to` on [out] when
/// rolled back; 1 with the reason (`import running`, `no previous build`,
/// ...) on [err] otherwise, or when the database cannot be opened (the
/// [precondition] is then added).
Future<int> runSdeRollback({
  required StoreOpener open,
  required StringSink out,
  required StringSink err,
  required String precondition,
}) async {
  final PostgresStaticDataStore store;
  try {
    store = await open();
  } on Object catch (error) {
    err
      ..writeln('Cannot connect to the development database: $error')
      ..writeln(precondition);
    return 1;
  }
  switch (await RollbackJob(store: store).run()) {
    case RollbackSucceeded(:final fromBuild, :final toBuild):
      out.writeln(
        'Rolled back: build $toBuild is active again; build $fromBuild is '
        'now the previous build and held.',
      );
      return 0;
    case RollbackFailed(:final reason):
      err.writeln('sde:rollback: $reason');
      return 1;
  }
}
