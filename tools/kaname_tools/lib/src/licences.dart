/// Dependency licence classification and policy check.
///
/// Classifies every package of the root `pubspec.lock` by licence and checks
/// the result against the committed `licence-policy.yaml`.
///
/// **Deliberate gap (C5):** only pub packages are checked. Native platform
/// dependencies (Gradle, CocoaPods or SwiftPM packages, and the Flutter
/// engine's bundled components) are neither licence-checked nor in the SBOM.
/// The engine's bundled licences are covered by one reference,
/// [engineBundleLicence], accepted without a text.
library;

import 'package:args/command_runner.dart';

import 'cli.dart';
import 'file_system.dart';
import 'licence_matcher.dart';
import 'licence_policy.dart';
import 'locked_packages.dart';

/// The licence reference of `sky_engine`, which bundles the engine's
/// third-party licences.
const String engineBundleLicence = 'LicenseRef-flutter-engine-bundle';

/// The licence of the Flutter SDK packages `flutter` and `flutter_test`.
const String flutterLicence = 'BSD-3-Clause';

/// What is known about the licence of one locked package.
sealed class PackageLicence {
  const PackageLicence();

  /// How messages name the licence: its identifier, `unrecognised`, or why
  /// there is none.
  String get label;
}

/// The package's licence was classified.
final class FoundLicence extends PackageLicence {
  /// Creates a result carrying [classification].
  const FoundLicence(this.classification);

  /// What the licence text matched.
  final LicenceClassification classification;

  @override
  String get label => switch (classification) {
    KnownLicence(:final id) => id,
    UnrecognisedLicence() => unrecognisedLicenceName,
  };
}

/// The package has no licence file.
final class NoLicenceFile extends PackageLicence {
  /// Creates a result with the [message] that names the package.
  const NoLicenceFile(this.message);

  /// The problem, naming the package and its version.
  final String message;

  @override
  String get label => 'no licence file';
}

/// The package's licence file or directory could not be read.
final class UnreadableLicence extends PackageLicence {
  /// Creates a result with the [message] that names the package.
  const UnreadableLicence(this.message);

  /// The problem, naming the package and its version.
  final String message;

  @override
  String get label => 'unreadable licence';
}

/// A locked package with its [licence].
final class ClassifiedPackage {
  /// Creates a classified package.
  const ClassifiedPackage(this.package, this.licence);

  /// The locked package.
  final LockedPackage package;

  /// What its licence is.
  final PackageLicence licence;
}

/// The outcome of [classifyLockedPackages].
sealed class LockClassification {
  const LockClassification();
}

/// Every locked package was looked at.
final class Classified extends LockClassification {
  /// Creates a result for [packages], sorted by name.
  const Classified(this.packages);

  /// The packages with their licences.
  final List<ClassifiedPackage> packages;
}

/// Nothing could be classified, for example because the workspace is not
/// resolved.
final class NotClassified extends LockClassification {
  /// Creates a result with the [problem].
  const NotClassified(this.problem);

  /// What is wrong, with the hint to fix it.
  final String problem;
}

/// Classifies every package of the root lockfile, sorted by name.
///
/// The SDK packages `flutter` and `flutter_test` take the Flutter SDK's
/// licence, [flutterLicence]; `sky_engine` takes [engineBundleLicence]. Every
/// other package is classified from its licence file, found as the notices
/// check finds it. A package whose licence file is missing or unreadable is
/// reported as such and does not stop the others. Returns [NotClassified]
/// when the lockfile or the package config is missing or invalid.
LockClassification classifyLockedPackages(
  FileSystem fileSystem, [
  LicenceMatcher matcher = const LicenceMatcher(),
]) {
  final List<LockedPackage> packages;
  final Map<String, String> roots;
  try {
    roots = readResolvedPackageRoots(fileSystem);
    packages = readLockedPackages(fileSystem)
      ..sort((a, b) => a.name.compareTo(b.name));
  } on WorkspaceReadException catch (e) {
    return NotClassified(e.message);
  }
  return Classified([
    for (final package in packages)
      ClassifiedPackage(
        package,
        _licenceOf(fileSystem, matcher, package, roots[package.name]),
      ),
  ]);
}

PackageLicence _licenceOf(
  FileSystem fileSystem,
  LicenceMatcher matcher,
  LockedPackage package,
  String? root,
) {
  switch ((package.source, package.name)) {
    case ('sdk', 'sky_engine'):
      return const FoundLicence(KnownLicence(engineBundleLicence));
    case ('sdk', 'flutter' || 'flutter_test'):
      return const FoundLicence(KnownLicence(flutterLicence));
  }
  try {
    final text = readLicenceText(
      fileSystem,
      package.name,
      package.version,
      root,
    );
    return FoundLicence(matcher.classify(text));
  } on NoLicenceFileException catch (e) {
    return NoLicenceFile(e.message);
  } on WorkspaceReadException catch (e) {
    return UnreadableLicence(e.message);
  }
}

/// A package that passes through an exception.
final class ExceptedPackage {
  /// Creates a record of [package] excepted by [exception].
  const ExceptedPackage(this.package, this.exception);

  /// The locked package.
  final LockedPackage package;

  /// The entry that covers it.
  final LicenceException exception;
}

/// The outcome of [checkLicences].
sealed class LicenceCheckResult {
  const LicenceCheckResult();
}

/// Every package passes.
final class LicenceCheckPassed extends LicenceCheckResult {
  /// Creates a passing result.
  const LicenceCheckPassed({
    required this.packages,
    required this.counts,
    required this.excepted,
  });

  /// Every locked package with its licence, sorted by name.
  final List<ClassifiedPackage> packages;

  /// How many packages carry each allowed licence identifier, sorted by
  /// identifier. Excepted packages are not counted here.
  final Map<String, int> counts;

