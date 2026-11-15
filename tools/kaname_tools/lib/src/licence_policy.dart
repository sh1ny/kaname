import 'dart:io';

import 'package:yaml/yaml.dart';

import 'file_system.dart';
import 'licence_matcher.dart';

/// One owner-approved exception of the licence policy.
final class LicenceException {
  /// Creates an exception, the [index]th entry of `exceptions:`.
  const LicenceException({
    required this.index,
    required this.package,
    required this.version,
    required this.licence,
    required this.reason,
    required this.approved,
  });

  /// The zero-based position of the entry in `exceptions:`.
  final int index;

  /// The package the entry covers.
  final String package;

  /// The one version the entry covers.
  final String version;

  /// The licence the owner reviewed: an SPDX identifier or `unrecognised`.
  final String licence;

  /// Why the owner accepted the package.
  final String reason;

  /// The ISO date (`YYYY-MM-DD`) of the owner's approval.
  final String approved;

  /// How problem messages name the entry.
  String get label => 'exceptions[$index] ($package $version)';
}

/// The committed licence policy: what may pass and what the owner accepted.
final class LicencePolicy {
  /// Creates a policy.
  const LicencePolicy({required this.allowed, required this.exceptions});

  /// The licence identifiers that pass without an exception. Every one names
  /// a known, AGPL-3.0-compatible licence.
  final Set<String> allowed;

  /// The exceptions, in file order.
  final List<LicenceException> exceptions;
}

/// The outcome of [loadLicencePolicy].
sealed class PolicyLoad {
  const PolicyLoad();
}

/// The policy file is valid.
final class PolicyLoaded extends PolicyLoad {
  /// Creates a result carrying [policy].
  const PolicyLoaded(this.policy);

  /// The validated policy.
  final LicencePolicy policy;
}

/// The policy file is missing or invalid; nothing is allowed or excepted.
final class PolicyInvalid extends PolicyLoad {
  /// Creates a result carrying every problem found.
  const PolicyInvalid(this.problems);

  /// What is wrong, each entry naming the file and what it concerns.
  final List<String> problems;
}

/// Repository-relative path of the licence policy.
const String licencePolicyPath = 'licence-policy.yaml';

/// The licence recorded in an exception for a package with no known licence.
const String unrecognisedLicenceName = 'unrecognised';

const Set<String> _policyKeys = {'allowed', 'exceptions'};
const Set<String> _entryKeys = {
  'package',
  'version',
  'licence',
  'reason',
  'approved',
};

/// Loads and validates `licence-policy.yaml` from [fileSystem].
///
/// The file has two keys. `allowed:` is a list of SPDX identifiers; each
/// must name a template the matcher knows (see [licenceTemplates]) that is
/// AGPL-3.0-compatible, so a typo or an incompatible identifier cannot widen
/// the policy. `exceptions:` is a list of entries with `package`, `version`,
/// `licence`, `reason` and `approved` (an ISO date), all strings. `licence`
/// is a template's SPDX identifier or `unrecognised`, never a read failure
/// such as a missing licence file, so an exception cannot hide one. An unknown
/// key, at the top or in an entry, is an error. Any problem makes the whole
/// policy [PolicyInvalid], so nothing is allowed or excepted by a bad file.
PolicyLoad loadLicencePolicy(FileSystem fileSystem) {
  if (fileSystem.kindOf(licencePolicyPath) != FsEntryKind.file) {
    return const PolicyInvalid(['$licencePolicyPath: file not found']);
  }
  final Object? document;
  try {
    document = loadYaml(fileSystem.readAsString(licencePolicyPath));
  } on YamlException catch (e) {
    return PolicyInvalid(['$licencePolicyPath: not valid YAML: ${e.message}']);
  } on FileSystemException catch (e) {
    return PolicyInvalid(['$licencePolicyPath: cannot be read: ${e.message}']);
  } on FormatException catch (e) {
    return PolicyInvalid(['$licencePolicyPath: not valid UTF-8: ${e.message}']);
  }
  if (document is! Map<Object?, Object?>) {
    return const PolicyInvalid([
      '$licencePolicyPath: expected a map with the keys allowed and exceptions',
    ]);
  }
  final problems = <String>[
    for (final key in document.keys)
      if (key is! String || !_policyKeys.contains(key))
        '$licencePolicyPath: unknown key "$key"',
  ];
  final allowed = _readAllowed(document['allowed'], problems);
  final exceptions = _readExceptions(document['exceptions'], problems);
  if (problems.isNotEmpty) return PolicyInvalid(problems);
  return PolicyLoaded(LicencePolicy(allowed: allowed, exceptions: exceptions));
}

