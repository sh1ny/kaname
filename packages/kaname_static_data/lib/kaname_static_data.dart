/// Importer for the EVE static data export (SDE).
///
/// The package reads one SDE build from CCP or a local zip, parses it into
/// typed rows and raw records, reports drift and missing data, and writes the
/// result through a `StaticDataStore`. It is pure Dart, so the server and the
/// solo build share it.
library;

export 'src/ccp_sde_source.dart';
export 'src/field_check.dart';
export 'src/import_build.dart';
export 'src/import_report.dart';
export 'src/import_sde_job.dart';
export 'src/in_memory_static_data_store.dart';
export 'src/known_files.dart';
export 'src/known_ids.dart';
export 'src/local_zip_sde_source.dart';
export 'src/rollback_job.dart';
export 'src/sde_ingest.dart';
export 'src/sde_limits.dart';
export 'src/sde_rows.dart';
export 'src/sde_source.dart';
export 'src/static_data_store.dart';
export 'src/typed_files.dart';
export 'src/zip_sde_archive.dart';
