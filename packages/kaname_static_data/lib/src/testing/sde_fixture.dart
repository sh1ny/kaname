/// Synthetic SDE builds for tests (design D9).
///
/// Every record is invented for these tests; no CCP data is used. The
/// builder starts from a complete build and lets a test change one thing: add
/// a new file or field, break a record, drop a file, and so on.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:kaname_static_data/kaname_static_data.dart';

import 'sde_zip.dart';

/// A mutable synthetic build that can be written as a JSON Lines zip.
final class SdeFixture {
  /// Creates an empty build with no files.
  SdeFixture.empty();

  /// Creates a complete build numbered [build].
  ///
  /// It holds the `_sde` record, every typed file with a full record and a
  /// bare one, every id of the production `knownIds` table in the file of its
  /// kind, the untyped files the field check reads, an integer-keyed and a
  /// string-keyed known untyped file, and every field `industryLogisticsFields`
  /// declares.
  factory SdeFixture.complete({int build = 1000}) {
    final fixture = SdeFixture.empty();
    fixture.files['_sde.jsonl'] = [
      {
        '_key': 'sde',
        'buildNumber': build,
        'releaseDate': '2026-01-01T00:00:00Z',
      },
    ];
    fixture.files.addAll(_typedRecords());
    for (final known in knownIds) {
      fixture.files[known.kind.fileName]!.add({
        '_key': known.id,
        'name': {'en': known.name},
      });
    }
    fixture.files.addAll(_plainRecords());
    return fixture;
  }

  /// The lines of each file by file name, in write order.
  ///
  /// A line is a JSON-encodable value, or a [RawLine] written as is.
  final Map<String, List<Object?>> files = {};

  /// Replaces the build number in the `_sde` record.
  void setBuild(int build) {
    files['_sde.jsonl'] = [
      {'_key': 'sde', 'buildNumber': build},
    ];
  }

  /// The zip's bytes.
  Uint8List toZip() => buildZip(files);

  /// Writes the zip into [dir] under [name] and returns the file.
  File writeTo(Directory dir, [String name = 'sde.zip']) =>
      writeFile(dir, name, toZip());
}

Map<String, List<Object?>> _typedRecords() => {
  'categories.jsonl': [
    {
      '_key': 9001,
      'name': {'en': 'Test category', 'de': 'Testkategorie'},
      'published': true,
      'iconID': 10,
    },
    {
      '_key': 9002,
      'name': {'en': 'Bare category'},
      'published': false,
    },
  ],
  'groups.jsonl': [
    {
      '_key': 9101,
      'categoryID': 9001,
      'name': {'en': 'Test group'},
      'published': true,
      'anchorable': false,
      'anchored': false,
      'fittableNonSingleton': false,
      'useBasePrice': false,
      'iconID': 11,
    },
    {
      '_key': 9102,
      'categoryID': 9002,
      'name': {'en': 'Bare group'},
    },
  ],
  'types.jsonl': [
    {
      '_key': 9201,
      'groupID': 9101,
      'name': {'en': 'Test hull', 'de': 'Testhuelle'},
      'portionSize': 1,
      'published': true,
      // A whole number: JSON `5` decodes to an int, a double column takes it.
      'volume': 5,
      'packagedVolume': 2.5,
      'capacity': 10.5,
      'mass': 1000.0,
      'marketGroupID': 9301,
      'metaGroupID': 1,
      'description': {'en': 'A synthetic hull'},
    },
    {
      '_key': 9202,
      'groupID': 9102,
      'name': {'en': 'Bare type'},
      'portionSize': 1,
      'published': false,
    },
  ],
  'marketGroups.jsonl': [
    {
      '_key': 9301,
      'name': {'en': 'Test market group'},
      'hasTypes': true,
      'parentGroupID': 9302,
      'iconID': 12,
    },
    {
      '_key': 9302,
      'name': {'en': 'Test market root'},
      'hasTypes': false,
    },
  ],
  'metaGroups.jsonl': [
    {
      '_key': 1,
      'name': {'en': 'Tech I'},
      'iconID': 13,
      'iconSuffix': 'a',
      'color': {'r': 0.1, 'g': 0.2, 'b': 0.3},
    },
  ],
  'dogmaAttributes.jsonl': [
    {
      '_key': 9401,
      'name': 'testAttribute',
      'displayName': {'en': 'Test attribute'},
      'attributeCategoryID': 9501,
      'unitID': 9601,
      'defaultValue': 0.0,
      'published': true,
      'highIsGood': true,
      'stackable': true,
      'dataType': 0,
      'displayWhenZero': false,
      'description': 'A synthetic attribute',
    },
  ],
  'dogmaAttributeCategories.jsonl': [
    {
      '_key': 9501,
      'name': 'Test attribute category',
      'description': 'Synthetic',
    },
  ],
  'dogmaEffects.jsonl': [
    {
      '_key': 9701,
      'name': 'testEffect',
      'displayName': {'en': 'Test effect'},
      'effectCategoryID': 1,
      'published': false,
      'isOffensive': false,
      'isAssistance': false,
      'disallowAutoRepeat': false,
      'electronicChance': false,
      'isWarpSafe': true,
      'propulsionChance': false,
      'rangeChance': false,
    },
  ],
  'dogmaUnits.jsonl': [
    {
      '_key': 9601,
      'name': 'Length',
      'displayName': {'en': 'm'},
      'description': {'en': 'Meter'},
    },
  ],
  'typeDogma.jsonl': [
    {
      '_key': 9201,
      'dogmaAttributes': [
        {'attributeID': 9401, 'value': 1.5},
      ],
    },
  ],
  'mapRegions.jsonl': [
    {
      '_key': 10009001,
      'name': {'en': 'Test region'},
      'factionID': 500001,
      'constellationIDs': [20009001],
      'nebulaID': 1,
      'position': {'x': 1.0, 'y': 2.0, 'z': 3.0},
    },
  ],
  'mapConstellations.jsonl': [
    {
      '_key': 20009001,
      'name': {'en': 'Test constellation'},
      'regionID': 10009001,
      'solarSystemIDs': [30009001],
      'position': {'x': 1.0, 'y': 2.0, 'z': 3.0},
    },
  ],
  'mapSolarSystems.jsonl': [
    {
      '_key': 30009001,
      'name': {'en': 'Test system'},
      'constellationID': 20009001,
      'regionID': 10009001,
      'securityStatus': 0.5,
      'securityClass': 'B',
      'position': {'x': 1.0e16, 'y': 2.0e16, 'z': 3.0e16},
      'radius': 1.0e12,
    },
  ],
};

