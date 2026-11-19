/// Test support for code that imports SDE builds.
///
/// This library is for tests only and is not exported from
/// `kaname_static_data.dart`. It builds synthetic SDE zips from Dart
/// literals (design D9), so the importer's own tests and the server's
/// Postgres tests share one fixture builder. Every record is invented; no
/// CCP data is used.
library;

export 'src/testing/sde_fixture.dart';
export 'src/testing/sde_zip.dart';
