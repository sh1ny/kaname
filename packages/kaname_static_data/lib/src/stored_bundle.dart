/// The client data bundles a store keeps for its builds, and the step that
/// builds one from a stored build.
library;

import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart'
    as bundle;

import 'known_files.dart';
import 'static_data_store.dart';
import 'typed_files.dart';
import 'zip_sde_archive.dart' show describeFailure;

/// How the bundle build of one stored build ended.
enum BundleOutcome {
  /// The bundle is stored with its bytes.
  built,

  /// The build failed; its reason is stored and there are no bytes.
  failed,
}

/// The metadata of one build's stored bundle, never its bytes (C11).
final class StoredBundle {
  /// Creates the metadata of [build]'s bundle.
  const StoredBundle({
    required this.build,
    required this.outcome,
    required this.formatMajor,
    required this.formatMinor,
    required this.builtAt,
    this.reason,
    this.sha256,
    this.size,
  });

  /// The build the bundle belongs to.
  final int build;

  /// How the newest bundle build of [build] ended.
  final BundleOutcome outcome;

  /// Why the bundle build failed; `null` for a built bundle.
  final String? reason;

  /// The major format version the builder wrote or tried.
  final int formatMajor;

  /// The minor format version the builder wrote or tried.
  final int formatMinor;

  /// The SHA-256 of the bundle's bytes, as 64 lower-case hexadecimal digits;
  /// `null` for a failed build.
  final String? sha256;

  /// The size of the bundle's bytes; `null` for a failed build.
  final int? size;

  /// When the bundle build ended.
  final DateTime builtAt;

  /// Whether this is a built bundle in the format this builder writes, with
  /// its hash and size recorded.
  ///
  /// A failed bundle, a built one of another format version, and a built one
  /// missing its hash or size count as missing and are built again (D20,
  /// C12): the announcer reads the same rule, so it never asks for a repair
  /// this step would skip.
  bool get isCurrent =>
      outcome == BundleOutcome.built &&
      formatMajor == bundle.bundleFormatMajor &&
      formatMinor == bundle.bundleFormatMinor &&
      sha256 != null &&
      size != null;
}

/// What a store records about one build's bundle.
sealed class BundleWrite {
  const BundleWrite({required this.build, required this.at});

  /// The build the bundle belongs to.
  final int build;

  /// When the bundle build ended.
  final DateTime at;
}

/// A built bundle: its metadata and its bytes, stored together.
final class BundleWriteBuilt extends BundleWrite {
  /// Creates the write of [built], the bundle built for [build] at [at].
  const BundleWriteBuilt({
    required super.build,
    required super.at,
    required this.built,
  });

  /// The bundle the builder wrote, in the current format.
  final bundle.BuiltBundle built;
}

/// A bundle build that failed for [reason].
final class BundleWriteFailed extends BundleWrite {
  /// Creates the write of a failure of [build]'s bundle build at [at].
  const BundleWriteFailed({
    required super.build,
    required super.at,
    required this.reason,
  });

  /// Why the build failed; holds no credentials.
  final String reason;
}

/// Builds the bundle of the stored [build] from [store]'s records.
///
/// Both build paths use it: the server reads its stored build, and
/// `buildBundleFromZip` reads the in-memory store its import wrote. The
/// typed files' stored typed values and raw JSON are fed as typed records,
/// never re-projected from the raw JSON; the raw-only sections' stored
/// records as raw records with their lines, duplicates kept; and the
/// release date is picked from the build's `_sde.jsonl` objects in line
/// order with [bundle.selectReleaseDate] (C23). A section with no stored
/// record is absent (C24).
///
/// Throws a [bundle.BundleBuildException] when the records cannot be
/// written as a bundle, and whatever the store throws when it cannot read.
Future<bundle.BuiltBundle> buildStoredBundle(
  StaticDataStore store,
  int build,
) async {
  final builder = bundle.BundleBuilder(
    buildNumber: build,
    releaseDate: bundle.selectReleaseDate(build, [
      for (final record in await store.readRawRecords(build, sdeRecordFileName))
        record.record.value,
    ]),
  );
  for (final file in typedFiles) {
    final section = bundle.BundleSection.fromFile(file.fileName);
    if (section == null || section.isRawOnly) {
      throw StateError('${file.fileName} has no typed bundle section');
    }
    for (final row in await store.readTypedRows(build, file)) {
      builder.addTyped(
        section,
        bundle.TypedRecord(
          key: row.sdeId,
          values: row.values,
          raw: row.raw.value,
        ),
      );
    }
  }
  for (final section in bundle.BundleSection.values) {
    if (!section.isRawOnly) continue;
    for (final record in await store.readRawRecords(build, section.fileName)) {
      builder.addRaw(
        section,
        bundle.RawRecord(
          key: record.key,
          line: record.line,
          record: record.record.value,
        ),
      );
    }
  }
  return builder.build();
}

/// Builds the bundle of the stored build given as the second argument from
/// the store given as the first; [buildStoredBundle] in production.
typedef BuildBundle = Future<bundle.BuiltBundle> Function(
  StaticDataStore store,
  int build,
);

/// How one bundle step for a build ended.
sealed class BundleStepResult {
  const BundleStepResult(this.build);

  /// The build whose bundle the step looked at.
  final int build;
}

/// A built bundle of the current format was stored; nothing was built.
final class BundleAlreadyCurrent extends BundleStepResult {
  /// Creates the result for [build].
  const BundleAlreadyCurrent(super.build);
}

/// The bundle was built and stored.
final class BundleBuilt extends BundleStepResult {
  /// Creates the result for [build]'s stored bundle.
  const BundleBuilt(super.build, {required this.sha256, required this.size});

  /// The SHA-256 of the stored bytes.
  final String sha256;

  /// The size of the stored bytes.
  final int size;
}

/// The bundle build failed; the failure is recorded when the store allowed.
final class BundleFailed extends BundleStepResult {
  /// Creates the result for [build] with [reason].
  const BundleFailed(super.build, this.reason);

  /// Why the bundle could not be built or stored; holds no credentials.
  final String reason;
}

/// Builds and stores [build]'s bundle unless a built bundle of the current
/// format is stored ([StoredBundle.isCurrent]).
///
/// Only valid under the static-data lock (C7). The bundle is built with
/// [buildBundle] and stored with its bytes in one transaction
/// ([StaticDataStore.recordBundle]); a failure to build or store it is
/// recorded as a [BundleWriteFailed] with its reason, at [clock]'s time.
/// Never throws: every failure is a [BundleFailed].
Future<BundleStepResult> ensureBundle(
  StaticDataStore store,
  int build, {
  BuildBundle buildBundle = buildStoredBundle,
  DateTime Function() clock = DateTime.now,
}) async {
  String reason;
  try {
    final stored = await store.storedBundle(build);
    if (stored != null && stored.isCurrent) return BundleAlreadyCurrent(build);
    final built = await buildBundle(store, build);
    await store.recordBundle(
      BundleWriteBuilt(build: build, at: clock(), built: built),
    );
    return BundleBuilt(build, sha256: built.sha256, size: built.bytes.length);
  } on bundle.BundleBuildException catch (error) {
    reason = 'bundle build failed: $error';
  } on Object catch (error) {
    reason = 'bundle build failed: ${describeFailure(error)}';
  }
  try {
    await store.recordBundle(
      BundleWriteFailed(build: build, at: clock(), reason: reason),
    );
  } on Object {
    // The failure stays unrecorded; the next repair tries again.
  }
  return BundleFailed(build, reason);
}
