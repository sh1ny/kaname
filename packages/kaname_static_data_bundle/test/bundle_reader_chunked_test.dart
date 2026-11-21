import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';
import 'package:test/test.dart';

import 'support/bundle_fixture.dart';

Uint8List inflatedFixture({int build = fixtureBuild}) => Uint8List.fromList(
  const GZipDecoder().decodeBytes(fixtureBuilder(build: build).build().bytes),
);

ClientBundle opened(BundleOpenResult result) => switch (result) {
  BundleOpened(:final bundle) => bundle,
  BundleRefused(:final refusal) => fail('refused: $refusal'),
};

BundleRefusal refused(BundleOpenResult result) => switch (result) {
  BundleRefused(:final refusal) => refusal,
  BundleOpened() => fail('opened, expected a refusal'),
};

/// Everything a bundle exposes, as plain values that compare with `equals`.
Object? snapshot(ClientBundle bundle) {
  final header = bundle.header;
  return {
    'header': [
      header.formatMajor,
      header.formatMinor,
      header.build,
      header.releaseDate,
      header.locales,
      {
        for (final MapEntry(:key, :value) in header.sections.entries)
          key.file: (value.present, value.records),
      },
    ],
    'types': [
      for (final t in bundle.types)
        [
          t.id,
          t.name.en,
          t.groupId,
          t.published,
          t.volume,
          t.capacity,
          t.portionSize,
          t.mass,
          t.marketGroupId,
          t.metaGroupId,
          t.radius,
          t.factionId,
          t.raceId,
          t.variationParentTypeId,
        ],
    ],
    'groups': [
      for (final g in bundle.groups)
        [g.id, g.name.en, g.categoryId, g.published],
    ],
    'regions': [
      for (final r in bundle.regions) [r.id, r.name.en, r.factionId],
    ],
    'solarSystems': [
      for (final s in bundle.solarSystems)
        [
          s.id,
          s.name.en,
          s.constellationId,
          s.regionId,
          s.securityStatus,
          s.securityClass,
        ],
    ],
    'sections': {
      for (final section in BundleSection.values)
        section.file: [
          for (final r in bundle.records(section)) [r.key, r.typed, r.raw],
        ],
    },
  };
}

/// Counts event-loop turns (zero-length timers) until [stop] is called.
final class TurnCounter {
  int turns = 0;
  bool _running = true;

  TurnCounter() {
    void tick() {
      if (!_running) return;
      turns++;
      Timer.run(tick);
    }

    Timer.run(tick);
  }

  void stop() => _running = false;
}