Set<String> _readAllowed(Object? value, List<String> problems) {
  if (value is! List<Object?>) {
    problems.add('$licencePolicyPath: allowed: must be a list of licence ids');
    return const {};
  }
  final allowed = <String>{};
  for (var i = 0; i < value.length; i++) {
    final entry = value[i];
    if (entry is! String) {
      problems.add('$licencePolicyPath: allowed[$i] must be a licence id');
      continue;
    }
    switch (licenceTemplateFor(entry)) {
      case null:
        problems.add(
          '$licencePolicyPath: allowed entry "$entry" names no licence the '
          'check knows',
        );
      case LicenceTemplate(agplCompatible: false):
        problems.add(
          '$licencePolicyPath: allowed entry "$entry" is not '
          'AGPL-3.0-compatible',
        );
      case LicenceTemplate():
        allowed.add(entry);
    }
  }
  return allowed;
}

/// What an exception's `licence` may hold.
const _licenceValueRule = 'must be an SPDX id the check knows or unrecognised';

List<LicenceException> _readExceptions(Object? value, List<String> problems) {
  switch (value) {
    case null:
      return const [];
    case List<Object?>():
      break;
    default:
      problems.add('$licencePolicyPath: exceptions: must be a list');
      return const [];
  }
  final exceptions = <LicenceException>[];
  for (var i = 0; i < value.length; i++) {
    final entry = value[i];
    if (entry is! Map<Object?, Object?>) {
      problems.add('$licencePolicyPath: exceptions[$i] must be a map');
      continue;
    }
    final fields = <String, String>{};
    final before = problems.length;
    final name = _entryName(i, entry);
    for (final key in entry.keys) {
      if (key is! String || !_entryKeys.contains(key)) {
        problems.add('$licencePolicyPath: $name has unknown key "$key"');
      }
    }
    for (final key in _entryKeys) {
      switch (entry[key]) {
        case final String text when text.trim().isNotEmpty:
          fields[key] = text;
        case null:
          problems.add('$licencePolicyPath: $name is missing "$key"');
        default:
          problems.add(
            '$licencePolicyPath: $name: "$key" must be a non-empty string '
            '(quote versions)',
          );
      }
    }
    final licence = fields['licence'];
    if (licence != null &&
        licence != unrecognisedLicenceName &&
        licenceTemplateFor(licence) == null) {
      problems.add(
        '$licencePolicyPath: $name: "licence" $_licenceValueRule, '
        'found "$licence"',
      );
    }
    final approved = fields['approved'];
    if (approved != null && !_isIsoDate(approved)) {
      problems.add(
        '$licencePolicyPath: $name: "approved" must be an ISO date '
        '(YYYY-MM-DD), found "$approved"',
      );
    }
    if (problems.length == before) {
      exceptions.add(
        LicenceException(
          index: i,
          package: fields['package']!,
          version: fields['version']!,
          licence: fields['licence']!,
          reason: fields['reason']!,
          approved: fields['approved']!,
        ),
      );
    }
  }
  return exceptions;
}

String _entryName(int index, Map<Object?, Object?> entry) {
  return switch ((entry['package'], entry['version'])) {
    (final String package, final String version) =>
      'exceptions[$index] ($package $version)',
    (final String package, _) => 'exceptions[$index] ($package)',
    _ => 'exceptions[$index]',
  };
}

bool _isIsoDate(String text) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return false;
  final date = DateTime.tryParse('${text}T00:00:00Z');
  return date != null && date.toIso8601String().startsWith(text);
}
