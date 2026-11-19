import 'package:kaname_server/src/static_data/import_record_view.dart';
import 'package:kaname_server/src/static_data/sde_import_render.dart';
import 'package:test/test.dart';

Map<String, Object?> _check(List<(String, String, int)> fields) => {
  'complete': fields.every((f) => f.$3 > 0),
  'fields': [
    for (final (file, path, records) in fields)
      {
        'file': file,
        'path': path,
        'purpose': 'M18 | build planner',
        'status': records > 0 ? 'present' : 'missing',
        'records': records,
      },
  ],
};

ImportRecordView _record({
  Map<String, Object?>? fieldCheck,
  int? build = 3714173,
  String outcome = 'succeeded',
}) => ImportRecordView(
  build: build,
  source: 'local',
  startedAt: DateTime.utc(2026, 11, 19, 1, 2),
  finishedAt: DateTime.utc(2026, 11, 19, 1, 3),
  outcome: outcome,
  fileCounts: {'types.jsonl': 3, 'groups.jsonl': 2},
  drift: {
    'newFiles': ['x.jsonl'],
    'newFields': [
      {'file': 'types.jsonl', 'field': 'foo', 'records': 3},
    ],
    'wrongTyped': <Object?>[],
    'missingFiles': <Object?>[],
  },
  badRecords: {
    'total': 1,
    'files': {
      'types.jsonl': {
        'count': 1,
        'records': [
          {'line': 7, 'reason': 'invalid JSON'},
        ],
      },
    },
  },
  knownIds: {
    'checked': 4,
    'passed': false,
    'findings': [
      {
        'name': 'Tritanium',
        'id': 34,
        'expected': 'type',
        'status': 'missing',
        'foundAs': <Object?>[],
      },
    ],
  },
  fieldCheck: fieldCheck,
);

void main() {
  group('renderR38Report', () {
    test('lists every field and says no gap when all are present', () {
      final report = renderR38Report(
        _record(
          fieldCheck: _check([
            ('types.jsonl', 'volume', 10),
            ('blueprints.jsonl', 'activities.manufacturing.materials[]', 4),
          ]),
        ),
      );

      expect(
        report,
        startsWith('# R38: industry and logistics fields in SDE build '),
      );
      expect(report, contains('- Build: 3714173'));
      expect(report, contains('- Date: 2026-11-19'));
      expect(
        report,
        contains('| File | Field path | Purpose | Status | Records |'),
      );
      expect(
        report,
        contains(
          r'| types.jsonl | `volume` | M18 \| build planner | present | 10 |',
        ),
      );
      expect(report, contains('activities.manufacturing.materials[]'));
      expect(report, contains('Verdict: no gap.'));
      expect(report, isNot(contains('Verdict: gap')));
    });

    test('names the missing fields in a gap verdict', () {
      final report = renderR38Report(
        _record(
          fieldCheck: _check([
            ('types.jsonl', 'volume', 10),
            ('types.jsonl', 'capacity', 0),
          ]),
        ),
      );

      expect(report, contains('| missing | 0 |'));
      expect(
        report,
        contains('Verdict: gap. 1 of 2 declared fields are missing'),
      );
      expect(report, contains('types.jsonl capacity'));
    });

    test('a record without a field check or build has no report', () {
      expect(() => renderR38Report(_record()), throwsFormatException);
      expect(
        () => renderR38Report(_record(build: null, fieldCheck: _check([]))),
        throwsFormatException,
      );
    });
  });

  group('renderImportSummary', () {
    test('shows build, source, outcome, reason, counts and every report', () {
      final text = renderImportSummary(
        _record(fieldCheck: _check([('types.jsonl', 'volume', 0)])),
      );

      expect(text, contains('build:    3714173'));
      expect(text, contains('source:   local'));
      expect(text, contains('outcome:  succeeded'));
      expect(text, contains('reason:   -'));
      expect(text, contains('Records: 5 in 2 files'));
      expect(text, contains('new files: x.jsonl'));
      expect(text, contains('new field: types.jsonl foo (3 records)'));
      expect(text, contains('line 7: invalid JSON'));
      expect(text, contains('Tritanium (34, expected type): missing'));
      expect(text, contains('Field check: 0 of 1 fields present'));
      expect(text, contains('missing: types.jsonl volume'));
    });

    test('a record that never succeeded shows only its header', () {
      final text = renderImportSummary(
        ImportRecordView(
          source: 'ccp',
          startedAt: _t,
          outcome: 'failed',
          failureReason: 'CCP unreachable',
        ),
      );

      expect(text, contains('outcome:  failed'));
      expect(text, contains('reason:   CCP unreachable'));
      expect(text, contains('build:    unknown'));
      expect(text, isNot(contains('Drift')));
    });
  });
}

final _t = DateTime.utc(2026);
