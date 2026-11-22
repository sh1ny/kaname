import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';

/// The build number of the fixture.
const int fixtureBuild = 3714173;

/// The release date of the fixture build.
const String fixtureReleaseDate = '2026-11-18T11:00:00Z';

/// A builder fed one small build with records in every one of the 17
/// sections, added out of key order.
///
/// Without [withDynamicItemAttributes] the build has no
/// `dynamicItemAttributes` file. [build] overrides the build number.
BundleBuilder fixtureBuilder({
  bool withDynamicItemAttributes = true,
  int build = fixtureBuild,
}) {
  final builder = BundleBuilder(
    buildNumber: build,
    releaseDate: fixtureReleaseDate,
  );
  void typed(BundleSection section, String line, Map<String, Object?> values) {
    final raw = jsonDecode(line) as Map<String, Object?>;
    builder.addTyped(
      section,
      TypedRecord(key: raw['_key']! as int, values: values, raw: raw),
    );
  }

  void raw(BundleSection section, int line, String text) {
    final record = jsonDecode(text) as Map<String, Object?>;
    builder.addRaw(
      section,
      RawRecord(key: '${record['_key']}', line: line, record: record),
    );
  }

  typed(
    BundleSection.categories,
    '{"_key":6,"name":{"de":"Schiff","en":"Ship"},"published":true,'
    '"iconID":0}',
    {'name': 'Ship', 'published': true, 'iconId': 0},
  );
  typed(
    BundleSection.groups,
    '{"_key":25,"categoryID":6,"name":{"de":"Fregatte","en":"Frigate"},'
    '"published":true,"anchorable":false}',
    {'categoryId': 6, 'name': 'Frigate', 'published': true},
  );
  // A type without English text comes before Rifter in the input.
  typed(
    BundleSection.types,
    '{"_key":34562,"groupID":25,"name":{"de":"Nur deutsch"},'
    '"published":false,"mass":1000.0}',
    {'groupId': 25, 'name': null, 'published': false, 'mass': 1000.0},
  );
  typed(
    BundleSection.types,
    '{"_key":587,"groupID":25,"name":{"de":"Rifter DE","en":"Rifter"},'
    '"description":{"en":"A frigate."},"published":true,"volume":27289.0,'
    '"capacity":140.0,"portionSize":1,"mass":1067000.0,"marketGroupID":64,'
    '"metaGroupID":1,"radius":31.0,"factionID":500002,"raceID":2,'
    '"variationParentTypeID":586,"basePrice":30000.5}',
    {
      'groupId': 25,
      'name': 'Rifter',
      'published': true,
      'volume': 27289.0,
      'capacity': 140.0,
      'portionSize': 1,
      'mass': 1067000.0,
      'marketGroupId': 64,
      'metaGroupId': 1,
    },
  );
  typed(
    BundleSection.marketGroups,
    '{"_key":64,"name":{"en":"Minmatar"},"parentGroupID":61,'
    '"hasTypes":true,"iconID":1364}',
    {'name': 'Minmatar', 'parentGroupId': 61, 'hasTypes': true, 'iconId': 1364},
  );
  typed(
    BundleSection.metaGroups,
    '{"_key":1,"name":{"en":"Tech I"},"iconID":null}',
    {'name': 'Tech I', 'iconId': null},
  );
  typed(
    BundleSection.dogmaAttributes,
    '{"_key":4,"name":"mass","displayName":{"de":"Masse","en":"Mass"},'
    '"attributeCategoryID":7,"unitID":2,"defaultValue":0.0,'
    '"published":true,"highIsGood":true,"stackable":true,"dataType":5}',
    {
      'name': 'mass',
      'displayName': 'Mass',
      'attributeCategoryId': 7,
      'unitId': 2,
      'defaultValue': 0.0,
      'published': true,
      'highIsGood': true,
      'stackable': true,
    },
  );
  typed(
    BundleSection.dogmaAttributeCategories,
    '{"_key":7,"name":"Fitting","description":"Fitting capabilities"}',
    {'name': 'Fitting', 'description': 'Fitting capabilities'},
  );
  typed(
    BundleSection.dogmaEffects,
    '{"_key":11,"name":"loPower","effectCategoryID":0,"published":false,'
    '"isOffensive":false,"isAssistance":false,"guid":"effects.LoPower"}',
    {
      'name': 'loPower',
      'displayName': null,
      'effectCategoryId': 0,
      'published': false,
      'isOffensive': false,
      'isAssistance': false,
    },
  );
  typed(
    BundleSection.dogmaUnits,
    '{"_key":2,"name":"Mass","displayName":{"en":"kg"},'
    '"description":{"en":"Kilogram"}}',
    {'name': 'Mass', 'displayName': 'kg', 'description': 'Kilogram'},
  );
  typed(
    BundleSection.typeDogma,
    '{"_key":587,"dogmaAttributes":[{"attributeID":4,"value":1067000.0}],'
    '"dogmaEffects":[{"effectID":11,"isDefault":false}]}',
    {},
  );
  typed(
    BundleSection.mapRegions,
    '{"_key":10000002,"name":{"en":"The Forge"},"factionID":500001,'
    '"constellationIDs":[20000020]}',
    {'name': 'The Forge', 'factionId': 500001},
  );
  typed(
    BundleSection.mapConstellations,
    '{"_key":20000020,"regionID":10000002,"name":{"en":"Kimotoro"},'
    '"factionID":500001}',
    {'regionId': 10000002, 'name': 'Kimotoro', 'factionId': 500001},
  );
  typed(
    BundleSection.mapSolarSystems,
    '{"_key":30000142,"constellationID":20000020,"regionID":10000002,'
    '"name":{"en":"Jita"},"securityStatus":0.9459,"securityClass":"B",'
    '"radius":1.0e12}',
    {
      'constellationId': 20000020,
      'regionId': 10000002,
      'name': 'Jita',
      'securityStatus': 0.9459,
      'securityClass': 'B',
    },
  );
  // A duplicate raw key is kept, ordered by key, then line.
  raw(BundleSection.dbuffCollections, 3, '{"_key":10,"aggregateMode":"Max"}');
  raw(BundleSection.dbuffCollections, 1, '{"_key":2,"aggregateMode":"Min"}');
  raw(BundleSection.dbuffCollections, 2, '{"_key":10,"aggregateMode":"Min"}');
  if (withDynamicItemAttributes) {
    raw(
      BundleSection.dynamicItemAttributes,
      1,
      '{"_key":47297,"attributeIDs":[{"_key":4,"min":0.9,"max":1.1}]}',
    );
  }
  raw(
    BundleSection.fighterAbilities,
    1,
    '{"_key":1,"name":{"en":"Pulse Cannon"},"targetMode":"untargeted"}',
  );
  raw(
    BundleSection.fighterAbilitiesByType,
    1,
    '{"_key":23055,"abilitySlot0":{"abilityID":1}}',
  );
  return builder;
}

/// The lines of the bundle file [bytes], each decoded from JSON.
List<Object?> bundleLines(Uint8List bytes) {
  final text = utf8.decode(const GZipDecoder().decodeBytes(bytes));
  expectTrailingNewline(text);
  return [
    for (final line in text.substring(0, text.length - 1).split('\n'))
      jsonDecode(line),
  ];
}

/// Throws unless [text] ends with exactly one line feed.
void expectTrailingNewline(String text) {
  if (!text.endsWith('\n') || text.endsWith('\n\n')) {
    throw StateError('bundle text does not end with one line feed');
  }
}

/// The record lines of [section] in the bundle file [bytes].
List<List<Object?>> sectionLines(Uint8List bytes, BundleSection section) {
  final lines = bundleLines(bytes);
  final start = lines.indexWhere(
    (line) => line is Map && line['section'] == section.file,
  );
  if (start < 0) return const [];
  return [
    for (final line in lines.skip(start + 1).takeWhile((line) => line is List))
      line! as List<Object?>,
  ];
}
