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
    // per chunk shows each chunk's yield was a real one.
    expect(counter.turns, greaterThanOrEqualTo(searchLines - 1));
  });

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
    final badRecord = Uint8List.fromList(
      utf8.encode(
        '${text.substring(0, newlineAt)}\n'
        '{"section":"types.jsonl"}\n[1,2]\n',
      ),
    );
    expect(
      refused(await chunked(badRecord, fixtureBuild)),
      isA<CorruptBundle>(),
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
