/// The pinned ESI spec snapshot and its pin file (design D8 of
/// `esi-client-generator`).
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

import 'file_system.dart';

/// The committed spec snapshot, relative to the repository root.
const String esiSnapshotPath = 'packages/kaname_esi/spec/openapi.json';

/// The committed pin file, relative to the repository root.
const String esiPinPath = 'packages/kaname_esi/spec/pin.yaml';

final RegExp _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final RegExp _sha256 = RegExp(r'^[0-9a-f]{64}$');

/// Whether [value] has the `YYYY-MM-DD` form of a compatibility date.
bool isEsiDate(String value) => _date.hasMatch(value);

/// The lower-case hex SHA-256 of [text]'s UTF-8 bytes.
///
/// The repository stores the snapshot with LF line endings and no byte
/// order mark (`.gitattributes`), so these are the bytes on disk.
String esiSha256(String text) => sha256.convert(utf8.encode(text)).toString();

/// What `pin.yaml` records.
final class EsiPin {
  /// Creates a pin.
  const EsiPin({
    required this.date,
    required this.source,
    required this.sha256,
  });

  /// The compatibility date, `YYYY-MM-DD`.
  final String date;

  /// The URL the snapshot was fetched from.
  final String source;

  /// The snapshot's lower-case hex SHA-256.
  final String sha256;

  /// The pin file's text.
  String render() =>
      '# Written by `mise run esi:fetch`; do not edit by hand.\n'
      'date: "$date"\n'
      'source: "$source"\n'
      'sha256: "$sha256"\n';
}

/// Reads a pin file, or lists why it cannot be used.
({EsiPin? pin, List<String> problems}) parseEsiPin(String text) {
  final Object? document;
  try {
    document = loadYaml(text);
  } on YamlException catch (e) {
    return (
      pin: null,
      problems: ['$esiPinPath is not valid YAML: ${e.message}'],
    );
  }
  if (document is! Map<Object?, Object?>) {
    return (pin: null, problems: ['$esiPinPath is not a YAML mapping']);
  }
  final fields = document;
  final problems = <String>[];
  String? field(String name, bool Function(String) valid, String form) {
    final value = fields[name];
    if (value == null) {
      problems.add('$esiPinPath lacks its $name');
      return null;
    }
    if (value is String && valid(value)) return value;
    problems.add('$esiPinPath has an invalid $name "$value"; expected $form');
    return null;
  }

  final date = field('date', isEsiDate, 'YYYY-MM-DD');
  final source = field(
    'source',
    (v) => v.startsWith('https://'),
    'an https:// URL',
  );
  final hash = field('sha256', _sha256.hasMatch, '64 lower-case hex digits');
  if (date == null || source == null || hash == null) {
    return (pin: null, problems: problems);
  }
  return (
    pin: EsiPin(date: date, source: source, sha256: hash),
    problems: problems,
  );
}

/// Lists how [document], a decoded spec, disagrees with the compatibility
/// [date]: its `info.version` and its `X-Compatibility-Date` parameter enum
/// must both name it.
List<String> esiDateProblems(
  Object? document,
  String date, {
  required String what,
}) {
  final version = switch (document) {
    {'info': {'version': final String version}} => version,
    _ => null,
  };
  final dates = <String>[
    if (document case {
      'components': {'parameters': final Map<String, Object?> parameters},
    })
      for (final parameter in parameters.values)
        if (parameter case {
          'in': 'header',
          'name': 'X-Compatibility-Date',
          'schema': {'enum': final List<Object?> values},
        })
          for (final value in values)
            if (value is String) value,
  ];
  return [
    if (version != date)
      '$what date $date differs from the snapshot\'s info.version '
          '${version ?? '(missing)'}',
    if (!dates.contains(date))
      '$what date $date differs from the snapshot\'s X-Compatibility-Date '
          'enum ${dates.isEmpty ? '(missing)' : dates.join(', ')}',
  ];
}

/// What [loadEsiSnapshot] found.
sealed class EsiSnapshotLoad {
  const EsiSnapshotLoad();
}

/// The snapshot matches its pin.
final class EsiSnapshotLoaded extends EsiSnapshotLoad {
  /// Creates the loaded pair.
  const EsiSnapshotLoaded(this.pin, this.document);

  /// The pin.
  final EsiPin pin;

  /// The decoded snapshot, parsed from exactly the bytes that were hashed.
  final Object? document;
}

/// The snapshot or the pin cannot be used.
final class EsiSnapshotRefused extends EsiSnapshotLoad {
  /// Creates a refusal listing [problems].
  const EsiSnapshotRefused(this.problems);

  /// Why, each naming the file, field or date at fault.
  final List<String> problems;
}

/// Reads the pin and the snapshot from [fileSystem], hashes the snapshot's
/// exact text, and only then parses that same text and checks its dates.
EsiSnapshotLoad loadEsiSnapshot(FileSystem fileSystem) {
  final String pinText;
  try {
    pinText = fileSystem.readAsString(esiPinPath);
  } on Exception catch (e) {
    return EsiSnapshotRefused(['$esiPinPath cannot be read: $e']);
  }
  final (:pin, :problems) = parseEsiPin(pinText);
  if (pin == null) return EsiSnapshotRefused(problems);

  final String snapshot;
  try {
    snapshot = fileSystem.readAsString(esiSnapshotPath);
  } on Exception catch (e) {
    return EsiSnapshotRefused(['$esiSnapshotPath cannot be read: $e']);
  }
  final hash = esiSha256(snapshot);
  if (hash != pin.sha256) {
    return EsiSnapshotRefused([
      '$esiSnapshotPath does not match the pin\'s hash '
          '(pin ${pin.sha256}, snapshot $hash); rerun `mise run esi:fetch` '
          'for the pinned date instead of editing either file',
    ]);
  }

  final Object? document;
  try {
    document = jsonDecode(snapshot);
  } on FormatException catch (e) {
    return EsiSnapshotRefused(['$esiSnapshotPath is not JSON: ${e.message}']);
  }
  final dateProblems = esiDateProblems(document, pin.date, what: 'The pin\'s');
  if (dateProblems.isNotEmpty) return EsiSnapshotRefused(dateProblems);
  return EsiSnapshotLoaded(pin, document);
}
