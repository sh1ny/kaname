import 'dart:collection';

import 'package:kaname_static_data/kaname_static_data.dart';

import '../generated/protocol.dart';

/// Converts a stored comparison into a bounded public report (D16, C12).
///
/// Keys are kept in stored file and kind order, up to 20,000 across the
/// answer. Stored truncation is preserved, and any further cut is marked;
/// counts remain complete. Per file, the first 200 field names in lexical
/// order are retained alongside the complete number of distinct fields.
/// [activeBuild] can be either end of the comparison after a rollback.
StaticDataChangeReport capChangeReport(
  BuildDiffReport report, {
  required int activeBuild,
}) {
  var remaining = 20000;

  StaticDataReportChanges capChanges(RecordChanges changes) {
    final length = changes.keys.length;
    final kept = length < remaining ? length : remaining;
    remaining -= kept;
    return StaticDataReportChanges(
      count: changes.count,
      keys: kept == length ? changes.keys : changes.keys.sublist(0, kept),
      cutOff: changes.truncated || kept < length,
    );
  }

  StaticDataReportFile capFile(FileDiff file) {
    final fields = SplayTreeMap<String, int>();
    for (final MapEntry(:key, :value) in file.changedFields.entries) {
      if (fields.length < 200) {
        fields[key] = value;
      } else if (key.compareTo(fields.lastKey()!) < 0) {
        fields.remove(fields.lastKey());
        fields[key] = value;
      }
    }
    return StaticDataReportFile(
      file: file.file,
      status: switch (file.status) {
        DiffFileStatus.both => StaticDataReportFileStatus.both,
        DiffFileStatus.newFile => StaticDataReportFileStatus.newFile,
        DiffFileStatus.removedFile => StaticDataReportFileStatus.removedFile,
      },
      added: capChanges(file.added),
      removed: capChanges(file.removed),
      changed: capChanges(file.changed),
      changedFields: fields,
      changedFieldCount: file.changedFields.length,
      changedFieldsCutOff: file.changedFields.length > 200,
    );
  }

  return StaticDataChangeReport(
    outcome: StaticDataReportOutcome.reportReady,
    activeBuild: activeBuild,
    fromBuild: report.fromBuild,
    toBuild: report.toBuild,
    files: [for (final file in report.files) capFile(file)],
  );
}
