/// The sections of a bundle and the typed columns each one carries.
/// @docImport 'bundle_builder.dart';
library;

/// The JSON type a bundle column holds.
enum BundleColumnKind {
  /// A JSON integer.
  integer,

  /// Any JSON number; integral values are written as integers.
  real,

  /// A JSON `true` or `false`.
  boolean,

  /// A string written as is, such as a solar system's `securityClass`.
  text,

  /// Text written under its locale, as `{"en": value}`.
  ///
  /// A record without the text is written with an empty object, `{}`, so it
  /// keeps its place and has no `en` name.
  localizedText,
}

/// One column of a section's `typed` object.
final class BundleColumn {
  /// Creates a column fed as [name] and written as [field].
  const BundleColumn(this.name, this.field, this.kind);

  /// The column's Kaname name, for example `groupId`.
  ///
  /// A [TypedRecord]'s values are keyed by this name, the same name as the
  /// server's typed column and the import's row value.
  final String name;

  /// The field's name in the bundle, CCP's name for it, for example
  /// `groupID`.
  final String field;

  /// The JSON type the column holds.
  final BundleColumnKind kind;
}

const _int = BundleColumnKind.integer;
const _real = BundleColumnKind.real;
const _bool = BundleColumnKind.boolean;
const _text = BundleColumnKind.text;
const _l10n = BundleColumnKind.localizedText;

/// A section of a bundle: one SDE file, in the bundle's fixed file order.
///
/// The declaration order is the format's section order: the 13 typed files
/// in the importer's order, then the four raw-only files. Changing it, or a
/// section's columns, is a major format change; adding a section at the end
/// is a minor one.
///
/// A typed section's `typed` object is keyed by CCP's field names
/// ([BundleColumn.field]), so its fields read like the SDE and like the type
/// extras `radius`, `factionID`, `raceID` and `variationParentTypeID`.
enum BundleSection {
  /// `categories.jsonl`.
  categories(
    columns: [
      BundleColumn('name', 'name', _l10n),
      BundleColumn('published', 'published', _bool),
      BundleColumn('iconId', 'iconID', _int),
    ],
  ),

  /// `groups.jsonl`.
  groups(
    columns: [
      BundleColumn('categoryId', 'categoryID', _int),
      BundleColumn('name', 'name', _l10n),
      BundleColumn('published', 'published', _bool),
    ],
  ),

  /// `types.jsonl`, whose records also carry the [typeExtras].
  types(
    columns: [
      BundleColumn('groupId', 'groupID', _int),
      BundleColumn('name', 'name', _l10n),
      BundleColumn('published', 'published', _bool),
      BundleColumn('volume', 'volume', _real),
      BundleColumn('capacity', 'capacity', _real),
      BundleColumn('portionSize', 'portionSize', _int),
      BundleColumn('mass', 'mass', _real),
      BundleColumn('marketGroupId', 'marketGroupID', _int),
      BundleColumn('metaGroupId', 'metaGroupID', _int),
    ],
  ),

  /// `marketGroups.jsonl`.
  marketGroups(
    columns: [
      BundleColumn('name', 'name', _l10n),
      BundleColumn('parentGroupId', 'parentGroupID', _int),
      BundleColumn('hasTypes', 'hasTypes', _bool),
      BundleColumn('iconId', 'iconID', _int),
    ],
  ),

  /// `metaGroups.jsonl`.
  metaGroups(
    columns: [
      BundleColumn('name', 'name', _l10n),
      BundleColumn('iconId', 'iconID', _int),
    ],
  ),

  /// `dogmaAttributes.jsonl`, with its full raw JSON.
  dogmaAttributes(
    columns: [
      BundleColumn('name', 'name', _l10n),
      BundleColumn('displayName', 'displayName', _l10n),
      BundleColumn('attributeCategoryId', 'attributeCategoryID', _int),
      BundleColumn('unitId', 'unitID', _int),
      BundleColumn('defaultValue', 'defaultValue', _real),
      BundleColumn('published', 'published', _bool),
      BundleColumn('highIsGood', 'highIsGood', _bool),
      BundleColumn('stackable', 'stackable', _bool),
    ],
  ),

  /// `dogmaAttributeCategories.jsonl`, with its full raw JSON.
  dogmaAttributeCategories(
    columns: [
      BundleColumn('name', 'name', _l10n),
      BundleColumn('description', 'description', _l10n),
    ],
  ),

  /// `dogmaEffects.jsonl`, with its full raw JSON.
  dogmaEffects(
    columns: [
      BundleColumn('name', 'name', _l10n),
      BundleColumn('displayName', 'displayName', _l10n),
      BundleColumn('effectCategoryId', 'effectCategoryID', _int),
      BundleColumn('published', 'published', _bool),
      BundleColumn('isOffensive', 'isOffensive', _bool),
      BundleColumn('isAssistance', 'isAssistance', _bool),
    ],
  ),

