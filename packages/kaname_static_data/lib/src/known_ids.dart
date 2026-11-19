/// The one small table of SDE ids that code knows, and its check.
library;

import 'package:kaname_core/kaname_core.dart';

/// What kind of SDE record an id names; each kind lives in one typed file.
enum IdKind {
  /// An item category, in `categories.jsonl`.
  category('categories.jsonl'),

  /// An item group, in `groups.jsonl`.
  group('groups.jsonl'),

  /// An item type, in `types.jsonl`.
  type('types.jsonl'),

  /// A market group, in `marketGroups.jsonl`.
  marketGroup('marketGroups.jsonl'),

  /// A meta group, in `metaGroups.jsonl`.
  metaGroup('metaGroups.jsonl'),

  /// A dogma attribute, in `dogmaAttributes.jsonl`.
  dogmaAttribute('dogmaAttributes.jsonl'),

  /// A dogma attribute category, in `dogmaAttributeCategories.jsonl`.
  dogmaAttributeCategory('dogmaAttributeCategories.jsonl'),

  /// A dogma effect, in `dogmaEffects.jsonl`.
  dogmaEffect('dogmaEffects.jsonl'),

  /// A dogma unit, in `dogmaUnits.jsonl`.
  dogmaUnit('dogmaUnits.jsonl'),

  /// A region, in `mapRegions.jsonl`.
  region('mapRegions.jsonl'),

  /// A constellation, in `mapConstellations.jsonl`.
  constellation('mapConstellations.jsonl'),

  /// A solar system, in `mapSolarSystems.jsonl`.
  solarSystem('mapSolarSystems.jsonl');

  const IdKind(this.fileName);

  /// The typed file whose keys are ids of this kind.
  final String fileName;
}

/// An SDE id that code relies on, with a name and the kind it must have.
final class KnownId {
  /// Creates an entry: [name] describes [id], which must be a [kind].
  const KnownId(this.name, this.id, this.kind);

  /// What the id is, for reports, for example `ship category`.
  final String name;

  /// The id.
  final int id;

  /// The kind of record the id must name.
  final IdKind kind;
}

/// The ids Kaname code relies on, checked against every build.
///
/// Code that needs an id must read it from here, with a name; no Dart enum or
/// constant may be generated from SDE content (requirement "No code is
/// generated from SDE content"), and the source scan test fails on id
/// constants declared elsewhere.
///
/// The design says this table starts with only the ids M1 code uses. M1
/// changes after this one (build switch, client data bundle, settings page)
/// are described in `openspec/roadmap.md` without naming an id, so nothing
/// requires one yet. The table holds the three item categories a fit engine
/// consumes (ships, modules and charges, ADR 0011) so that the check runs
/// against real data from the first build on; the first change that needs an
/// id adds it here.
const List<KnownId> knownIds = [
  KnownId('ship category', 6, IdKind.category),
  KnownId('module category', 7, IdKind.category),
  KnownId('charge category', 8, IdKind.category),
];

/// One known id the build does not hold as expected.
final class KnownIdFinding {
  /// Creates a finding for [known], which the build holds as [foundAs].
  const KnownIdFinding(this.known, this.foundAs);

  /// The table entry.
  final KnownId known;

  /// The other kinds the id exists as in the build; empty when it exists as
  /// no kind at all (missing).
  final List<IdKind> foundAs;

  /// Whether the id is absent from the build, rather than another kind.
  bool get isMissing => foundAs.isEmpty;
}

/// The result of checking the known-ids table against a build.
final class KnownIdsReport {
  /// Creates a report of [checked] entries with [findings].
  const KnownIdsReport({required this.checked, required this.findings});

  /// How many table entries were checked.
  final int checked;

  /// The entries the build does not hold as expected.
  final List<KnownIdFinding> findings;

  /// Whether every entry exists in the build with its expected kind.
  bool get passed => findings.isEmpty;

  /// The report as JSON for the import record.
  SdeJson toSdeJson() => SdeJson({
    'checked': checked,
    'passed': passed,
    'findings': [
      for (final KnownIdFinding(:known, :foundAs, :isMissing) in findings)
        {
          'name': known.name,
          'id': known.id,
          'expected': known.kind.name,
          'status': isMissing ? 'missing' : 'other kind',
          'foundAs': [for (final kind in foundAs) kind.name],
        },
    ],
  });
}

/// Checks [table] against [idsByFile], the keys of every typed file's
/// records, by file name.
///
/// An id that is not among the keys of its kind's file is a finding. When it
/// is among the keys of other kinds' files, the finding lists them.
KnownIdsReport checkKnownIds(
  List<KnownId> table,
  Map<String, Set<int>> idsByFile,
) {
  final findings = <KnownIdFinding>[];
  for (final known in table) {
    if (idsByFile[known.kind.fileName]?.contains(known.id) ?? false) continue;
    findings.add(
      KnownIdFinding(known, [
        for (final kind in IdKind.values)
          if (kind != known.kind &&
              (idsByFile[kind.fileName]?.contains(known.id) ?? false))
            kind,
      ]),
    );
  }
  return KnownIdsReport(checked: table.length, findings: findings);
}
