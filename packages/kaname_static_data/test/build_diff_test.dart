import 'dart:io';

import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Given two builds in the in-memory store', () {
    Future<BuildDiffReport> compare(DiffScenario scenario) async {
      final store = InMemoryStaticDataStore();
      await scenario.seed(store);
      return InMemoryStaticDataDiffer(store)
          .compare(scenario.fromBuild, scenario.toBuild);
    }

    final scenarios = {
      'changed types file reports counts, keys and volume field':
          changedBuildScenario(),
      'more than 1000 changed keys are cut off and marked':
          manyChangesScenario(),
      'a file only in the new build is listed as new with all records added':
          fileOnlyInOneBuildScenario(),
      'key order alone is not a change': keyOrderScenario(),
      'repeated and empty keys are compared as multisets and never changed':
          rawMultisetScenario(),
    };
    for (final MapEntry(:key, :value) in scenarios.entries) {
      test('when compared then $key', () async {
        final report = await compare(value);
        expect(report.toSdeJson().value, value.expectedReport);
      });
    }

    test(
      'when a build is not stored then it throws naming the build',
      () async {
        final store = InMemoryStaticDataStore();
        await seedDiffBuild(
          store,
          100,
          const DiffBuildData(),
          BuildState.active,
        );
        await expectLater(
          InMemoryStaticDataDiffer(store).compare(100, 777),
          throwsA(
            isA<BuildNotStoredException>()
                .having((e) => e.build, 'build', 777)
                .having((e) => '$e', 'message', contains('build not stored'))
                .having((e) => '$e', 'message', contains('777')),
          ),
        );
        await expectLater(
          InMemoryStaticDataDiffer(store).compare(555, 100),
          throwsA(isA<BuildNotStoredException>()),
        );
      },
    );
  });

  group('Given a report', () {
    final report = BuildDiffReport.fromSdeJson(
      SdeJson(rawMultisetScenario().expectedReport),
    );

    test('when it is encoded and decoded then it is unchanged', () {
      final json = report.toSdeJson();
      expect(json.value, rawMultisetScenario().expectedReport);
      expect(BuildDiffReport.fromSdeJson(json).toSdeJson().value, json.value);
    });

    test('when its doc comment is read then it states the C5 rule', () {
      // Guards the carried constraint's destination (design C5).
      final source = File('lib/src/build_diff.dart').readAsStringSync();
      expect(source, contains('classified per record, never per file'));
    });

    Map<String, Object?> validFile() => {
      'file': 'a.jsonl',
      'status': 'both',
      'added': {
        'count': 1,
        'keys': ['1'],
        'truncated': false,
      },
      'removed': {'count': 0, 'keys': <Object?>[], 'truncated': false},
      'changed': {'count': 0, 'keys': <Object?>[], 'truncated': false},
      'changedFields': <String, Object?>{},
    };

    Map<String, Object?> valid({Map<String, Object?>? file}) => {
      'fromBuild': 1,
      'toBuild': 2,
      'files': <Object?>[file ?? validFile()],
    };

    test('when a valid report is decoded then it reads', () {
      expect(
        BuildDiffReport.fromSdeJson(SdeJson(valid())).toSdeJson().value,
        valid(),
      );
    });

    final broken = <String, Map<String, Object?>>{
      'a missing build': {...valid()}..remove('toBuild'),
      'a text build': {...valid(), 'fromBuild': '1'},
      'no files list': {...valid(), 'files': 'x'},
      'an unknown status': valid(file: {...validFile(), 'status': 'odd'}),
      'a negative count': valid(
        file: {
          ...validFile(),
          'added': {'count': -1, 'keys': <Object?>[], 'truncated': false},
        },
      ),
      'more keys than the count': valid(
        file: {
          ...validFile(),
          'added': {
            'count': 1,
            'keys': ['1', '2'],
            'truncated': false,
          },
        },
      ),
      'a key that is not text': valid(
        file: {
          ...validFile(),
          'added': {
            'count': 1,
            'keys': [1],
            'truncated': false,
          },
        },
      ),
      'a missing truncated flag': valid(
        file: {
          ...validFile(),
          'added': {
            'count': 1,
            'keys': ['1'],
          },
        },
      ),
      'a changed field count that is not a number': valid(
        file: {
          ...validFile(),
          'changedFields': {'volume': 'x'},
        },
      ),
    };
    for (final MapEntry(:key, :value) in broken.entries) {
      test('when a report has $key then decoding throws a FormatException', () {
        expect(
          () => BuildDiffReport.fromSdeJson(SdeJson(value)),
          throwsFormatException,
        );
      });
    }
  });
}
