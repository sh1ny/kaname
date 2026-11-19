/// The text the development import task prints and writes.
library;

import 'import_record_view.dart';

/// A readable summary of [record]: build, source, outcome, reason, counts,
/// drift, bad records, known ids and the field check.
String renderImportSummary(ImportRecordView record) {
  final out = StringBuffer()
    ..writeln('Import record')
    ..writeln('  build:    ${record.build ?? 'unknown'}')
    ..writeln('  source:   ${record.source}')
    ..writeln('  outcome:  ${record.outcome}')
    ..writeln('  reason:   ${record.failureReason ?? '-'}')
    ..writeln('  started:  ${record.startedAt.toUtc().toIso8601String()}')
    ..writeln(
      '  finished: '
      '${record.finishedAt?.toUtc().toIso8601String() ?? '-'}',
    );
  _counts(out, record.fileCounts);
  _drift(out, record.drift);
  _badRecords(out, record.badRecords);
  _knownIds(out, record.knownIds);
  _fieldCheck(out, record.fieldCheck);
  return out.toString();
}

void _counts(StringBuffer out, Map<String, Object?>? counts) {
  if (counts == null) return;
  final total = counts.values.fold<int>(0, (sum, n) => sum + (n as int));
  out.writeln('Records: $total in ${counts.length} files');
  for (final MapEntry(:key, :value) in counts.entries) {
    out.writeln('  $key: $value');
  }
}

void _drift(StringBuffer out, Map<String, Object?>? drift) {
  if (drift == null) return;
  final newFiles = _list(drift['newFiles']);
  final newFields = _list(drift['newFields']);
  final wrongTyped = _list(drift['wrongTyped']);
  final missingFiles = _list(drift['missingFiles']);
  if ([newFiles, newFields, wrongTyped, missingFiles].every((l) => l.isEmpty)) {
    out.writeln('Drift: none');
    return;
  }
  out.writeln('Drift:');
  if (newFiles.isNotEmpty) out.writeln('  new files: ${newFiles.join(', ')}');
  for (final field in newFields) {
    out.writeln('  new field: ${_fieldCount(field)}');
  }
  for (final field in wrongTyped) {
    out.writeln('  wrong type: ${_fieldCount(field)}');
  }
  if (missingFiles.isNotEmpty) {
    out.writeln('  missing files: ${missingFiles.join(', ')}');
  }
}

String _fieldCount(Object? field) => switch (field) {
  {'file': final String file, 'field': final String name, 'records': final n} =>
    '$file $name ($n records)',
  _ => '$field',
};

void _badRecords(StringBuffer out, Map<String, Object?>? bad) {
  if (bad == null) return;
  final total = bad['total'] as int? ?? 0;
  if (total == 0) {
    out.writeln('Bad records: none');
    return;
  }
  out.writeln('Bad records: $total');
  if (bad['files'] case final Map<Object?, Object?> files) {
    for (final MapEntry(:key, :value) in files.entries) {
      final entry = value! as Map<Object?, Object?>;
      out.writeln('  $key: ${entry['count']}');
      for (final record in _list(entry['records']).take(3)) {
        if (record case {'line': final line, 'reason': final reason}) {
          out.writeln('    line $line: $reason');
        }
      }
    }
  }
}

void _knownIds(StringBuffer out, Map<String, Object?>? known) {
  if (known == null) return;
  final findings = _list(known['findings']);
  out.writeln(
    'Known ids: ${known['checked']} checked, '
    '${findings.isEmpty ? 'all found' : '${findings.length} findings'}',
  );
  for (final finding in findings) {
    if (finding case {
      'name': final name,
      'id': final id,
      'expected': final expected,
      'status': final status,
    }) {
      out.writeln('  $name ($id, expected $expected): $status');
    }
  }
}

void _fieldCheck(StringBuffer out, Map<String, Object?>? check) {
  if (check == null) return;
  final fields = _list(check['fields']);
  final missing = [
    for (final field in fields)
      if (field is Map && field['status'] != 'present') field,
  ];
  out.writeln(
    'Field check: ${fields.length - missing.length} of ${fields.length} '
    'fields present',
  );
  for (final field in missing) {
    out.writeln('  missing: ${field['file']} ${field['path']}');
  }
}

List<Object?> _list(Object? value) => value is List<Object?> ? value : const [];

/// The R38 report for [record], in Markdown.
///
/// R38 asks whether a build lacks a field that industry or logistics needs.
/// The report has a title, the build number, the date, a table of every
/// declared field with its file, path, purpose, status and record count, and
/// a one-line verdict. The date is the day the import finished (UTC), the
/// build's own release date not being stored.
///
/// Throws a [FormatException] when [record] has no build number or no field
/// check (an import that did not succeed has none).
String renderR38Report(ImportRecordView record) {
  final build = record.build;
  final check = record.fieldCheck;
  if (build == null || check == null) {
    throw const FormatException(
      'the import record has no build number or field check',
    );
  }
  final date = (record.finishedAt ?? record.startedAt)
      .toUtc()
      .toIso8601String()
      .substring(0, 10);
  final fields = [
    for (final field in _list(check['fields']))
      if (field is Map<Object?, Object?>) field,
  ];
  final missing = [
    for (final field in fields)
      if (field['status'] != 'present') field,
  ];
  final out = StringBuffer()
    ..writeln('# R38: industry and logistics fields in SDE build $build')
    ..writeln()
    ..writeln('- Build: $build')
    ..writeln('- Date: $date')
    ..writeln()
    ..writeln('| File | Field path | Purpose | Status | Records |')
    ..writeln('| --- | --- | --- | --- | ---: |');
  for (final field in fields) {
    out.writeln(
      '| ${_cell(field['file'])} | `${_cell(field['path'])}` '
      '| ${_cell(field['purpose'])} | ${_cell(field['status'])} '
      '| ${_cell(field['records'])} |',
    );
  }
  out
    ..writeln()
    ..writeln(
      missing.isEmpty
          ? 'Verdict: no gap. All ${fields.length} declared fields are '
                'present in build $build.'
          : 'Verdict: gap. ${missing.length} of ${fields.length} declared '
                'fields are missing in build $build: '
                '${missing.map((f) => '${f['file']} ${f['path']}').join(', ')}.',
    );
  return out.toString();
}

String _cell(Object? value) =>
    '$value'.replaceAll('|', r'\|').replaceAll('\n', ' ');
