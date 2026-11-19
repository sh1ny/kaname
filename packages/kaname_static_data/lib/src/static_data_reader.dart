/// The pinned reader of the static data builds.
library;

import 'package:kaname_core/kaname_core.dart';

/// Reads static data from one build that stays the same for a request.
///
/// Every server-side static-data read goes through a reader and filters by
/// the build it pinned (C1; see the spec requirement "A request reads one
/// build from start to end"). No query may read "the active build" by joining
/// on the build state in the middle of a request: a switch between two such
/// reads would mix two builds.
abstract interface class StaticDataReader {
  /// Reads the active build number once and returns a view of that build.
  ///
  /// Throws [NoActiveBuild] when no build is active.
  Future<PinnedBuild> pinActiveBuild();
}

/// A view of one stored build, fixed when it was pinned.
///
/// A lookup returns `null` for an id the build does not have. When the build
/// itself has been removed, for example by two switches after the pin, a
/// lookup throws [BuildNoLongerStored] and never reads another build.
abstract interface class PinnedBuild {
  /// The build number every lookup reads.
  int get build;

  /// The type with [id], or `null` when the build has none.
  Future<SdeTypeRow?> type(int id);

  /// The solar system with [id], or `null` when the build has none.
  Future<SdeSolarSystemRow?> solarSystem(int id);
}

/// Why a pinned read failed.
sealed class StaticDataReadError implements Exception {
  const StaticDataReadError();
}

/// No build is active, so there is nothing to pin.
final class NoActiveBuild extends StaticDataReadError {
  /// Creates the error.
  const NoActiveBuild();

  @override
  String toString() => 'no active build';
}

/// The pinned [build] was removed before the lookup.
final class BuildNoLongerStored extends StaticDataReadError {
  /// Creates the error for [build].
  const BuildNoLongerStored(this.build);

  /// The build number that is gone.
  final int build;

  @override
  String toString() => 'build no longer stored: $build';
}

/// One item type of a build with its raw record.
final class SdeTypeRow {
  /// Creates a type row.
  const SdeTypeRow({
    required this.sdeId,
    required this.raw,
    this.groupId,
    this.name,
    this.published,
    this.volume,
    this.capacity,
    this.portionSize,
    this.mass,
    this.marketGroupId,
    this.metaGroupId,
  });

  /// The type's id.
  final int sdeId;

  /// The type's group id.
  final int? groupId;

  /// The type's English name.
  final String? name;

  /// Whether the type is published.
  final bool? published;

  /// The type's volume.
  final double? volume;

  /// The type's capacity.
  final double? capacity;

  /// The type's portion size.
  final int? portionSize;

  /// The type's mass.
  final double? mass;

  /// The type's market group id.
  final int? marketGroupId;

  /// The type's meta group id.
  final int? metaGroupId;

  /// The record exactly as CCP shipped it.
  final SdeJson raw;
}

/// One solar system of a build with its raw record.
final class SdeSolarSystemRow {
  /// Creates a solar system row.
  const SdeSolarSystemRow({
    required this.sdeId,
    required this.raw,
    this.constellationId,
    this.regionId,
    this.name,
    this.securityStatus,
    this.securityClass,
  });

  /// The system's id.
  final int sdeId;

  /// The system's constellation id.
  final int? constellationId;

  /// The system's region id.
  final int? regionId;

  /// The system's English name.
  final String? name;

  /// The system's security status.
  final double? securityStatus;

  /// The system's security class.
  final String? securityClass;

  /// The record exactly as CCP shipped it.
  final SdeJson raw;
}
