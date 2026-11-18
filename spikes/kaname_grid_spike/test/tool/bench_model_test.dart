import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/bench_model.dart';

void main() {
  group('rows', () {
    test('the matrix is skwasm threaded, skwasm single, CanvasKit', () {
      expect(benchRows.map((r) => r.name), [
        'skwasm-threaded',
        'skwasm-single',
        'canvaskit',
      ]);
      expect(benchRows.map((r) => r.fileStem), [
        'skwasm-multi',
        'skwasm-single',
        'canvaskit-na',
      ]);
      expect(benchRows.map((r) => r.isolation), [true, false, true]);
    });

    test('the page path carries bench, renderer and threads=single only', () {
      final row = selectRows(['skwasm-single']).single;
      expect(
        row.path(smoke: false),
        '/?bench=1&renderer=skwasm&threads=single',
      );
      expect(
        row.path(smoke: true),
        '/?bench=smoke&renderer=skwasm&threads=single',
      );
      // The bootstrap knows only `threads=single`; the other rows send none.
      expect(
        selectRows(['skwasm-threaded']).single.path(smoke: false),
        '/?bench=1&renderer=skwasm',
      );
      expect(
        selectRows(['canvaskit']).single.path(smoke: false),
        '/?bench=1&renderer=canvaskit',
      );
    });

    test('selectRows takes names or file stems and rejects unknown ones', () {
      expect(selectRows([]), benchRows);
      expect(selectRows(['canvaskit-na']).single.name, 'canvaskit');
      expect(() => selectRows(['nope']), throwsArgumentError);
    });
  });

  group('classifyResult', () {
    test('null, empty and "null" are pending', () {
      for (final json in [null, '', 'null']) {
        expect(classifyResult(json), isA<BenchPending>());
      }
    });

    test('schema 1 with a verdict is done', () {
      final poll = classifyResult(
        jsonEncode({
          'schemaVersion': 1,
          'verdict': {'passed': false},
        }),
      );
      expect(poll, isA<BenchDone>());
    });

    test('an abort document is aborted with its reason', () {
      final poll = classifyResult(
        jsonEncode({'schemaVersion': 1, 'aborted': 'no frames'}),
      );
      expect(poll, isA<BenchAborted>());
      expect((poll as BenchAborted).reason, contains('no frames'));
    });

    test('other schema versions, shapes and invalid JSON fail the row', () {
      for (final json in [
        jsonEncode({'schemaVersion': 2, 'verdict': <String, Object?>{}}),
        jsonEncode({'schemaVersion': 1}),
        jsonEncode([1]),
        '{oops',
      ]) {
        expect(classifyResult(json), isA<BenchAborted>(), reason: json);
      }
    });
  });

  test('row and summary files mark failed rows with their reason', () {
    final row = benchRows.first;
    final failed = RowOutcome(
      row: row,
      url: 'http://127.0.0.1:1/',
      smoke: false,
      elapsed: const Duration(seconds: 2),
      failure: 'No result within 600 s.',
    );
    final done = RowOutcome(
      row: benchRows[1],
      url: 'http://127.0.0.1:2/',
      smoke: true,
      elapsed: const Duration(seconds: 3),
      result: {
        'schemaVersion': 1,
        'verdict': {'passed': true},
      },
    );
    expect(failed.toJson()['status'], 'failed');
    expect(failed.toJson()['reason'], 'No result within 600 s.');
    expect(done.toJson()['status'], 'done');
    final rows = summaryJson([failed, done])['rows']! as List<Object?>;
    expect(rows, [
      {
        'row': 'skwasm-threaded',
        'file': 'skwasm-multi.json',
        'status': 'failed',
        'reason': 'No result within 600 s.',
        'smoke': false,
        'verdictPassed': null,
      },
      {
        'row': 'skwasm-single',
        'file': 'skwasm-single.json',
        'status': 'done',
        'reason': null,
        'smoke': true,
        'verdictPassed': true,
      },
    ]);
  });
}
