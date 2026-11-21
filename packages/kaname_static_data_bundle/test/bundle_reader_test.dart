import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';
import 'package:test/test.dart';

import 'support/bundle_fixture.dart';

/// The fixture's bundle with its header replaced by [edit]'s result and
/// [extraLines] appended, re-gzip'd.
Uint8List editedBundle(
  Map<String, Object?> Function(Map<String, Object?> header) edit, {
  List<String> extraLines = const [],
}) {
  final text = utf8.decode(
    const GZipDecoder().decodeBytes(fixtureBuilder().build().bytes),
  );
  final lines = text.substring(0, text.length - 1).split('\n');
  final header = jsonDecode(lines.first) as Map<String, Object?>;
  final edited = [jsonEncode(edit(header)), ...lines.skip(1), ...extraLines];
  return const GZipEncoder().encodeBytes(utf8.encode('${edited.join('\n')}\n'));
}

/// The fixture bundle's lines after [edit] rewrote its record lines (the
/// header kept as built), re-gzip'd.
Uint8List editedBody(List<String> Function(List<String> body) edit) {
  final text = utf8.decode(
    const GZipDecoder().decodeBytes(fixtureBuilder().build().bytes),
  );
  final lines = text.substring(0, text.length - 1).split('\n');
  final edited = [lines.first, ...edit(lines.skip(1).toList())];
  return const GZipEncoder().encodeBytes(utf8.encode('${edited.join('\n')}\n'));
}

/// [body] without the marker and record lines of section [file].
List<String> withoutSection(List<String> body, String file) {
  final start = body.indexOf('{"section":"$file"}');
  if (start < 0) fail('no section $file');
  var end = start + 1;
  while (end < body.length && !body[end].startsWith('{')) {
    end++;
  }
  return [...body.take(start), ...body.skip(end)];
}

/// The opened bundle of [result], failing the test when it was refused.
ClientBundle opened(BundleOpenResult result) => switch (result) {
  BundleOpened(:final bundle) => bundle,
  BundleRefused(:final refusal) => fail('refused: $refusal'),
};

/// The refusal of [result], failing the test when it was opened.
BundleRefusal refused(BundleOpenResult result) => switch (result) {
  BundleRefused(:final refusal) => refusal,
  BundleOpened() => fail('opened, expected a refusal'),
};

