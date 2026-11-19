/// The check that a build holds the fields industry and logistics need.
library;

import 'package:kaname_core/kaname_core.dart';

/// A field of an SDE record that a later milestone needs.
final class IndustryLogisticsField {
  /// Creates a declaration of [path] in [file], needed for [purpose].
  const IndustryLogisticsField(this.file, this.path, this.purpose);

  /// The file the field lives in, for example `blueprints.jsonl`.
  final String file;

  /// The field's path inside a record.
  ///
  /// Segments are separated by dots. A segment ending in `[]` is a list: the
  /// path continues into any element, and a path ending in `[]` needs a list
  /// with at least one element. A record holds the field when the path leads
  /// to a value that is not `null`.
  final String path;

  /// What the field is for, naming the milestone.
  final String purpose;
}

/// The fields M18 (industry), M19 (invention, planetary industry), M20
/// (reprocessing) and M22 (freight and logistics) need, checked against build
/// 3714173 (assumption A2 of the design).
///
/// The list comes from the milestones' descriptions in `openspec/roadmap.md`:
/// blueprints, jobs, cost model and build planner (M18); invention and the PI
/// dashboard (M19); reprocessing (M20); freight and routes (M22). The first
/// build checked held every field, so this list has no known gap; each import
/// checks it again, and R38 asks whether a patch ever removes one.
const List<IndustryLogisticsField> industryLogisticsFields = [
  IndustryLogisticsField(
    'types.jsonl',
    'volume',
    'M22 freight: the volume of an item in cargo',
  ),
  IndustryLogisticsField(
    'types.jsonl',
    'packagedVolume',
    'M22 freight: the volume of a repackaged ship or item',
  ),
  IndustryLogisticsField(
    'types.jsonl',
    'capacity',
    'M22 freight: the cargo capacity of a hauler or container',
  ),
  IndustryLogisticsField(
    'types.jsonl',
    'portionSize',
    'M20 reprocessing: the batch size of one reprocessing run',
  ),
  IndustryLogisticsField(
    'blueprints.jsonl',
    'activities.manufacturing.materials[]',
    'M18 build planner: the materials of a manufacturing job',
  ),
  IndustryLogisticsField(
    'blueprints.jsonl',
    'activities.manufacturing.products[]',
    'M18 build planner: what a manufacturing job produces',
  ),
  IndustryLogisticsField(
    'blueprints.jsonl',
    'activities.manufacturing.skills[]',
    'M18 build planner: the skills a manufacturing job needs',
  ),
  IndustryLogisticsField(
    'blueprints.jsonl',
    'activities.manufacturing.time',
    'M18 cost model: the base time of a manufacturing job',
  ),
  IndustryLogisticsField(
    'blueprints.jsonl',
    'activities.invention.materials[]',
    'M19 invention: the datacores and other inputs of an invention job',
  ),
  IndustryLogisticsField(
    'blueprints.jsonl',
    'activities.invention.products[]',
    'M19 invention: the blueprints an invention job can produce',
  ),
  IndustryLogisticsField(
    'blueprints.jsonl',
    'activities.invention.products[].probability',
    'M19 invention: the chance that an invention job succeeds',
  ),
  IndustryLogisticsField(
    'blueprints.jsonl',
    'activities.invention.skills[]',
    'M19 invention: the skills an invention job needs',
  ),
  IndustryLogisticsField(
    'blueprints.jsonl',
    'activities.invention.time',
    'M19 invention: the base time of an invention job',
  ),
  IndustryLogisticsField(
    'blueprints.jsonl',
    'activities.reaction.materials[]',
    'M18 build planner: the inputs of a reaction job',
  ),
  IndustryLogisticsField(
    'blueprints.jsonl',
    'activities.reaction.products[]',
    'M18 build planner: what a reaction job produces',
  ),
  IndustryLogisticsField(
    'blueprints.jsonl',
    'activities.reaction.time',
    'M18 cost model: the base time of a reaction job',
  ),
  IndustryLogisticsField(
    'blueprints.jsonl',
    'activities.copying.time',
    'M18 jobs: the base time of a copying job',
  ),
  IndustryLogisticsField(
    'blueprints.jsonl',
    'activities.research_material.time',
    'M18 jobs: the base time of a material efficiency research job',
  ),
  IndustryLogisticsField(
    'blueprints.jsonl',
    'activities.research_time.time',
    'M18 jobs: the base time of a time efficiency research job',
  ),
  IndustryLogisticsField(
    'blueprints.jsonl',
    'maxProductionLimit',
    'M18 jobs: the most runs of a blueprint copy',
  ),
  IndustryLogisticsField(
    'typeMaterials.jsonl',
    'materials[].materialTypeID',
    'M20 reprocessing: what an item reprocesses into',
  ),
  IndustryLogisticsField(
    'typeMaterials.jsonl',
    'materials[].quantity',
    'M20 reprocessing: how much of each material an item yields',
  ),
  IndustryLogisticsField(
    'planetSchematics.jsonl',
    'cycleTime',
    'M19 PI dashboard: the cycle time of a schematic',
  ),
  IndustryLogisticsField(
    'planetSchematics.jsonl',
    'types[].isInput',
    'M19 PI dashboard: which items a schematic consumes and makes',
  ),
  IndustryLogisticsField(
    'planetSchematics.jsonl',
    'types[].quantity',
    'M19 PI dashboard: how much a schematic consumes and makes',
  ),
  IndustryLogisticsField(
    'mapStargates.jsonl',
    'destination.solarSystemID',
    'M22 freight: the system on the other side of a stargate, for routes',
  ),
  IndustryLogisticsField(
    'mapSolarSystems.jsonl',
    'position.x',
    'M22 freight: the system position, for distances (x)',
  ),
  IndustryLogisticsField(
    'mapSolarSystems.jsonl',
    'position.y',
    'M22 freight: the system position, for distances (y)',
  ),
  IndustryLogisticsField(
    'mapSolarSystems.jsonl',
    'position.z',
    'M22 freight: the system position, for distances (z)',
  ),
  IndustryLogisticsField(
    'mapSolarSystems.jsonl',
    'securityStatus',
    'M22 freight: the security of a system, for route risk',
  ),
];