Map<String, List<Object?>> _plainRecords() => {
  'blueprints.jsonl': [
    {
      '_key': 9801,
      'maxProductionLimit': 300,
      'activities': {
        'copying': {'time': 480},
        'research_material': {'time': 210},
        'research_time': {'time': 210},
        'manufacturing': {
          'materials': [
            {'typeID': 9201, 'quantity': 86},
          ],
          'products': [
            {'typeID': 9202, 'quantity': 1},
          ],
          'skills': [
            {'typeID': 9203, 'level': 1},
          ],
          'time': 600,
        },
        'invention': {
          'materials': [
            {'typeID': 9201, 'quantity': 2},
          ],
          'products': [
            {'typeID': 9802, 'quantity': 1, 'probability': 0.3},
          ],
          'skills': [
            {'typeID': 9203, 'level': 3},
          ],
          'time': 3600,
        },
        'reaction': {
          'materials': [
            {'typeID': 9201, 'quantity': 100},
          ],
          'products': [
            {'typeID': 9202, 'quantity': 200},
          ],
          'time': 10800,
        },
      },
    },
  ],
  'typeMaterials.jsonl': [
    {
      '_key': 9201,
      'materials': [
        {'materialTypeID': 9202, 'quantity': 175},
      ],
    },
  ],
  'planetSchematics.jsonl': [
    {
      '_key': 9901,
      'cycleTime': 3600,
      'name': {'en': 'Test schematic'},
      'pins': [1, 2],
      'types': [
        {'_key': 9201, 'isInput': true, 'quantity': 40},
        {'_key': 9202, 'isInput': false, 'quantity': 5},
      ],
    },
  ],
  'mapStargates.jsonl': [
    {
      '_key': 50009001,
      'solarSystemID': 30009001,
      'typeID': 9201,
      'destination': {'solarSystemID': 30009001, 'stargateID': 50009002},
      'position': {'x': 1.0, 'y': 2.0, 'z': 3.0},
    },
  ],
  // An integer-keyed known untyped file.
  'factions.jsonl': [
    {
      '_key': 500001,
      'name': {'en': 'Test faction'},
    },
    {
      '_key': 500002,
      'name': {'en': 'Other faction'},
    },
  ],
  // A known untyped file with string keys.
  'translationLanguages.jsonl': [
    {'_key': 'en', 'name': 'English'},
  ],
};