void main() {
  late BuiltBundle built;

  setUp(() => built = fixtureBuilder().build());

  test('valid bundle returns types, systems and dogma', () {
    final bundle = opened(
      openBundle(built.bytes, build: fixtureBuild, sha256: built.sha256),
    );

    final header = bundle.header;
    expect(header.formatMajor, 1);
    expect(header.formatMinor, 0);
    expect(header.build, fixtureBuild);
    expect(header.releaseDate, fixtureReleaseDate);
    expect(header.locales, ['en']);
    expect(header.sections, hasLength(17));
    expect(header.sections[BundleSection.dbuffCollections]?.records, 3);

    expect([for (final type in bundle.types) type.id], [587, 34562]);
    final rifter = bundle.types.first;
    expect(rifter.name.en, 'Rifter');
    expect(rifter.groupId, 25);
    expect(rifter.published, isTrue);
    expect(rifter.mass, 1067000.0);
    expect(rifter.radius, 31.0);
    expect(rifter.factionId, 500002);
    expect(rifter.raceId, 2);
    expect(rifter.variationParentTypeId, 586);
    expect(bundle.types.last.name.en, isNull);
    expect(bundle.types.last.published, isFalse);

    expect(bundle.groups.single.name.en, 'Frigate');
    expect(bundle.regions.single.name.en, 'The Forge');
    final jita = bundle.solarSystems.single;
    expect(jita.id, 30000142);
    expect(jita.name.en, 'Jita');
    expect(jita.regionId, 10000002);
    expect(jita.securityStatus, 0.9459);
    expect(jita.securityClass, 'B');

    final dogma = bundle.records(BundleSection.typeDogma).single;
    expect(dogma.key, 587);
    expect(dogma.raw?['dogmaAttributes'], [
      {'attributeID': 4, 'value': 1067000},
    ]);
    final attribute = bundle.records(BundleSection.dogmaAttributes).single;
    expect(attribute.typed['displayName'], {'en': 'Mass'});
    expect(
      [
        for (final record in bundle.records(BundleSection.dbuffCollections))
          (record.key, record.raw?['aggregateMode']),
      ],
      [(2, 'Min'), (10, 'Min'), (10, 'Max')],
    );
  });

  // Pre-ship round 35: a negative minor would define no section at all.
  test('a negative minor with no sections and no body is refused', () {
    final text = utf8.decode(
      const GZipDecoder().decodeBytes(fixtureBuilder().build().bytes),
    );
    final header = jsonDecode(text.substring(0, text.indexOf('\n'))) as Map;
    final bytes = const GZipEncoder().encodeBytes(
      utf8.encode(
        '${jsonEncode({...header, 'formatMinor': -1, 'sections': <Object?>[]})}\n',
      ),
    );

    expect(
      refused(
        openBundle(bytes, build: fixtureBuild, sha256: bundleSha256(bytes)),
      ),
      isA<CorruptBundle>().having(
        (r) => r.detail,
        'detail',
        contains('formatMinor'),
      ),
    );
  });

  // Pre-ship round 36: a second entry must not replace the first.
  test('a header that lists a known section twice is refused', () {
    final bytes = editedBundle((header) {
      final sections = header['sections']! as List<Object?>;
      final types = sections.firstWhere(
        (entry) => entry is Map && entry['file'] == 'types',
      );
      return {
        ...header,
        'sections': [
          {'file': 'types', 'present': false, 'records': 0},
          ...sections.where((entry) => entry != types),
          types,
        ],
      };
    });

    expect(
      refused(
        openBundle(bytes, build: fixtureBuild, sha256: bundleSha256(bytes)),
      ),
      isA<CorruptBundle>().having((r) => r.detail, 'detail', contains('types')),
    );
  });

  test('newer major is refused naming both versions', () {
    final bytes = editedBundle(
      (header) => {...header, 'formatMajor': 2, 'formatMinor': 3},
    );

    final refusal = refused(
      openBundle(bytes, build: fixtureBuild, sha256: bundleSha256(bytes)),
    );

    expect(
      refusal,
      isA<UnsupportedFormat>()
          .having((r) => r.bundleMajor, 'bundleMajor', 2)
          .having((r) => r.supportedMajor, 'supportedMajor', 1),
    );
    expect(refusal.reason, 'unsupported bundle format');
    expect(refusal.message, allOf(contains('2.3'), contains('format 1')));
  });

  test('matching hash with another build is refused as wrong build', () {
    final other = fixtureBuilder(build: fixtureBuild + 1).build();

    final refusal = refused(
      openBundle(other.bytes, build: fixtureBuild, sha256: other.sha256),
    );

    expect(
      refusal,
      isA<WrongBuild>()
          .having((r) => r.expected, 'expected', fixtureBuild)
          .having((r) => r.actual, 'actual', fixtureBuild + 1),
    );
    expect(refusal.reason, 'wrong build');
    expect(
      refusal.message,
      allOf(contains('$fixtureBuild'), contains('${fixtureBuild + 1}')),
    );
  });

  test('hash mismatch is refused', () {
    final other = fixtureBuilder(withDynamicItemAttributes: false).build();

    final refusal = refused(
      openBundle(built.bytes, build: fixtureBuild, sha256: other.sha256),
    );

    expect(
      refusal,
      isA<HashMismatch>()
          .having((r) => r.expected, 'expected', other.sha256)
          .having((r) => r.actual, 'actual', built.sha256),
    );
    expect(refusal.reason, 'hash mismatch');
  });

  test('a newer minor with unknown header keys and sections is read', () {
    final bytes = editedBundle(
      (header) => {
        ...header,
        'formatMinor': 7,
        'futureKey': {'any': 'thing'},
        'sections': [
          ...header['sections']! as List<Object?>,
          {'file': 'futureFile', 'present': true, 'records': 1},
        ],
      },
      extraLines: ['{"section":"futureFile"}', '[1,{"x":1},null]'],
    );

    final bundle = opened(
      openBundle(bytes, build: fixtureBuild, sha256: bundleSha256(bytes)),
    );

    expect(bundle.header.formatMinor, 7);
    expect(bundle.header.sections, hasLength(17));
    expect(bundle.types, hasLength(2));
    expect(
      bundle.records(BundleSection.fighterAbilitiesByType).single.key,
      23055,
    );
  });

  test('an absent section has no records', () {
    final other = fixtureBuilder(withDynamicItemAttributes: false).build();
    final bundle = opened(
      openBundle(other.bytes, build: fixtureBuild, sha256: other.sha256),
    );

    expect(
      bundle.header.sections[BundleSection.dynamicItemAttributes]?.present,
      isFalse,
    );
    expect(bundle.records(BundleSection.dynamicItemAttributes), isEmpty);
  });

  test('bytes that are not a bundle are refused as corrupt', () {
    final notGzip = Uint8List.fromList(utf8.encode('not a bundle'));
    final notJson = const GZipEncoder().encodeBytes(utf8.encode('{oops\n'));

    expect(
      refused(
        openBundle(notGzip, build: fixtureBuild, sha256: bundleSha256(notGzip)),
      ),
      isA<CorruptBundle>(),
    );
    expect(
      refused(
        openBundle(notJson, build: fixtureBuild, sha256: bundleSha256(notJson)),
      ),
      isA<CorruptBundle>(),
    );
  });

  group('a body that does not match its header is refused as corrupt', () {
    BundleRefusal refusalOf(Uint8List bytes) => refused(
      openBundle(bytes, build: fixtureBuild, sha256: bundleSha256(bytes)),
    );

    test('a present section left out', () {
      final bytes = editedBody((body) => withoutSection(body, 'types'));

      expect(
        refusalOf(bytes),
        isA<CorruptBundle>().having(
          (r) => r.detail,
          'detail',
          contains('types'),
        ),
      );
    });

    test('a present section with fewer records than the header counts', () {
      final bytes = editedBody((body) {
        final marker = body.indexOf('{"section":"types"}');
        return [...body.take(marker + 1), ...body.skip(marker + 2)];
      });

      expect(
        refusalOf(bytes),
        isA<CorruptBundle>().having(
          (r) => r.detail,
          'detail',
          contains('types'),
        ),
      );
    });

    test('records in a section the header names absent', () {
      final bytes = editedBundle(
        (header) => {
          ...header,
          'sections': [
            for (final entry in header['sections']! as List<Object?>)
              switch (entry) {
                {'file': 'types'} => {
                  'file': 'types',
                  'present': false,
                  'records': 0,
                },
                _ => entry,
              },
          ],
        },
      );

      expect(refusalOf(bytes), isA<CorruptBundle>());
    });

    // The fixture with [file]'s body lines left out and its header entry
    // replaced.
    Uint8List withEntry(
      String file, {
      required bool present,
      required int records,
    }) {
      final text = utf8.decode(
        const GZipDecoder().decodeBytes(fixtureBuilder().build().bytes),
      );
      final lines = text.substring(0, text.length - 1).split('\n');
      final header = jsonDecode(lines.first) as Map<String, Object?>;
      final edited = {
        ...header,
        'sections': [
          for (final entry in header['sections']! as List<Object?>)
            switch (entry) {
              {'file': final String name} when name == file => {
                'file': file,
                'present': present,
                'records': records,
              },
              _ => entry,
            },
        ],
      };
      final body = withoutSection(lines.skip(1).toList(), file);
      return const GZipEncoder().encodeBytes(
        utf8.encode('${[jsonEncode(edited), ...body].join('\n')}\n'),
      );
    }

    test('an absent section whose header counts records', () {
      final bytes = withEntry(
        'dynamicItemAttributes',
        present: false,
        records: 3,
      );

      expect(refusalOf(bytes), isA<CorruptBundle>());
    });

    test('a present section whose header counts no records', () {
      final bytes = withEntry(
        'dynamicItemAttributes',
        present: true,
        records: 0,
      );

      expect(refusalOf(bytes), isA<CorruptBundle>());
    });

    // Pre-ship round 34: a header lists the sections its own minor
    // defines, so a reader that knows a later section still opens it.
    test('every known section belongs to format 1.0, and a section added in '
        'a later minor is not required of an older bundle', () {
      for (final section in BundleSection.values) {
        expect(section.sinceMinor, 0, reason: section.file);
        expect(section.isDefinedIn(0), isTrue, reason: section.file);
      }
      expect(sectionDefinedIn(sinceMinor: 1, formatMinor: 0), isFalse);
      expect(sectionDefinedIn(sinceMinor: 1, formatMinor: 1), isTrue);
      expect(sectionDefinedIn(sinceMinor: 1, formatMinor: 2), isTrue);
    });

    // Pre-ship round 33: format 1.0 lists every section it defines.
    for (final file in ['types', 'mapSolarSystems', 'dynamicItemAttributes']) {
      test('a header and body that both leave out the $file section', () {
        final text = utf8.decode(
          const GZipDecoder().decodeBytes(fixtureBuilder().build().bytes),
        );
        final lines = text.substring(0, text.length - 1).split('\n');
        final header = jsonDecode(lines.first) as Map<String, Object?>;
        final edited = {
          ...header,
          'sections': [
            for (final entry in header['sections']! as List<Object?>)
              if (entry case {'file': final String name} when name != file)
                entry,
          ],
        };
        final body = withoutSection(lines.skip(1).toList(), file);
        final bytes = const GZipEncoder().encodeBytes(
          utf8.encode('${[jsonEncode(edited), ...body].join('\n')}\n'),
        );

        expect(
          refusalOf(bytes),
          isA<CorruptBundle>().having(
            (r) => r.detail,
            'detail',
            contains('no entry for section $file'),
          ),
        );
      });
    }

    // Pre-ship round 29.
    test('an absent section whose header counts a negative number of '
        'records', () {
      final bytes = withEntry(
        'dynamicItemAttributes',
        present: false,
        records: -1,
      );

      expect(
        refusalOf(bytes),
        isA<CorruptBundle>().having(
          (r) => r.detail,
          'detail',
          contains('dynamicItemAttributes'),
        ),
      );
    });

    test('a record line before the first section marker', () {
      final bytes = editedBody((body) => ['[99,{},null]', ...body]);

      expect(
        refusalOf(bytes),
        isA<CorruptBundle>().having(
          (r) => r.detail,
          'detail',
          contains('before the first section'),
        ),
      );
    });

    test('a section that appears twice', () {
      final bytes = editedBody(
        (body) => [...body, '{"section":"types"}', '[99,{},null]'],
      );

      expect(refusalOf(bytes), isA<CorruptBundle>());
    });

    test('the chunked open refuses the same bundle', () async {
      final bytes = editedBody((body) => withoutSection(body, 'types'));
      final inflated = const GZipDecoder().decodeBytes(bytes);

      expect(
        refused(await openInflatedBundleChunked(inflated, build: fixtureBuild)),
        isA<CorruptBundle>(),
      );
    });
  });

  test('an inflated bundle whose hash the caller checked opens', () {
    final inflated = const GZipDecoder().decodeBytes(built.bytes);

    final bundle = opened(openInflatedBundle(inflated, build: fixtureBuild));

    expect(bundle.solarSystems.single.name.en, 'Jita');
  });
}
