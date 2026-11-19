/// The server's pinned reader of the static data builds.
library;

import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// Reads the static data through the Serverpod ORM on the main isolate.
///
/// [pinActiveBuild] runs the equivalent of
/// `SELECT build FROM sde_build WHERE state = 'active'` once, and every
/// lookup of the returned [PinnedBuild] adds `build = N` to its query. Every
/// server-side static-data read goes through this reader (C1; see the spec
/// requirement "A request reads one build from start to end"): no query reads
/// "the active build" by joining on state in the middle of a request.
final class OrmStaticDataReader implements StaticDataReader {
  /// Creates a reader that queries through [session].
  const OrmStaticDataReader(this._session);

  final Session _session;

  @override
  Future<PinnedBuild> pinActiveBuild() async {
    final active = await SdeBuild.db.findFirstRow(
      _session,
      where: (t) => t.state.equals(SdeBuildState.active),
    );
    if (active == null) throw const NoActiveBuild();
    return _OrmPinnedBuild(_session, active.build);
  }
}

final class _OrmPinnedBuild implements PinnedBuild {
  const _OrmPinnedBuild(this._session, this.build);

  final Session _session;

  @override
  final int build;

  /// Throws [BuildNoLongerStored] when the pinned build's row is gone.
  ///
  /// Called only after a lookup found no row, so a missing id inside a stored
  /// build stays `null`.
  Future<void> _requireStored() async {
    final row = await SdeBuild.db.findFirstRow(
      _session,
      where: (t) => t.build.equals(build),
    );
    if (row == null) throw BuildNoLongerStored(build);
  }

  @override
  Future<SdeTypeRow?> type(int id) async {
    final row = await SdeType.db.findFirstRow(
      _session,
      where: (t) => t.build.equals(build) & t.sdeId.equals(id),
    );
    if (row == null) {
      await _requireStored();
      return null;
    }
    return SdeTypeRow(
      sdeId: row.sdeId,
      groupId: row.groupId,
      name: row.name,
      published: row.published,
      volume: row.volume,
      capacity: row.capacity,
      portionSize: row.portionSize,
      mass: row.mass,
      marketGroupId: row.marketGroupId,
      metaGroupId: row.metaGroupId,
      raw: row.raw,
    );
  }

  @override
  Future<SdeSolarSystemRow?> solarSystem(int id) async {
    final row = await SdeSolarSystem.db.findFirstRow(
      _session,
      where: (t) => t.build.equals(build) & t.sdeId.equals(id),
    );
    if (row == null) {
      await _requireStored();
      return null;
    }
    return SdeSolarSystemRow(
      sdeId: row.sdeId,
      constellationId: row.constellationId,
      regionId: row.regionId,
      name: row.name,
      securityStatus: row.securityStatus,
      securityClass: row.securityClass,
      raw: row.raw,
    );
  }
}