  /// The packages that pass through an exception.
  final List<ExceptedPackage> excepted;
}

/// At least one package, exception or policy entry fails.
final class LicenceCheckFailed extends LicenceCheckResult {
  /// Creates a failing result carrying every problem found.
  const LicenceCheckFailed(this.problems);

  /// What is wrong, each entry naming what it concerns.
  final List<String> problems;
}

/// Checks the locked packages' licences against `licence-policy.yaml`.
///
/// Fails, listing every problem, when the workspace is not resolved; when
/// the policy file is missing or invalid (then nothing is allowed or
/// excepted); when a package has no licence file, an unrecognised licence or
/// a licence off the allowlist and no exception covers it; and when an
/// exception is stale (no locked package at that exact version), records a
/// licence other than the one found, or covers a package that already
/// passes. [engineBundleLicence] always passes.
LicenceCheckResult checkLicences(FileSystem fileSystem) =>
    switch (classifyLockedPackages(fileSystem)) {
      NotClassified(:final problem) => LicenceCheckFailed([problem]),
      Classified(:final packages) => switch (loadLicencePolicy(fileSystem)) {
        PolicyInvalid(:final problems) => LicenceCheckFailed(problems),
        PolicyLoaded(:final policy) => _evaluate(packages, policy),
      },
    };

/// Why an exception never applies to a licence read failure.
const _readFailureNote = 'cannot cover a package whose licence was not read';

LicenceCheckResult _evaluate(
  List<ClassifiedPackage> packages,
  LicencePolicy policy,
) {
  final problems = <String>[];
  final counts = <String, int>{};
  final excepted = <ExceptedPackage>[];
  final used = <int>{};
  for (final classified in packages) {
    final ClassifiedPackage(:package, :licence) = classified;
    final name = '${package.name} ${package.version}';
    final exception = policy.exceptions
        .where((e) => e.package == package.name && e.version == package.version)
        .firstOrNull;
    final allowedId = switch (licence) {
      FoundLicence(classification: KnownLicence(:final id))
          when id == engineBundleLicence || policy.allowed.contains(id) =>
        id,
      _ => null,
    };
    if (exception != null) {
      used.add(exception.index);
      if (licence
          case NoLicenceFile(:final message) ||
              UnreadableLicence(:final message)) {
        problems.add('$message; ${exception.label} $_readFailureNote');
      } else if (allowedId != null) {
        problems.add(
          '$licencePolicyPath: ${exception.label} is not needed: $name is '
          'already allowed as $allowedId',
        );
      } else if (exception.licence != licence.label) {
        problems.add(
          '$licencePolicyPath: ${exception.label} records licence '
          '${exception.licence} but the check found ${licence.label}',
        );
      } else {
        excepted.add(ExceptedPackage(package, exception));
      }
    } else if (allowedId != null) {
      counts[allowedId] = (counts[allowedId] ?? 0) + 1;
    } else {
      problems.add(switch (licence) {
        FoundLicence(classification: KnownLicence(:final id)) =>
          'package $name: licence $id is not on the allowlist',
        FoundLicence(classification: UnrecognisedLicence()) =>
          'package $name: licence is unrecognised',
        NoLicenceFile(:final message) ||
        UnreadableLicence(:final message) => message,
      });
    }
  }
  for (final exception in policy.exceptions) {
    if (!used.contains(exception.index)) {
      problems.add(
        '$licencePolicyPath: ${exception.label} is stale: pubspec.lock has '
        'no such package at that version',
      );
    }
  }
  if (problems.isNotEmpty) return LicenceCheckFailed(problems);
  return LicenceCheckPassed(
    packages: packages,
    counts: Map.fromEntries(
      counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    ),
    excepted: excepted,
  );
}

/// The `licences` command: checks dependency licences against the policy.
///
/// The check covers pub packages only. A deliberate gap: the licences of the
/// container images (Postgres, Redis, Caddy, Debian) and of the native
/// libraries that pub build hooks bundle into the server image
/// (`libsqlite3`, SQLite, public domain; `libsqlite3_connection_pool`, which
/// statically links the Rust `lru` crate and Rust std, MIT/Apache-2.0) are
/// outside this check, the generated section of THIRD_PARTY_NOTICES and the
/// SBOM. The server image is built locally and not redistributed, so nothing
/// is owed yet. A change that publishes the image, or that brings a hook
/// package into a distributed app, must add their notices first.
final class LicencesCommand extends Command<int> {
  /// Creates the command over [_fileSystem], writing to [_output].
  LicencesCommand(this._fileSystem, this._output) {
    argParser.addFlag(
      'check',
      negatable: false,
      help:
          'Fail if a locked package has an unrecognised, missing or '
          'disallowed licence, or the policy is invalid. Writes nothing.',
    );
  }

  final FileSystem _fileSystem;
  final CliOutput _output;

  @override
  String get name => 'licences';

  @override
  String get description =>
      'Check the licences of the locked packages (--check) against '
      '$licencePolicyPath.';

  @override
  int run() {
    if (!argResults!.flag('check')) usageException('Pass --check.');
    switch (checkLicences(_fileSystem)) {
      case LicenceCheckFailed(:final problems):
        for (final problem in problems) {
          _output.err.writeln(problem);
        }
        return exitCheckFailed;
      case LicenceCheckPassed(:final counts, :final excepted):
        for (final MapEntry(:key, :value) in counts.entries) {
          _output.out.writeln('$key: $value');
        }
        for (final ExceptedPackage(:package, :exception) in excepted) {
          _output.out.writeln(
            'excepted ${package.name} ${package.version} '
            '(${exception.licence}): ${exception.reason} '
            '[approved ${exception.approved}]',
          );
        }
        return exitSuccess;
    }
  }
}
