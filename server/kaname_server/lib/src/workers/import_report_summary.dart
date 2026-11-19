/// The warning a finished import logs about what its build did not match.
library;

import 'package:kaname_static_data/kaname_static_data.dart';

/// The most names a summary lists for one kind of finding.
const int _maxNames = 5;

/// A one-line summary of what [report] found that needs a look, or `null`
/// when the build matched everything (design: "log summary at `warning`").
///
/// It counts drift (new files, new fields, wrong-typed fields, missing known
/// files), bad records, known ids that are missing or of another kind, and
/// missing industry and logistics (R38) fields, and names the new files and
/// fields, the known ids and the R38 fields, at most five of each.
String? summarizeImportReport(ImportReport report) {
  final parts = <String>[
    ?_part('new file', 'new files', report.drift.newFiles),
    ?_part('new field', 'new fields', [
      for (final FieldCount(:file, :field) in report.drift.newFields)
        '$file $field',
    ]),
    ?_part('wrong-typed field', 'wrong-typed fields', [
      for (final FieldCount(:file, :field) in report.drift.wrongTypedFields)
        '$file $field',
    ], named: false),
    ?_part(
      'known file missing',
      'known files missing',
      report.drift.missingFiles,
      named: false,
    ),
    if (report.badRecords.total > 0)
      '${report.badRecords.total} bad '
          '${report.badRecords.total == 1 ? 'record' : 'records'}',
    ?_part(
      'known id missing or of another kind',
      'known ids missing or of '
          'another kind',
      [for (final finding in report.knownIds.findings) finding.known.name],
    ),
    ?_part('R38 field missing', 'R38 fields missing', [
      for (final result in report.fieldCheck.missing)
        '${result.field.file} ${result.field.path}',
    ]),
  ];
  if (parts.isEmpty) return null;
  return 'import found: ${parts.join('; ')}';
}

String? _part(
  String singular,
  String plural,
  List<String> names, {
  bool named = true,
}) {
  if (names.isEmpty) return null;
  final label = '${names.length} ${names.length == 1 ? singular : plural}';
  if (!named) return label;
  final shown = names.take(_maxNames).join(', ');
  final more = names.length > _maxNames
      ? ', and ${names.length - _maxNames} more'
      : '';
  return '$label ($shown$more)';
}
