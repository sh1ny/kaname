import 'dart:convert';

import 'package:kaname_tools/kaname_tools.dart';
import 'package:test/test.dart';

import 'support/esi_fixtures.dart';

List<String> _refusal(EsiSnapshotLoad load) => switch (load) {
  EsiSnapshotRefused(:final problems) => problems,
  EsiSnapshotLoaded() => fail('expected a refusal, got a loaded snapshot'),
};

void main() {
  test('a snapshot matching its pin loads with the pin and the document', () {
    final load = loadEsiSnapshot(esiRepository());
    expect(
      load,
      isA<EsiSnapshotLoaded>()
          .having((l) => l.pin.date, 'date', esiFixtureDate)
          .having((l) => l.pin.source, 'source', esiFixtureSource)
          .having(
            (l) => l.document,
            'document',
            containsPair('openapi', '3.1.0'),
          ),
    );
  });

  test('the pin round-trips through render and parse', () {
    const pin = EsiPin(
      date: '2030-01-02',
      source: 'https://esi.evetech.net/meta/openapi.json',
      sha256:
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    );
    final (pin: parsed, :problems) = parseEsiPin(pin.render());
    expect(problems, isEmpty);
    expect(parsed?.date, pin.date);
    expect(parsed?.source, pin.source);
    expect(parsed?.sha256, pin.sha256);
  });

  // Scenario: Pin missing a field.
  for (final field in ['date', 'source', 'sha256']) {
    test('a pin without its $field is refused naming the field', () {
      final full = EsiPin(
        date: esiFixtureDate,
        source: esiFixtureSource,
        sha256: esiSha256(esiFixtureText()),
      ).render();
      final pin = full
          .split('\n')
          .where((line) => !line.startsWith('$field:'))
          .join('\n');
      final problems = _refusal(loadEsiSnapshot(esiRepository(pin: pin)));
      expect(problems, ['$esiPinPath lacks its $field']);
    });
  }

  test('a pin field in the wrong form is refused naming the field', () {
    final problems = _refusal(
      loadEsiSnapshot(
        esiRepository(
          pin:
              'date: "2030-1-2"\n'
              'source: "http://example.invalid"\n'
              'sha256: "ABC"\n',
        ),
      ),
    );
    expect(problems, hasLength(3));
    expect(problems[0], contains('invalid date "2030-1-2"'));
    expect(problems[1], contains('invalid source'));
    expect(problems[2], contains('invalid sha256'));
  });

  // Scenario: Pin date edited by hand.
  test('a pin date differing from the snapshot names both dates', () {
    final text = esiFixtureText();
    final problems = _refusal(
      loadEsiSnapshot(
        esiRepository(
          pin: EsiPin(
            date: '2030-01-03',
            source: esiFixtureSource,
            sha256: esiSha256(text),
          ).render(),
        ),
      ),
    );
    expect(problems, [
      "The pin's date 2030-01-03 differs from the snapshot's info.version "
          '2030-01-02',
      "The pin's date 2030-01-03 differs from the snapshot's "
          'X-Compatibility-Date enum 2030-01-02',
    ]);
  });

  test('a header enum differing from the pin is refused on its own', () {
    final document = esiFixture();
    final parameters =
        (document['components']! as Map<String, Object?>)['parameters']!
            as Map<String, Object?>;
    ((parameters['CompatibilityDate']! as Map<String, Object?>)['schema']!
        as Map<String, Object?>)['enum'] = [
      '2030-01-01',
    ];
    final problems = _refusal(
      loadEsiSnapshot(esiRepository(snapshot: jsonEncode(document))),
    );
    expect(problems, [
      "The pin's date 2030-01-02 differs from the snapshot's "
          'X-Compatibility-Date enum 2030-01-01',
    ]);
  });

  test('a header enum holding the pin date and another is refused', () {
    final document = esiFixture();
    final parameters =
        (document['components']! as Map<String, Object?>)['parameters']!
            as Map<String, Object?>;
    ((parameters['CompatibilityDate']! as Map<String, Object?>)['schema']!
        as Map<String, Object?>)['enum'] = [
      esiFixtureDate,
      '2030-01-01',
    ];
    final problems = _refusal(
      loadEsiSnapshot(esiRepository(snapshot: jsonEncode(document))),
    );
    expect(problems, [
      "The pin's date 2030-01-02 differs from the snapshot's "
          'X-Compatibility-Date enum 2030-01-02, 2030-01-01',
    ]);
  });

  test('another header definition naming the pin date does not hide a '
      'mismatch', () {
    final document = esiFixture();
    final parameters =
        (document['components']! as Map<String, Object?>)['parameters']!
            as Map<String, Object?>;
    ((parameters['CompatibilityDate']! as Map<String, Object?>)['schema']!
        as Map<String, Object?>)['enum'] = [
      '2030-01-01',
    ];
    parameters['UnusedCompatibilityDate'] = {
      'in': 'header',
      'name': 'X-Compatibility-Date',
      'required': true,
      'schema': {
        'type': 'string',
        'enum': [esiFixtureDate],
      },
    };
    final problems = _refusal(
      loadEsiSnapshot(esiRepository(snapshot: jsonEncode(document))),
    );
    expect(problems, [
      "The pin's date 2030-01-02 differs from the snapshot's "
          'X-Compatibility-Date enum 2030-01-01',
    ]);
  });

  // Scenario: Snapshot edited by hand.
  test('a changed snapshot byte fails the hash check before parsing', () {
    final text = esiFixtureText();
    final repository = esiRepository()
      // Not even JSON any more: the hash check must refuse it first.
      ..writeFile(esiSnapshotPath, '${text.substring(0, text.length - 2)}X');
    final problems = _refusal(loadEsiSnapshot(repository));
    expect(problems, hasLength(1));
    expect(
      problems.single,
      startsWith("$esiSnapshotPath does not match the pin's hash"),
    );
  });

  test('a byte order mark added to the snapshot fails the hash check', () {
    final repository = esiRepository()
      ..writeFile(esiSnapshotPath, '\uFEFF${esiFixtureText()}');
    expect(
      _refusal(loadEsiSnapshot(repository)).single,
      startsWith("$esiSnapshotPath does not match the pin's hash"),
    );
  });

  test('a missing pin or snapshot is refused naming the file', () {
    final noPin = esiRepository()..deleteFile(esiPinPath);
    expect(_refusal(loadEsiSnapshot(noPin)).single, startsWith(esiPinPath));
    final noSnapshot = esiRepository()..deleteFile(esiSnapshotPath);
    expect(
      _refusal(loadEsiSnapshot(noSnapshot)).single,
      startsWith(esiSnapshotPath),
    );
  });
}
