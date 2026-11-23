import 'dart:typed_data';

import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:serverpod/serverpod.dart' show Session;

/// Every table the static-data store writes, for the reset between tests.
const storeTables = [
  'sde_admin_operation',
  'sde_build_revision',
  'sde_setting_write',
  'sde_import',
  'sde_check',
  'sde_switch',
  'sde_build_diff',
  'sde_bundle',
  'sde_bundle_bytes',
  'sde_record',
  'sde_build',
  'sde_category',
  'sde_group',
  'sde_type',
  'sde_market_group',
  'sde_meta_group',
  'sde_dogma_attribute',
  'sde_dogma_attribute_category',
  'sde_dogma_effect',
  'sde_dogma_unit',
  'sde_type_dogma',
  'sde_region',
  'sde_constellation',
  'sde_solar_system',
];

/// Empties every table the static-data store writes.
Future<void> resetStore(Session session) =>
    session.db.unsafeExecute('TRUNCATE ${storeTables.join(', ')}');

/// A source that announces [build], as CCP would, and reads the build from
/// [inner].
final class AnnouncingSource implements SdeSource {
  /// Creates a source announcing [build] in front of [inner].
  AnnouncingSource(this.inner, this.build);

  /// The source the build is read from.
  final SdeSource inner;

  /// The build this source announces.
  final int build;

  @override
  SdeSourceKind get kind => inner.kind;

  @override
  Future<int?> announcedBuild() async => build;

  @override
  Future<SdeArchive> open() => inner.open();
}

/// The bundle metadata row of [build], or `null`.
Future<SdeBundle?> bundleRowOf(Session session, int build) =>
    SdeBundle.db.findFirstRow(session, where: (t) => t.build.equals(build));

/// The stored bundle bytes of [build], or `null` when none are stored.
///
/// Fails when [build] has more than one byte row (D3).
Future<Uint8List?> bundleBytesOf(Session session, int build) async {
  final rows = await SdeBundleBytes.db.find(
    session,
    where: (t) => t.build.equals(build),
  );
  if (rows.length > 1) {
    throw StateError('build $build has ${rows.length} bundle byte rows');
  }
  if (rows.isEmpty) return null;
  final data = rows.single.bytes;
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
