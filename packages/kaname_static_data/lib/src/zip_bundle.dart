/// Builds a client data bundle from a local SDE zip, with no server.
library;

import 'dart:io';

import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart'
    as bundle;

import 'import_build.dart';
import 'in_memory_static_data_store.dart';
import 'local_zip_sde_source.dart';
import 'sde_limits.dart';
import 'stored_bundle.dart';

/// Why a bundle could not be built from a local zip.
///
/// Unlike the import's recorded reasons, which never name a local path, this
/// exception is for the person running the builder, so it names the zip.
final class ZipBundleException implements Exception {
  /// Creates the exception for the zip at [zipPath] with [reason].
  const ZipBundleException(this.zipPath, this.reason);

  /// The path of the zip, as given to [buildBundleFromZip].
  final String zipPath;

  /// Why the bundle could not be built.
  final String reason;

  @override
  String toString() => 'cannot build a bundle from $zipPath: $reason';
}

/// Builds the client data bundle of the SDE build in [zipFile], with no
/// server.
///
/// The records are selected and projected by the import itself: the zip is
/// read through [LocalZipSdeSource] and imported by [importBuild] into an
/// [InMemoryStaticDataStore], so the build number, the required files, the
/// lines kept (unreadable lines dropped, the first record of a duplicate
/// typed key kept) and the typed values (a wrong-typed value is `null`) are
/// the import's. The bundle is then built from that store by
/// [buildStoredBundle], the same code the server runs on its stored build,
/// so both paths feed the builder alike.
///
/// Returns the bundle's bytes and writes no file: the caller decides where
/// they go. [limits] bound the unpacking and the import's duration;
/// [scratchRoot] holds the temporary directory the zip is unpacked into,
/// which is removed before this returns, and defaults to the system
/// temporary directory.
///
/// Throws a [ZipBundleException] naming [zipFile] when it is not a readable
/// SDE zip that the import would accept, or when its records cannot be
/// written as a bundle.
Future<bundle.BuiltBundle> buildBundleFromZip(
  File zipFile, {
  SdeLimits limits = const SdeLimits(),
  Directory? scratchRoot,
}) async {
  final store = InMemoryStaticDataStore();
  final attempt = await importBuild(
    store: store,
    source: LocalZipSdeSource(
      zipFile,
      limits: limits,
      scratchRoot: scratchRoot,
    ),
    startedAt: DateTime.now(),
    limits: limits,
  );
  final build = switch (attempt.result) {
    ImportSucceeded(:final build) => build,
    ImportFailed(:final reason) || ImportSkipped(:final reason) =>
      throw ZipBundleException(zipFile.path, reason),
  };
  try {
    return await buildStoredBundle(store, build);
  } on bundle.BundleBuildException catch (error) {
    throw ZipBundleException(zipFile.path, '$error');
  }
}
