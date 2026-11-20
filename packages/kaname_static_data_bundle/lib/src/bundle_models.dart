/// The typed records a reader decodes for search and display.
library;

/// Text keyed by locale, such as a type's name.
final class LocalizedText {
  /// Creates text with the entries of [byLocale].
  const LocalizedText(this.byLocale);

  /// Text with no locale.
  static const LocalizedText none = LocalizedText({});

  /// The text of each locale the bundle holds, for example `{"en": ...}`.
  final Map<String, String> byLocale;

  /// The English text, or `null` when the record has none.
  String? get en => byLocale['en'];

  @override
  String toString() => 'LocalizedText($byLocale)';
}

/// A type from the bundle's `types` section.
final class BundleType {
  /// Creates a type.
  const BundleType({
    required this.id,
    required this.name,
    required this.groupId,
    required this.published,
    required this.volume,
    required this.capacity,
    required this.portionSize,
    required this.mass,
    required this.marketGroupId,
    required this.metaGroupId,
    required this.radius,
    required this.factionId,
    required this.raceId,
    required this.variationParentTypeId,
  });

  /// The type id.
  final int id;

  /// The type's name.
  final LocalizedText name;

  /// The id of the type's group, when known.
  final int? groupId;

  /// Whether CCP publishes the type; `false` when the SDE does not say.
  final bool published;

  /// The type's volume in m³, when known.
  final double? volume;

  /// The type's cargo capacity in m³, when known.
  final double? capacity;

  /// The type's portion size, when known.
  final int? portionSize;

  /// The type's mass in kg, when known.
  final double? mass;

  /// The id of the type's market group, when it has one.
  final int? marketGroupId;

  /// The id of the type's meta group, when it has one.
  final int? metaGroupId;

  /// The type's radius in metres, when known.
  final double? radius;

  /// The id of the type's faction, when it has one.
  final int? factionId;

  /// The id of the type's race, when it has one.
  final int? raceId;

  /// The id of the type this one is a variation of, when it is one.
  final int? variationParentTypeId;
}

/// A group from the bundle's `groups` section.
final class BundleGroup {
  /// Creates a group.
  const BundleGroup({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.published,
  });

  /// The group id.
  final int id;

  /// The group's name.
  final LocalizedText name;

  /// The id of the group's category, when known.
  final int? categoryId;

  /// Whether CCP publishes the group; `false` when the SDE does not say.
  final bool published;
}

/// A region from the bundle's `mapRegions` section.
final class BundleRegion {
  /// Creates a region.
  const BundleRegion({
    required this.id,
    required this.name,
    required this.factionId,
  });

  /// The region id.
  final int id;

  /// The region's name.
  final LocalizedText name;

  /// The id of the region's faction, when it has one.
  final int? factionId;
}

/// A solar system from the bundle's `mapSolarSystems` section.
final class BundleSolarSystem {
  /// Creates a solar system.
  const BundleSolarSystem({
    required this.id,
    required this.name,
    required this.constellationId,
    required this.regionId,
    required this.securityStatus,
    required this.securityClass,
  });

  /// The solar system id.
  final int id;

  /// The solar system's name.
  final LocalizedText name;

  /// The id of the system's constellation, when known.
  final int? constellationId;

  /// The id of the system's region, when known.
  final int? regionId;

  /// The system's security status, when known.
  final double? securityStatus;

  /// The system's security class, when it has one.
  final String? securityClass;
}
