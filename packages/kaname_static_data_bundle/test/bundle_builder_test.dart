import 'dart:convert';

import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';
import 'package:test/test.dart';

import 'support/bundle_fixture.dart';

/// The SHA-256 of the fixture's bundle, pinned on the Dart VM (A1).
///
/// A change of this value means the bytes changed: either the format, the
/// builder or a locked dependency (`package:archive`'s deflate) did. A
/// dependency upgrade may change it with no format bump (design A1).
const pinnedFixtureSha256 =
    '43efba67d4328bff51110fc7b7f87cd022960c3c97d318564e8e54a8fca8c6ac';

void main() {
  group('bundle builder', () {
    test('build with every file holds 17 sections, typed columns, radius, '
        'faction, race and variation parent', () {
      final built = fixtureBuilder().build();
      final header = bundleLines(built.bytes).first! as Map<String, Object?>;

      expect(header['formatMajor'], 1);
      expect(header['formatMinor'], 0);
      expect(header['build'], fixtureBuild);
      expect(header['releaseDate'], fixtureReleaseDate);
      expect(header['locales'], ['en']);
      final sections = header['sections']! as List<Object?>;
      expect(sections, hasLength(17));
      expect(
        [for (final section in sections) (section! as Map)['file']],
        [for (final section in BundleSection.values) section.file],
      );
      expect(sections, everyElement(containsPair('present', true)));
      expect(sections[2], {'file': 'types', 'present': true, 'records': 2});
      expect(sections[13], {
        'file': 'dbuffCollections',
        'present': true,
        'records': 3,
      });
      expect(built.records[BundleSection.types], 2);
      expect(built.buildNumber, fixtureBuild);

      final rifter = sectionLines(
        built.bytes,
        BundleSection.types,
      ).singleWhere((line) => line[0] == 587);
      expect(rifter, [
        587,
        {
          'capacity': 140,
          'factionID': 500002,
          'groupID': 25,
          'marketGroupID': 64,
          'mass': 1067000,
          'metaGroupID': 1,
          'name': {'en': 'Rifter'},
          'portionSize': 1,
          'published': true,
          'raceID': 2,
          'radius': 31,
          'variationParentTypeID': 586,
          'volume': 27289,
        },
        null,
      ]);
      expect((rifter[1]! as Map).containsKey('description'), isFalse);

      // Dogma and raw-only sections keep the record's full JSON.
      final dogma = sectionLines(built.bytes, BundleSection.typeDogma).single;
      expect(dogma[0], 587);
      expect(dogma[1], <String, Object?>{});
      expect(dogma[2], containsPair('dogmaAttributes', isNotEmpty));
      final unit = sectionLines(built.bytes, BundleSection.dogmaUnits).single;
      expect(unit[2], containsPair('displayName', {'en': 'kg'}));
      // Other typed sections carry no raw JSON.
      final jita = sectionLines(
        built.bytes,
        BundleSection.mapSolarSystems,
      ).single;
      expect(jita[1], containsPair('securityClass', 'B'));
      expect(jita[2], isNull);
    });

    test('missing optional file is a section marked absent', () {
      final built = fixtureBuilder(withDynamicItemAttributes: false).build();
      final lines = bundleLines(built.bytes);
      final sections =
          (lines.first! as Map<String, Object?>)['sections']! as List<Object?>;

      expect(sections, hasLength(17));
      for (final section in sections.cast<Map<String, Object?>>()) {
        if (section['file'] == 'dynamicItemAttributes') {
          expect(section, {
            'file': 'dynamicItemAttributes',
            'present': false,
            'records': 0,
          });
        } else {
          expect(section['present'], isTrue, reason: '${section['file']}');
        }
      }
      expect(lines, isNot(contains({'section': 'dynamicItemAttributes'})));
      expect(built.records[BundleSection.dynamicItemAttributes], 0);
    });

    test('names keep only en', () {
      final built = fixtureBuilder().build();
      final rifter = sectionLines(
        built.bytes,
        BundleSection.types,
      ).singleWhere((line) => line[0] == 587);
      final groups = sectionLines(built.bytes, BundleSection.groups);

      expect((rifter[1]! as Map)['name'], {'en': 'Rifter'});
      expect((groups.single[1]! as Map)['name'], {'en': 'Frigate'});
    });

    test('record without en name is kept', () {
      final built = fixtureBuilder().build();
      final types = sectionLines(built.bytes, BundleSection.types);

      expect([for (final line in types) line[0]], [587, 34562]);
      expect((types.last[1]! as Map)['name'], <String, Object?>{});
    });

    test('records are written in key order, raw duplicates by line', () {
      final built = fixtureBuilder().build();
      final buffs = sectionLines(built.bytes, BundleSection.dbuffCollections);

      expect([for (final line in buffs) line[0]], [2, 10, 10]);
      expect(
        [for (final line in buffs) (line[2]! as Map)['aggregateMode']],
        ['Min', 'Min', 'Max'],
      );
    });

    test('a raw section with a non-integer key fails the build (A2)', () {
      final builder = fixtureBuilder();

      expect(
        () => builder.addRaw(
          BundleSection.fighterAbilities,
          const RawRecord(key: 'abc', line: 2, record: {'_key': 'abc'}),
        ),
        throwsA(
          isA<BundleBuildException>()
              .having(
                (e) => e.section,
                'section',
                BundleSection.fighterAbilities,
              )
              .having((e) => e.message, 'message', contains('abc')),
        ),
      );
    });

    test('a key at the bundle key bound builds and reopens; one past it '
        'fails the build, typed and raw alike', () {
      for (final key in [bundleMaxKey, -bundleMaxKey]) {
        final builder = fixtureBuilder()
          ..addTyped(
            BundleSection.typeDogma,
            TypedRecord(key: key, values: const {}, raw: {'_key': key}),
          )
          ..addRaw(
            BundleSection.fighterAbilities,
            RawRecord(key: '$key', line: 99, record: {'_key': key}),
          );
        final built = builder.build();

        final bundle = switch (openBundle(
          built.bytes,
          build: fixtureBuild,
          sha256: built.sha256,
        )) {
          BundleOpened(:final bundle) => bundle,
          BundleRefused(:final refusal) => fail('refused: $refusal'),
        };
        expect(
          bundle.records(BundleSection.typeDogma).map((r) => r.key),
          contains(key),
        );
        expect(
          bundle.records(BundleSection.fighterAbilities).map((r) => r.key),
          contains(key),
        );
      }
      for (final key in [bundleMaxKey + 1, -bundleMaxKey - 1]) {
        expect(
          () => fixtureBuilder().addTyped(
            BundleSection.typeDogma,
            TypedRecord(key: key, values: const {}, raw: {'_key': key}),
          ),
          throwsA(
            isA<BundleBuildException>().having(
              (e) => e.message,
              'message',
              contains('$key'),
            ),
          ),
        );
        expect(
          () => fixtureBuilder().addRaw(
            BundleSection.fighterAbilities,
            RawRecord(key: '$key', line: 1, record: {'_key': key}),
          ),
          throwsA(isA<BundleBuildException>()),
        );
      }
    });

    test('typed input is refused when it does not fit the section', () {
      final builder = fixtureBuilder();

      expect(
        () => builder.addTyped(
          BundleSection.types,
          const TypedRecord(key: 1, values: {'unknown': 1}, raw: {}),
        ),
        throwsA(isA<BundleBuildException>()),
      );
      expect(
        () => builder.addTyped(
          BundleSection.types,
          const TypedRecord(key: 2, values: {'groupId': 'x'}, raw: {}),
        ),
        throwsA(isA<BundleBuildException>()),
      );
      expect(
        () => builder.addTyped(
          BundleSection.types,
          const TypedRecord(key: 587, values: {}, raw: {}),
        ),
        throwsA(isA<BundleBuildException>()),
      );
      expect(
        () => builder.addRaw(
          BundleSection.types,
          const RawRecord(key: '1', line: 1, record: {}),
        ),
        throwsA(isA<BundleBuildException>()),
      );
      expect(
        () => builder.addTyped(
          BundleSection.dbuffCollections,
          const TypedRecord(key: 1, values: {}, raw: {}),
        ),
        throwsA(isA<BundleBuildException>()),
      );
    });

    test('the same records give the same bytes and the pinned SHA-256', () {
      final first = fixtureBuilder().build();
      final second = fixtureBuilder().build();

      expect(second.bytes, first.bytes);
      expect(first.sha256, bundleSha256(first.bytes));
      expect(first.sha256, pinnedFixtureSha256);
    });

    test(
      'records decoded from jsonb and from text give the same bytes (A6)',
      () {
        // As the zip's text has them: an exponent, integral floats and a
        // duplicate key.
        const text =
            '{"_key":5,"a":1e2,"b":1.0,"c":2.5e0,"k":1,"k":2,'
            '"nested":{"x":3.0E1,"y":[1e0,0.5]}}';
        // As Postgres jsonb returns the same record: numeric values rewritten,
        // the last duplicate kept, keys in jsonb's own order.
        const jsonb =
            '{"a": 100, "b": 1.0, "c": 2.5, "k": 2, "_key": 5, '
            '"nested": {"x": 30, "y": [1, 0.5]}}';

        List<int> build(String line) {
          final record = jsonDecode(line) as Map<String, Object?>;
          final builder = BundleBuilder(buildNumber: 1, releaseDate: null)
            ..addTyped(
              BundleSection.typeDogma,
              TypedRecord(key: 5, values: const {}, raw: record),
            )
            ..addRaw(
              BundleSection.dbuffCollections,
              RawRecord(key: '5', line: 1, record: record),
            )
            ..addTyped(
              BundleSection.types,
              TypedRecord(
                key: 5,
                values: const {'volume': 100.0, 'mass': 2.5},
                raw: {...record, 'radius': record['a']},
              ),
            );
          return builder.build().bytes;
        }

        expect(build(jsonb), build(text));
      },
    );
  });

  group('release date', () {
    test('comes from the first object whose build number equals the build', () {
      final objects = [
        {'_key': 'sde', 'releaseDate': 'no build number'},
        {'_key': 'sde', 'buildNumber': 41, 'releaseDate': 'other build'},
        jsonDecode('{"buildNumber": 42e0, "releaseDate": "A"}')
            as Map<String, Object?>,
        {'buildNumber': 42, 'releaseDate': 'B'},
      ];

      expect(selectReleaseDate(42, objects), 'A');
    });

    test('is null when the matching object has none or nothing matches', () {
      expect(
        selectReleaseDate(42, [
          {'buildNumber': 42.0},
          {'buildNumber': 42, 'releaseDate': 'later'},
        ]),
        isNull,
      );
      expect(
        selectReleaseDate(42, [
          {'buildNumber': '42', 'releaseDate': 'text build number'},
        ]),
        isNull,
      );
      expect(selectReleaseDate(42, const []), isNull);
    });
  });
}
