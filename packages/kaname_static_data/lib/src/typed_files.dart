/// The typed files of the SDE and how their records become rows.
library;

import 'package:kaname_core/kaname_core.dart';

import 'sde_rows.dart';

/// The JSON type a typed column expects.
enum ColumnKind {
  /// A JSON integer.
  integer,

  /// Any JSON number; an integer is accepted and read as a `double`.
  real,

  /// A JSON `true` or `false`.
  boolean,

  /// A JSON string, or a localised object whose `en` entry is a string.
  ///
  /// CCP ships most names as `{"de": ..., "en": ...}` and a few as plain
  /// strings; both land in the same column as the English text. A localised
  /// object without an `en` string gives no value and is not a type error.
  text,
}

/// One typed column of a typed table.
final class TypedColumn {
  /// Creates a column called [name] read from the record's [jsonField].
  const TypedColumn(this.name, this.jsonField, this.kind);

  /// The column's name in Kaname's table, for example `groupId`.
  final String name;

  /// The field's name in CCP's record, for example `groupID`.
  final String jsonField;

  /// The JSON type the column expects.
  final ColumnKind kind;
}

/// A record parsed for a typed table.
final class ParsedTypedRecord {
  /// Creates a parsed record.
  const ParsedTypedRecord({
    required this.row,
    required this.unknownFields,
    required this.wrongTypedFields,
  });

  /// The row to store.
  final TypedRow row;

  /// Fields of the record that the file's definition does not list.
  final List<String> unknownFields;

  /// Known typed fields whose value had another JSON type than expected.
  final List<String> wrongTypedFields;
}

/// A file of the SDE that has its own table with typed columns.
final class TypedFile {
  /// Creates the definition of [fileName], stored in [table].
  const TypedFile({
    required this.fileName,
    required this.table,
    required this.columns,
    this.otherFields = const [],
  });

  /// The file's name, for example `types.jsonl`.
  final String fileName;

  /// The table's name, for example `sde_type`.
  final String table;

  /// The columns, in table order.
  final List<TypedColumn> columns;

  /// The other fields CCP ships in this file today.
  ///
  /// They have no typed column and live in the record's JSON. Listing them
  /// keeps them from being reported as new on every import.
  final List<String> otherFields;

  /// The key field every record has.
  static const String keyField = '_key';

  /// Whether [field] is one this definition lists: the key, a typed column's
  /// field or an other field.
  bool knowsField(String field) =>
      field == keyField ||
      otherFields.contains(field) ||
      columns.any((column) => column.jsonField == field);

  /// Parses [record], whose key is [sdeId], into a row.
  ParsedTypedRecord parse(int sdeId, Map<String, Object?> record) {
    final values = <String, Object?>{};
    final wrongTyped = <String>[];
    for (final column in columns) {
      final value = record[column.jsonField];
      if (value == null) {
        values[column.name] = null;
        continue;
      }
      final typed = _convert(column.kind, value);
      switch (typed) {
        case _Converted(:final value):
          values[column.name] = value;
        case _WrongType():
          values[column.name] = null;
          wrongTyped.add(column.jsonField);
      }
    }
    return ParsedTypedRecord(
      row: TypedRow(
        table: table,
        sdeId: sdeId,
        values: values,
        raw: SdeJson(record),
      ),
      unknownFields: [
        for (final field in record.keys)
          if (!knowsField(field)) field,
      ],
      wrongTypedFields: wrongTyped,
    );
  }
}

sealed class _Conversion {
  const _Conversion();
}

final class _Converted extends _Conversion {
  const _Converted(this.value);
  final Object? value;
}

final class _WrongType extends _Conversion {
  const _WrongType();
}

_Conversion _convert(ColumnKind kind, Object value) => switch ((kind, value)) {
  (ColumnKind.integer, final int v) => _Converted(v),
  (ColumnKind.real, final num v) => _Converted(v.toDouble()),
  (ColumnKind.boolean, final bool v) => _Converted(v),
  (ColumnKind.text, final String v) => _Converted(v),
  (ColumnKind.text, {'en': final String english}) => _Converted(english),
  (ColumnKind.text, Map<Object?, Object?>()) => const _Converted(null),
  _ => const _WrongType(),
};

const _int = ColumnKind.integer;
const _real = ColumnKind.real;
const _bool = ColumnKind.boolean;
const _text = ColumnKind.text;

