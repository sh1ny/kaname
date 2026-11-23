import 'dart:convert';
import 'dart:io';

import 'package:kaname_tools/kaname_tools.dart';

import 'in_memory_file_system.dart';

/// The Kaname-written OpenAPI fixture's text, as stored.
String esiFixtureText() =>
    File('test/fixtures/esi/minimal_openapi.json').readAsStringSync();

/// A fresh decoded copy of the fixture, safe to change.
Map<String, Object?> esiFixture() =>
    jsonDecode(esiFixtureText()) as Map<String, Object?>;

/// The fixture's compatibility date.
const String esiFixtureDate = '2030-01-02';

/// The source URL the fixture pins record.
const String esiFixtureSource =
    'https://esi.example.invalid/meta/openapi.json?compatibility_date=2030-01-02';

/// A repository holding [snapshot] (the fixture by default) and a pin that
/// matches it, unless [pin] replaces the pin text.
InMemoryFileSystem esiRepository({String? snapshot, String? pin}) {
  final text = snapshot ?? esiFixtureText();
  return InMemoryFileSystem()
    ..writeFile(esiSnapshotPath, text)
    ..writeFile(
      esiPinPath,
      pin ??
          EsiPin(
            date: esiFixtureDate,
            source: esiFixtureSource,
            sha256: esiSha256(text),
          ).render(),
    );
}
