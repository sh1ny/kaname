/// An SDE build read from a zip file on this machine.
library;

import 'dart:io';

import 'sde_limits.dart';
import 'sde_source.dart';
import 'zip_sde_archive.dart';

/// Reads a build from a local zip file in CCP's JSON Lines layout.
///
/// This is the source of tests and of the development task. The zip is read
/// in place and never modified; entries are unpacked into a temporary
/// directory that the opened archive deletes on close. Failure reasons say
/// "local zip" and never name the file's path.
final class LocalZipSdeSource implements SdeSource {
  /// Creates a source for [zipFile].
  ///
  /// [scratchRoot] is where the temporary directory is created; it defaults
  /// to the system temporary directory.
  LocalZipSdeSource(
    this.zipFile, {
    this.limits = const SdeLimits(),
    Directory? scratchRoot,
  }) : scratchRoot = scratchRoot ?? Directory.systemTemp;

  /// The zip file.
  final File zipFile;

  /// The caps applied while unpacking.
  final SdeLimits limits;

  /// The directory that holds the temporary working directory.
  final Directory scratchRoot;

  @override
  SdeSourceKind get kind => SdeSourceKind.local;

  @override
  Future<int?> announcedBuild() async => null;

  @override
  Future<SdeArchive> open() async {
    if (!zipFile.existsSync()) {
      throw const SdeSourceException('local zip does not exist');
    }
    final workDir = await scratchRoot.createTemp('kaname_sde_');
    return ZipSdeArchive.open(
      zipFile: zipFile,
      workDir: workDir,
      limits: limits,
      sourceName: 'local zip',
    );
  }
}
