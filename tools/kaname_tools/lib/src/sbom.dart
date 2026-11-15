import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import 'cli.dart';
import 'file_system.dart';
import 'licence_matcher.dart';
import 'licences.dart';

/// The SDK file whose text covers `sky_engine`'s bundled components.
const String engineBundleLicenceFile = 'bin/cache/pkg/sky_engine/LICENSE';

/// The name of the application the SBOM describes.
const String sbomApplicationName = 'kaname_workspace';

/// Builds the CycloneDX 1.6 SBOM of the root lockfile from [packages].
///
/// The document is a JSON object with its keys in a fixed order, indented by
/// two spaces and ended by a newline. It carries no `serialNumber` and no
/// `metadata.timestamp`, so the same lockfile always gives the same bytes.
///
/// Each package is a `library` component, in the order of [packages] (the
/// lockfile order by name that [classifyLockedPackages] returns), with:
///
/// - `bom-ref` and `purl`, both `pkg:pub/<name>@<version>`;
/// - `licenses`, from the classification: an SPDX `id`, or a `name` for a
///   `LicenseRef-` reference. A package with an unrecognised licence, no
///   licence file or an unreadable one has none;
/// - `hashes`, the lockfile SHA-256, when the lockfile records one;
/// - `properties`, `kaname:source` (the lockfile source), and for
///   `sky_engine` `kaname:licence-file` naming [engineBundleLicenceFile].
///
/// The SBOM describes what the classification found; it does not apply the
/// licence policy. CI runs the licence check first.
String buildSbom(List<ClassifiedPackage> packages) {
  final document = <String, Object?>{
    'bomFormat': 'CycloneDX',
    'specVersion': '1.6',
    'version': 1,
    'metadata': {
      'component': {
        'type': 'application',
        'bom-ref': sbomApplicationName,
        'name': sbomApplicationName,
      },
    },
    'components': [
      for (final ClassifiedPackage(:package, :licence) in packages)
        {
          'type': 'library',
          'bom-ref': 'pkg:pub/${package.name}@${package.version}',
          'name': package.name,
          'version': package.version,
          'purl': 'pkg:pub/${package.name}@${package.version}',
          if (switch (licence) {
                FoundLicence(classification: KnownLicence(:final id)) =>
                  _licenceEntry(id),
                _ => null,
              }
              case final entry?)
            'licenses': [entry],
          if (package.sha256 case final hash?)
            'hashes': [
              {'alg': 'SHA-256', 'content': hash},
            ],
          'properties': [
            {'name': 'kaname:source', 'value': package.source},
            if (package.source == 'sdk' && package.name == 'sky_engine')
              {'name': 'kaname:licence-file', 'value': engineBundleLicenceFile},
          ],
        },
    ],
  };
  return '${const JsonEncoder.withIndent('  ').convert(document)}\n';
}

Map<String, Object?> _licenceEntry(String id) => {
  'license': licenceTemplateFor(id) == null ? {'name': id} : {'id': id},
};

/// Writes [content] to [path] through a temporary file and a rename, so an
/// interrupted run leaves the old file whole.
void _writeAtomically(FileSystem fileSystem, String path, String content) {
  final temporary = '$path.tmp';
  try {
    fileSystem.writeAsString(temporary, content);
    fileSystem.rename(temporary, path);
  } finally {
    if (fileSystem.kindOf(temporary) != null) {
      try {
        fileSystem.delete(temporary);
      } on FileSystemException {
        // Nothing more can be done; the target file is intact.
      }
    }
  }
}

/// The `sbom` command: writes a CycloneDX SBOM of the locked packages.
final class SbomCommand extends Command<int> {
  /// Creates the command over [_fileSystem], writing to [_output].
  SbomCommand(this._fileSystem, this._output) {
    argParser.addOption(
      'output',
      valueHelp: 'path',
      help:
          'Repository-relative file to write; missing directories are '
          'created.',
    );
  }

  final FileSystem _fileSystem;
  final CliOutput _output;

  @override
  String get name => 'sbom';

  @override
  String get description =>
      'Write a CycloneDX 1.6 JSON SBOM of pubspec.lock to --output.';

  @override
  int run() {
    final path = argResults!.option('output');
    if (path == null || path.isEmpty) usageException('Pass --output <path>.');
    switch (classifyLockedPackages(_fileSystem)) {
      case NotClassified(:final problem):
        _output.err.writeln(problem);
        return exitCheckFailed;
      case Classified(:final packages):
        try {
          _writeAtomically(_fileSystem, path, buildSbom(packages));
        } on FileSystemException catch (e) {
          _output.err.writeln('$path cannot be written: ${e.message}');
          return exitCheckFailed;
        }
        _output.out.writeln('$path written: ${packages.length} packages');
        return exitSuccess;
    }
  }
}
