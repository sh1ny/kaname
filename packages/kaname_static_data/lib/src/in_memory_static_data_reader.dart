/// A [StaticDataReader] over an [InMemoryStaticDataStore].
library;

import 'in_memory_static_data_store.dart';
import 'sde_rows.dart';
import 'static_data_reader.dart';
import 'static_data_store.dart';

/// A hand-written fake of [StaticDataReader] for tests and solo mode.
///
/// It reads the store's current state on every lookup, so a switch or a
/// removal after the pin shows exactly as it does on the server.
final class InMemoryStaticDataReader implements StaticDataReader {
  /// Creates a reader over [store].
  const InMemoryStaticDataReader(this._store);

  final InMemoryStaticDataStore _store;

  @override
  Future<PinnedBuild> pinActiveBuild() async {
    for (final MapEntry(:key, :value) in _store.builds.entries) {
      if (value == BuildState.active) return _InMemoryPinnedBuild(_store, key);
    }
    throw const NoActiveBuild();
  }
}

final class _InMemoryPinnedBuild implements PinnedBuild {
  const _InMemoryPinnedBuild(this._store, this.build);

  final InMemoryStaticDataStore _store;

  @override
  final int build;

  TypedRow? _find(String table, int id) {
    for (final row in _store.typedRows(build, table)) {
      if (row.sdeId == id) return row;
    }
    // No row: it is a missing id only while the build is still stored.
    if (!_store.builds.containsKey(build)) throw BuildNoLongerStored(build);
    return null;
  }

  @override
  Future<SdeTypeRow?> type(int id) async {
    final row = _find('sde_type', id);
    if (row == null) return null;
    final TypedRow(:sdeId, :values, :raw) = row;
    return SdeTypeRow(
      sdeId: sdeId,
      groupId: values['groupId'] as int?,
      name: values['name'] as String?,
      published: values['published'] as bool?,
      volume: values['volume'] as double?,
      capacity: values['capacity'] as double?,
      portionSize: values['portionSize'] as int?,
      mass: values['mass'] as double?,
      marketGroupId: values['marketGroupId'] as int?,
      metaGroupId: values['metaGroupId'] as int?,
      raw: raw,
    );
  }

  @override
  Future<SdeSolarSystemRow?> solarSystem(int id) async {
    final row = _find('sde_solar_system', id);
    if (row == null) return null;
    final TypedRow(:sdeId, :values, :raw) = row;
    return SdeSolarSystemRow(
      sdeId: sdeId,
      constellationId: values['constellationId'] as int?,
      regionId: values['regionId'] as int?,
      name: values['name'] as String?,
      securityStatus: values['securityStatus'] as double?,
      securityClass: values['securityClass'] as String?,
      raw: raw,
    );
  }
}