/// The thirteen typed files, checked against SDE build 3714173 (assumption
/// A1 of the design): every typed column's field name and JSON type, and
/// every other field, is what that build ships.
const List<TypedFile> typedFiles = [
  TypedFile(
    fileName: 'categories.jsonl',
    table: 'sde_category',
    columns: [
      TypedColumn('name', 'name', _text),
      TypedColumn('published', 'published', _bool),
      TypedColumn('iconId', 'iconID', _int),
    ],
  ),
  TypedFile(
    fileName: 'groups.jsonl',
    table: 'sde_group',
    columns: [
      TypedColumn('categoryId', 'categoryID', _int),
      TypedColumn('name', 'name', _text),
      TypedColumn('published', 'published', _bool),
    ],
    otherFields: [
      'anchorable',
      'anchored',
      'fittableNonSingleton',
      'useBasePrice',
      'iconID',
    ],
  ),
  TypedFile(
    fileName: 'types.jsonl',
    table: 'sde_type',
    columns: [
      TypedColumn('groupId', 'groupID', _int),
      TypedColumn('name', 'name', _text),
      TypedColumn('published', 'published', _bool),
      TypedColumn('volume', 'volume', _real),
      TypedColumn('capacity', 'capacity', _real),
      TypedColumn('portionSize', 'portionSize', _int),
      TypedColumn('mass', 'mass', _real),
      TypedColumn('marketGroupId', 'marketGroupID', _int),
      TypedColumn('metaGroupId', 'metaGroupID', _int),
    ],
    otherFields: [
      'packagedVolume',
      'description',
      'iconID',
      'raceID',
      'graphicID',
      'radius',
      'basePrice',
      'techLevel',
      'metaLevel',
      'isRepackable',
      'soundID',
      'variationParentTypeID',
      'factionID',
      'shipTreeGroupID',
      'isDynamicType',
    ],
  ),
  TypedFile(
    fileName: 'marketGroups.jsonl',
    table: 'sde_market_group',
    columns: [
      TypedColumn('name', 'name', _text),
      TypedColumn('parentGroupId', 'parentGroupID', _int),
      TypedColumn('hasTypes', 'hasTypes', _bool),
      TypedColumn('iconId', 'iconID', _int),
    ],
    otherFields: ['description'],
  ),
  TypedFile(
    fileName: 'metaGroups.jsonl',
    table: 'sde_meta_group',
    columns: [
      TypedColumn('name', 'name', _text),
      TypedColumn('iconId', 'iconID', _int),
    ],
    otherFields: ['iconSuffix', 'color', 'description'],
  ),
  TypedFile(
    fileName: 'dogmaAttributes.jsonl',
    table: 'sde_dogma_attribute',
    columns: [
      TypedColumn('name', 'name', _text),
      TypedColumn('displayName', 'displayName', _text),
      TypedColumn('attributeCategoryId', 'attributeCategoryID', _int),
      TypedColumn('unitId', 'unitID', _int),
      TypedColumn('defaultValue', 'defaultValue', _real),
      TypedColumn('published', 'published', _bool),
      TypedColumn('highIsGood', 'highIsGood', _bool),
      TypedColumn('stackable', 'stackable', _bool),
    ],
    otherFields: [
      'dataType',
      'displayWhenZero',
      'description',
      'iconID',
      'tooltipTitle',
      'tooltipDescription',
      'maxAttributeID',
      'minAttributeID',
      'chargeRechargeTimeID',
    ],
  ),
  TypedFile(
    fileName: 'dogmaAttributeCategories.jsonl',
    table: 'sde_dogma_attribute_category',
    columns: [
      TypedColumn('name', 'name', _text),
      TypedColumn('description', 'description', _text),
    ],
  ),
  TypedFile(
    fileName: 'dogmaEffects.jsonl',
    table: 'sde_dogma_effect',
    columns: [
      TypedColumn('name', 'name', _text),
      TypedColumn('displayName', 'displayName', _text),
      TypedColumn('effectCategoryId', 'effectCategoryID', _int),
      TypedColumn('published', 'published', _bool),
      TypedColumn('isOffensive', 'isOffensive', _bool),
      TypedColumn('isAssistance', 'isAssistance', _bool),
    ],
    otherFields: [
      'disallowAutoRepeat',
      'electronicChance',
      'isWarpSafe',
      'propulsionChance',
      'rangeChance',
      'modifierInfo',
      'guid',
      'iconID',
      'description',
      'rangeAttributeID',
      'durationAttributeID',
      'dischargeAttributeID',
      'distribution',
      'falloffAttributeID',
      'resistanceAttributeID',
      'npcActivationChanceAttributeID',
      'fittingUsageChanceAttributeID',
      'npcUsageChanceAttributeID',
      'trackingSpeedAttributeID',
    ],
  ),
  TypedFile(
    fileName: 'dogmaUnits.jsonl',
    table: 'sde_dogma_unit',
    columns: [
      TypedColumn('name', 'name', _text),
      TypedColumn('displayName', 'displayName', _text),
      TypedColumn('description', 'description', _text),
    ],
  ),
  TypedFile(
    fileName: 'typeDogma.jsonl',
    table: 'sde_type_dogma',
    columns: [],
    otherFields: ['dogmaAttributes', 'dogmaEffects'],
  ),
  TypedFile(
    fileName: 'mapRegions.jsonl',
    table: 'sde_region',
    columns: [
      TypedColumn('name', 'name', _text),
      TypedColumn('factionId', 'factionID', _int),
    ],
    otherFields: [
      'constellationIDs',
      'nebulaID',
      'position',
      'wormholeClassID',
      'description',
    ],
  ),
  TypedFile(
    fileName: 'mapConstellations.jsonl',
    table: 'sde_constellation',
    columns: [
      TypedColumn('regionId', 'regionID', _int),
      TypedColumn('name', 'name', _text),
      TypedColumn('factionId', 'factionID', _int),
    ],
    otherFields: ['position', 'solarSystemIDs', 'wormholeClassID'],
  ),
  TypedFile(
    fileName: 'mapSolarSystems.jsonl',
    table: 'sde_solar_system',
    columns: [
      TypedColumn('constellationId', 'constellationID', _int),
      TypedColumn('regionId', 'regionID', _int),
      TypedColumn('name', 'name', _text),
      TypedColumn('securityStatus', 'securityStatus', _real),
      TypedColumn('securityClass', 'securityClass', _text),
    ],
    otherFields: [
      'position',
      'radius',
      'starID',
      'planetIDs',
      'position2D',
      'luminosity',
      'stargateIDs',
      'hub',
      'border',
      'corridor',
      'fringe',
      'wormholeClassID',
      'disallowedAnchorCategories',
      'regional',
      'visualEffect',
      'international',
      'disallowedAnchorGroups',
      'factionID',
    ],
  ),
];