  /// `dogmaUnits.jsonl`, with its full raw JSON.
  dogmaUnits(
    columns: [
      BundleColumn('name', 'name', _l10n),
      BundleColumn('displayName', 'displayName', _l10n),
      BundleColumn('description', 'description', _l10n),
    ],
  ),

  /// `typeDogma.jsonl`: no typed columns, its full raw JSON only.
  typeDogma(columns: []),

  /// `mapRegions.jsonl`.
  mapRegions(
    columns: [
      BundleColumn('name', 'name', _l10n),
      BundleColumn('factionId', 'factionID', _int),
    ],
  ),

  /// `mapConstellations.jsonl`.
  mapConstellations(
    columns: [
      BundleColumn('regionId', 'regionID', _int),
      BundleColumn('name', 'name', _l10n),
      BundleColumn('factionId', 'factionID', _int),
    ],
  ),

  /// `mapSolarSystems.jsonl`.
  mapSolarSystems(
    columns: [
      BundleColumn('constellationId', 'constellationID', _int),
      BundleColumn('regionId', 'regionID', _int),
      BundleColumn('name', 'name', _l10n),
      BundleColumn('securityStatus', 'securityStatus', _real),
      BundleColumn('securityClass', 'securityClass', _text),
    ],
  ),

  /// `dbuffCollections.jsonl` (buffs): raw JSON only.
  dbuffCollections(),

  /// `dynamicItemAttributes.jsonl` (mutaplasmids): raw JSON only.
  dynamicItemAttributes(),

  /// `fighterAbilities.jsonl`: raw JSON only.
  fighterAbilities(),

  /// `fighterAbilitiesByType.jsonl`: raw JSON only.
  fighterAbilitiesByType();

  const BundleSection({this.columns});

  /// The format minor version that added the section; every section of
  /// format 1.0 has 0.
  ///
  /// A section added in a later minor sets it, so a reader that knows the
  /// section still opens an older bundle whose header never lists it
  /// ([isDefinedIn]). A later minor that adds a section returns its minor
  /// for it here.
  int get sinceMinor => 0;

  /// Whether a bundle of format minor [formatMinor] defines the section, so
  /// that its header must list it, present or absent.
  bool isDefinedIn(int formatMinor) =>
      sectionDefinedIn(sinceMinor: sinceMinor, formatMinor: formatMinor);

  /// The typed columns, or `null` for a raw-only section.
  ///
  /// A raw-only section's `typed` object is empty and it keeps its records'
  /// full JSON. `typeDogma` is typed with no columns.
  final List<BundleColumn>? columns;

  /// Whether the section's lines carry the record's full JSON as `raw`.
  ///
  /// True for the five dogma files and the four raw-only files; every other
  /// section writes `raw` as `null`.
  bool get carriesRaw => switch (this) {
    dogmaAttributes ||
    dogmaAttributeCategories ||
    dogmaEffects ||
    dogmaUnits ||
    typeDogma => true,
    _ => isRawOnly,
  };

  /// Whether the section has no typed columns and is fed [RawRecord]s.
  bool get isRawOnly => columns == null;

  /// The section's name in the bundle, the file's name without `.jsonl`.
  String get file => name;

  /// The SDE file the section is built from, for example `types.jsonl`.
  String get fileName => '$name.jsonl';

  /// The fields every type record carries besides its typed columns.
  ///
  /// They are taken from the type's raw JSON, which the bundle does not keep
  /// for types: `radius` as a number and the others as integers, `null` when
  /// absent or of another JSON type.
  static const List<BundleColumn> typeExtras = [
    BundleColumn('factionID', 'factionID', _int),
    BundleColumn('raceID', 'raceID', _int),
    BundleColumn('radius', 'radius', _real),
    BundleColumn('variationParentTypeID', 'variationParentTypeID', _int),
  ];

  /// The section called [file] in a bundle, or `null` for an unknown one.
  ///
  /// Accepts the bundle's name (`types`) or the SDE file name
  /// (`types.jsonl`).
  static BundleSection? fromFile(String file) {
    final base = file.endsWith('.jsonl')
        ? file.substring(0, file.length - '.jsonl'.length)
        : file;
    for (final section in values) {
      if (section.name == base) return section;
    }
    return null;
  }
}

/// Whether a section added in format minor [sinceMinor] is defined by a
/// bundle of format minor [formatMinor]: only when it is not newer.
bool sectionDefinedIn({required int sinceMinor, required int formatMinor}) =>
    sinceMinor <= formatMinor;
