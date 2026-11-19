/// The sweep of what a killed import left behind.
library;

import 'dart:io';

import 'sde_source.dart';
import 'static_data_store.dart';

/// Cleans up after imports that died, while the caller holds the lock.
///
/// Marks every other `running` import record `failed` ("interrupted") at [at]
/// and deletes the temporary directories a killed import left in
/// [scratchRoot] (none when it is `null`). Safe only under the static-data
/// lock, which every import of the database holds while it works: no other
/// import is live, and the root belongs to this database, so no directory
/// with the sources' prefix in it belongs to a live import. Best effort for
/// the directories: nothing is recorded and no path is logged.
Future<void> sweepStaleImportWork({
  required StaticDataStore store,
  required DateTime at,
  Directory? scratchRoot,
}) async {
  await store.failRunningRecords(reason: 'interrupted', at: at);
  await _removeStaleScratch(scratchRoot);
}

Future<void> _removeStaleScratch(Directory? root) async {
  if (root == null || !root.existsSync()) return;
  try {
    await for (final entity in root.list(followLinks: false)) {
      if (entity is Directory &&
          entity.uri.pathSegments
              .lastWhere((segment) => segment.isNotEmpty)
              .startsWith(sdeScratchPrefix)) {
        try {
          await entity.delete(recursive: true);
        } on FileSystemException {
          // Left for the next import.
        }
      }
    }
  } on FileSystemException {
    // An unreadable root changes nothing about the import.
  }
}