void main() {
  test('the chunked open gives the same bundle as the one-pass open', () async {
    final inflated = inflatedFixture();

    final onePass = opened(openInflatedBundle(inflated, build: fixtureBuild));
    final chunked = opened(
      await openInflatedBundleChunked(
        inflated,
        build: fixtureBuild,
        linesPerChunk: 1,
      ),
    );

    expect(snapshot(chunked), equals(snapshot(onePass)));
    expect(chunked.types, isNotEmpty);
    expect(chunked.solarSystems, isNotEmpty);
  });

  test('the default chunk size opens the same bundle', () async {
    final inflated = inflatedFixture();

    final chunked = opened(
      await openInflatedBundleChunked(inflated, build: fixtureBuild),
    );

    expect(
      snapshot(chunked),
      equals(
        snapshot(opened(openInflatedBundle(inflated, build: fixtureBuild))),
      ),
    );
  });

  test('the chunked open yields to the event loop between chunks', () async {
    final inflated = inflatedFixture();
    final headerSections = opened(
      openInflatedBundle(inflated, build: fixtureBuild),
    ).header.sections;
    final searchLines = [
      BundleSection.types,
      BundleSection.groups,
      BundleSection.mapRegions,
      BundleSection.mapSolarSystems,
    ].fold<int>(0, (sum, s) => sum + (headerSections[s]?.records ?? 0));
    expect(searchLines, greaterThan(3));
    final counter = TurnCounter();

    await openInflatedBundleChunked(
      inflated,
      build: fixtureBuild,
      linesPerChunk: 1,
    );
    counter.stop();

    // A timer fires only when the open gives up the event loop, so one turn
    // per chunk shows each chunk's yield was a real one. The section scan
    // pauses after each body line; only the search decoding's own pauses,
    // one per search record line, take the count past the body's lines.
    final bodyLines = '\n'.allMatches(utf8.decode(inflated)).length - 1;
    expect(
      counter.turns,
      greaterThanOrEqualTo(bodyLines + searchLines - 1),
      reason: '$bodyLines body lines, $searchLines search lines',
    );
  });

  test(
    'the scan for sections yields too, over lines search never decodes',
    () async {
      // The fixture with a long section this reader passes over: indexing it
      // is most of the open's work, and none of it is search decoding.
      const lazyLines = 1000;
      final inflated = Uint8List.fromList([
        ...inflatedFixture(),
        ...utf8.encode('{"section":"zzUnread.jsonl"}\n'),
        for (var i = 0; i < lazyLines; i++) ...utf8.encode('[$i]\n'),
      ]);
      const linesPerChunk = 50;
      final counter = TurnCounter();

      final chunked = opened(
        await openInflatedBundleChunked(
          inflated,
          build: fixtureBuild,
          linesPerChunk: linesPerChunk,
        ),
      );
      counter.stop();

      expect(
        counter.turns,
        greaterThanOrEqualTo(lazyLines ~/ linesPerChunk - 1),
        reason: 'the index pauses every $linesPerChunk lines',
      );
      expect(
        snapshot(chunked),
        equals(
          snapshot(opened(openInflatedBundle(inflated, build: fixtureBuild))),
        ),
      );
    },
  );

  test('a chunk size larger than the bundle does not yield', () async {
    final counter = TurnCounter();

    await openInflatedBundleChunked(
      inflatedFixture(),
      build: fixtureBuild,
      linesPerChunk: 1000000,
    );
    counter.stop();

    expect(counter.turns, 0);
  });

  test('the chunked open refuses as the one-pass open does', () async {
    Future<BundleOpenResult> chunked(Uint8List inflated, int build) =>
        openInflatedBundleChunked(inflated, build: build, linesPerChunk: 1);

    final other = inflatedFixture(build: fixtureBuild + 1);
    expect(
      refused(await chunked(other, fixtureBuild)),
      isA<WrongBuild>()
          .having((r) => r.expected, 'expected', fixtureBuild)
          .having((r) => r.actual, 'actual', fixtureBuild + 1),
    );

    final text = utf8.decode(inflatedFixture());
    final newlineAt = text.indexOf('\n');
    final header = jsonDecode(text.substring(0, newlineAt)) as Map;
    final newer = Uint8List.fromList(
      utf8.encode(
        '${jsonEncode({...header, 'formatMajor': 2, 'formatMinor': 3})}'
        '${text.substring(newlineAt)}',
      ),
    );
    expect(
      refused(await chunked(newer, fixtureBuild)),
      isA<UnsupportedFormat>()
          .having((r) => r.bundleMajor, 'bundleMajor', 2)
          .having((r) => r.bundleMinor, 'bundleMinor', 3),
    );

    expect(
      refused(await chunked(Uint8List.fromList(utf8.encode('{oops\n')), 1)),
      isA<CorruptBundle>(),
    );
    expect(
      refused(await chunked(Uint8List.fromList(utf8.encode('no header')), 1)),
      isA<CorruptBundle>(),
    );
    // One type record replaced in place, so every section count still
    // matches its header and only the record's shape is wrong.
    final lines = text.substring(0, text.length - 1).split('\n');
    final typesAt = lines.indexOf('{"section":"types"}');
    expect(typesAt, greaterThan(0));
    final badRecord = Uint8List.fromList(
      utf8.encode(
        '${[...lines.take(typesAt + 1), '[1,2]', ...lines.skip(typesAt + 2)].join('\n')}\n',
      ),
    );
    expect(
      refused(await chunked(badRecord, fixtureBuild)),
      isA<CorruptBundle>().having(
        (r) => r.detail,
        'detail',
        allOf(contains('malformed'), contains('section types')),
      ),
    );
  });

  group('a lazy-section record replaced in place', () {
    final text = utf8.decode(inflatedFixture());
    final lines = text.substring(0, text.length - 1).split('\n');
    final dogmaAt = lines.indexOf('{"section":"typeDogma"}');

    Uint8List withDogmaRecord(List<int> record) => Uint8List.fromList([
      ...utf8.encode('${lines.take(dogmaAt + 1).join('\n')}\n'),
      ...record,
      ...utf8.encode('\n${lines.skip(dogmaAt + 2).join('\n')}\n'),
    ]);

    test('keeps every count, so the fixture has such a record', () {
      expect(dogmaAt, greaterThan(0));
      expect(lines[dogmaAt + 1], startsWith('['));
      final same = withDogmaRecord(utf8.encode(lines[dogmaAt + 1]));
      expect(opened(openInflatedBundle(same, build: fixtureBuild)), isNotNull);
      // The cases' starting line opens too, so each refusal is its defect.
      final base = withDogmaRecord(utf8.encode('[1,{},{}]'));
      expect(opened(openInflatedBundle(base, build: fixtureBuild)), isNotNull);
    });

    // Each case starts from a valid raw-carrying line, `[1,{},{}]`, and
    // breaks only what it names (pre-ship round 32).
    for (final (name, record) in [
      ('invalid JSON', utf8.encode('[1,{},{"a":}]')),
      ('a shape other than [key, typed, raw]', utf8.encode('[1,2]')),
      ('a key that is not an integer', utf8.encode('[1.5,{},{}]')),
      ('trailing text', utf8.encode('[1,{},{}] x')),
      ('an unterminated string', utf8.encode('[1,{"a":"b},{}]')),
      ('a bad escape', utf8.encode(r'[1,{"a":"\q"},{}]')),
      // Pre-ship round 31: a raw-carrying section's line has its raw JSON.
      ('null where its raw object belongs', utf8.encode('[1,{},null]')),
      (
        'malformed UTF-8',
        [...utf8.encode('[1,{"a":"'), 0xC3, ...utf8.encode('"},{}]')],
      ),
    ]) {
      test('holding $name is refused by both opens', () async {
        final bytes = withDogmaRecord(record);
        Matcher corrupt() => isA<CorruptBundle>().having(
          (r) => r.detail,
          'detail',
          allOf(contains('malformed'), contains('section typeDogma')),
        );

        expect(
          refused(openInflatedBundle(bytes, build: fixtureBuild)),
          corrupt(),
        );
        expect(
          refused(
            await openInflatedBundleChunked(
              bytes,
              build: fixtureBuild,
              linesPerChunk: 3,
            ),
          ),
          corrupt(),
        );
      });
    }
  });

  test('a search-section key beyond the bundle key range is refused by '
      'both opens', () async {
    final text = utf8.decode(inflatedFixture());
    final lines = text.substring(0, text.length - 1).split('\n');
    final typesAt = lines.indexOf('{"section":"types"}');
    final record = jsonDecode(lines[typesAt + 1]) as List<Object?>;
    // Exact natively, rounded on the web.
    final replaced = jsonEncode([bundleMaxKey + 2, record[1], record[2]]);
    final bytes = Uint8List.fromList(
      utf8.encode(
        '${[...lines.take(typesAt + 1), replaced, ...lines.skip(typesAt + 2)].join('\n')}\n',
      ),
    );
    final corrupt = isA<CorruptBundle>().having(
      (r) => r.detail,
      'detail',
      allOf(contains('malformed'), contains('section types')),
    );

    expect(refused(openInflatedBundle(bytes, build: fixtureBuild)), corrupt);
    expect(
      refused(
        await openInflatedBundleChunked(
          bytes,
          build: fixtureBuild,
          linesPerChunk: 3,
        ),
      ),
      corrupt,
    );
  });

  // Pre-ship round 31: a section that carries no raw JSON writes null.
  test('a raw object in a section that carries none is refused by both '
      'opens', () async {
    final text = utf8.decode(inflatedFixture());
    final lines = text.substring(0, text.length - 1).split('\n');
    final typesAt = lines.indexOf('{"section":"types"}');
    final record = jsonDecode(lines[typesAt + 1]) as List<Object?>;
    expect(record[2], isNull);
    final replaced = jsonEncode([record[0], record[1], <String, Object?>{}]);
    final bytes = Uint8List.fromList(
      utf8.encode(
        '${[...lines.take(typesAt + 1), replaced, ...lines.skip(typesAt + 2)].join('\n')}\n',
      ),
    );
    final corrupt = isA<CorruptBundle>().having(
      (r) => r.detail,
      'detail',
      allOf(contains('malformed'), contains('section types')),
    );

    expect(refused(openInflatedBundle(bytes, build: fixtureBuild)), corrupt);
    expect(
      refused(
        await openInflatedBundleChunked(
          bytes,
          build: fixtureBuild,
          linesPerChunk: 3,
        ),
      ),
      corrupt,
    );
  });

  test('a chunk size below one is rejected', () {
    expect(
      () => openInflatedBundleChunked(
        inflatedFixture(),
        build: fixtureBuild,
        linesPerChunk: 0,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