/// How many records of a build hold one declared field.
final class FieldCheckResult {
  /// Creates the result for [field], held by [records] records.
  const FieldCheckResult(this.field, this.records);

  /// The declared field.
  final IndustryLogisticsField field;

  /// The number of records that hold the field.
  final int records;

  /// Whether at least one record holds the field.
  bool get isPresent => records > 0;
}

/// The result of checking every declared field against a build.
final class FieldCheckReport {
  /// Creates a report of [results], in the order of the declaration.
  const FieldCheckReport(this.results);

  /// One result per declared field.
  final List<FieldCheckResult> results;

  /// The results of fields no record holds.
  List<FieldCheckResult> get missing => [
    for (final result in results)
      if (!result.isPresent) result,
  ];

  /// Whether every declared field is present.
  bool get isComplete => results.every((result) => result.isPresent);

  /// The report as JSON for the import record.
  SdeJson toSdeJson() => SdeJson({
    'complete': isComplete,
    'fields': [
      for (final FieldCheckResult(:field, :records, :isPresent) in results)
        {
          'file': field.file,
          'path': field.path,
          'purpose': field.purpose,
          'status': isPresent ? 'present' : 'missing',
          'records': records,
        },
    ],
  });
}

/// Counts, record by record, how many records hold each declared field.
final class FieldCheckCollector {
  /// Creates a collector for [fields].
  FieldCheckCollector(List<IndustryLogisticsField> fields)
    : _fields = fields,
      _counts = List.filled(fields.length, 0),
      _byFile = {} {
    for (var i = 0; i < fields.length; i++) {
      (_byFile[fields[i].file] ??= []).add(i);
    }
    _paths = [for (final field in fields) _parse(field.path)];
  }

  final List<IndustryLogisticsField> _fields;
  final List<int> _counts;
  final Map<String, List<int>> _byFile;
  late final List<List<_Step>> _paths;

  /// Counts the declared fields of [file] that [record] holds.
  void observe(String file, Map<String, Object?> record) {
    final indexes = _byFile[file];
    if (indexes == null) return;
    for (final index in indexes) {
      if (_holds(record, _paths[index], 0)) _counts[index]++;
    }
  }

  /// Returns the report for everything observed so far.
  FieldCheckReport finish() => FieldCheckReport([
    for (var i = 0; i < _fields.length; i++)
      FieldCheckResult(_fields[i], _counts[i]),
  ]);
}

final class _Step {
  const _Step(this.name, {required this.isList});
  final String name;
  final bool isList;
}

List<_Step> _parse(String path) => [
  for (final segment in path.split('.'))
    segment.endsWith('[]')
        ? _Step(segment.substring(0, segment.length - 2), isList: true)
        : _Step(segment, isList: false),
];

bool _holds(Object? node, List<_Step> steps, int index) {
  if (node is! Map<Object?, Object?>) return false;
  final _Step(:name, :isList) = steps[index];
  final value = node[name];
  final isLast = index == steps.length - 1;
  if (isList) {
    if (value is! List<Object?>) return false;
    if (isLast) return value.isNotEmpty;
    return value.any((element) => _holds(element, steps, index + 1));
  }
  if (value == null) return false;
  return isLast || _holds(value, steps, index + 1);
}
