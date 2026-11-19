/// The text the development build-diff task prints.
library;

import 'package:kaname_static_data/kaname_static_data.dart';

/// A readable form of [report]: per file its status, the added, removed and
/// changed counts with their keys, and the changed fields.
///
/// The counts are always complete. A key list that the report cut off is
/// marked with the number of keys it holds. A file with no changes still
/// appears with zero counts, as in the stored report.
String renderBuildDiff(BuildDiffReport report) {
  final out = StringBuffer()
    ..writeln('Build diff: ${report.fromBuild} -> ${report.toBuild}');
  if (report.files.isEmpty) {
    out.writeln('No files in either build.');
    return out.toString();
  }
  for (final file in report.files) {
    out
      ..writeln('${file.file} (${file.status.jsonName})')
      ..writeln('  added:   ${_changes(file.added)}')
      ..writeln('  removed: ${_changes(file.removed)}')
      ..writeln('  changed: ${_changes(file.changed)}');
    if (file.changedFields.isNotEmpty) {
      final fields = [
        for (final field in file.changedFields.keys.toList()..sort())
          '$field (${file.changedFields[field]})',
      ];
      out.writeln('  changed fields: ${fields.join(', ')}');
    }
  }
  return out.toString();
}

String _changes(RecordChanges changes) {
  final RecordChanges(:count, :keys, :truncated) = changes;
  if (keys.isEmpty) return '$count';
  final listed = keys.join(', ');
  return truncated
      ? '$count (keys: $listed, ... cut off after ${keys.length})'
      : '$count (keys: $listed)';
}
