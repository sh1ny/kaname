/// The install's declared organisation tree, independent of member state.
sealed class OrgTree {
  const OrgTree();
}

/// The operator has not declared a tree. Affiliation refresh stays enabled.
final class UnconfiguredOrgTree extends OrgTree {
  /// Represents an unset or empty declaration.
  const UnconfiguredOrgTree();
}

/// A tree consisting of one corporation.
final class CorporationOrgTree extends OrgTree {
  const CorporationOrgTree._(this.corporationId);

  /// The declared EVE corporation ID.
  final int corporationId;
}

/// A tree consisting of one alliance.
final class AllianceOrgTree extends OrgTree {
  const AllianceOrgTree._(this.allianceId);

  /// The declared EVE alliance ID.
  final int allianceId;
}

/// A tree consisting of at least two distinct alliances.
final class CoalitionOrgTree extends OrgTree {
  CoalitionOrgTree._(Set<int> ids) : allianceIds = Set.unmodifiable(ids);

  /// The declared EVE alliance IDs, with no corporation IDs.
  final Set<int> allianceIds;
}

/// Reads `KANAME_ORG_TREE` without logging the supplied setting.
///
/// Throws a [FormatException] for a non-empty, invalid declaration.
OrgTree readOrgTree(Map<String, String> environment) {
  final value = environment['KANAME_ORG_TREE'];
  if (value == null || value.isEmpty) return const UnconfiguredOrgTree();
  final colon = value.indexOf(':');
  if (colon < 0) throw _invalid;
  final ids = value.substring(colon + 1);
  return switch (value.substring(0, colon)) {
    'corporation' => CorporationOrgTree._(_id(ids)),
    'alliance' => AllianceOrgTree._(_id(ids)),
    'coalition' => _coalition(ids),
    _ => throw _invalid,
  };
}

const _invalid = FormatException(
  'Invalid KANAME_ORG_TREE: expected corporation:<id>, alliance:<id>, '
  'or coalition:<id>,<id>[,...] with positive decimal IDs and no duplicates.',
);
final _decimal = RegExp(r'^[0-9]+$');

int _id(String text) {
  final id = _decimal.hasMatch(text) ? int.tryParse(text, radix: 10) : null;
  if (id == null || id <= 0) throw _invalid;
  return id;
}

CoalitionOrgTree _coalition(String text) {
  final ids = <int>{};
  for (final part in text.split(',')) {
    if (!ids.add(_id(part))) throw _invalid;
  }
  if (ids.length < 2) throw _invalid;
  return CoalitionOrgTree._(ids);
}
