import 'package:kaname_server/src/workers/import_report_summary.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:test/test.dart';

const _clean = DriftReport(
  newFiles: [],
  newFields: [],
  wrongTypedFields: [],
  missingFiles: [],
);

ImportReport _report({
  DriftReport drift = _clean,
  BadRecordsReport badRecords = const BadRecordsReport({}),
  KnownIdsReport knownIds = const KnownIdsReport(checked: 3, findings: []),
  FieldCheckReport fieldCheck = const FieldCheckReport([]),
}) => ImportReport(
  fileCounts: const {'types.jsonl': 1},
  drift: drift,
  badRecords: badRecords,
  knownIds: knownIds,
  fieldCheck: fieldCheck,
);

void main() {
  test('a build that matched everything has no summary', () {
    expect(summarizeImportReport(_report()), isNull);
  });

  test('drift is counted and its new files and fields are named', () {
    final summary = summarizeImportReport(
      _report(
        drift: const DriftReport(
          newFiles: ['shiny.jsonl'],
          newFields: [FieldCount('types.jsonl', 'newThing', 12)],
          wrongTypedFields: [FieldCount('types.jsonl', 'mass', 2)],
          missingFiles: ['old.jsonl', 'older.jsonl'],
        ),
      ),
    )!;

    expect(summary, contains('1 new file (shiny.jsonl)'));
    expect(summary, contains('1 new field (types.jsonl newThing)'));
    expect(summary, contains('1 wrong-typed field'));
    expect(summary, contains('2 known files missing'));
    expect(summary, isNot(contains('\n')));
  });

  test('bad records, known-id findings and missing R38 fields are listed', () {
    final summary = summarizeImportReport(
      _report(
        badRecords: const BadRecordsReport({
          'types.jsonl': FileBadRecords(count: 3, records: []),
        }),
        knownIds: const KnownIdsReport(
          checked: 3,
          findings: [KnownIdFinding(KnownId('Tritanium', 34, IdKind.type), [])],
        ),
        fieldCheck: const FieldCheckReport([
          FieldCheckResult(
            IndustryLogisticsField('types.jsonl', 'volume', 'freight'),
            0,
          ),
          FieldCheckResult(
            IndustryLogisticsField('types.jsonl', 'capacity', 'freight'),
            5,
          ),
        ]),
      ),
    )!;

    expect(summary, contains('3 bad records'));
    expect(
      summary,
      contains('1 known id missing or of another kind (Tritanium)'),
    );
    expect(summary, contains('1 R38 field missing (types.jsonl volume)'));
  });

  test('a long list is cut after five names', () {
    final summary = summarizeImportReport(
      _report(
        drift: DriftReport(
          newFiles: [for (var i = 1; i <= 8; i++) 'f$i.jsonl'],
          newFields: const [],
          wrongTypedFields: const [],
          missingFiles: const [],
        ),
      ),
    )!;

    expect(summary, contains('8 new files (f1.jsonl, f2.jsonl, f3.jsonl, '));
    expect(summary, contains('f5.jsonl, and 3 more)'));
    expect(summary, isNot(contains('f6.jsonl')));
  });
}
