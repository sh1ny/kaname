import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'file_system.dart';
import 'package_config.dart';

/// Repository-relative path of the root lockfile.
const String lockPath = 'pubspec.lock';

/// What to do when the workspace is not resolved.
const String resolveHint = 'run `mise run resolve` first';

/// The file names, in order of preference, that hold a package's licence.
const List<String> licenceFileNames = [
  'LICENSE',
  'LICENSE.md',
  'LICENSE.txt',
  'COPYING',
];

/// A package from the root `pubspec.lock`.
final class LockedPackage {
  /// Creates a locked package.
  const LockedPackage(this.name, this.version, this.source, {this.sha256});

  /// The package name.
  final String name;

  /// The locked version.
  final String version;

  /// The lockfile source: `hosted`, `sdk`, `git` or `path`.
  final String source;

  /// The lockfile's SHA-256 of the package archive, in hex, when it records
  /// one (hosted packages).
  final String? sha256;
}

/// The lockfile, the package config or a package's licence file cannot be
/// used.
///
/// Both the notices and the licence checks catch it and report [message].
class WorkspaceReadException implements Exception {
  /// Creates an exception explaining what is wrong.
  const WorkspaceReadException(this.message);

  /// What is wrong, naming the file or package concerned.
  final String message;

  @override
  String toString() => message;
}

/// A package has no licence file in its directory.
final class NoLicenceFileException extends WorkspaceReadException {
  /// Creates the exception with its [message].
  const NoLicenceFileException(super.message);
}

/// Reads the packages of the root lockfile, in lockfile order.
///
/// Throws a [WorkspaceReadException] when the lockfile is missing, is not
/// YAML or has a package without a string source and version.
List<LockedPackage> readLockedPackages(FileSystem fileSystem) {
  if (fileSystem.kindOf(lockPath) != FsEntryKind.file) {
    throw const WorkspaceReadException('$lockPath not found; $resolveHint');
  }
  final Object? document;
  try {
    document = loadYaml(fileSystem.readAsString(lockPath));
  } on YamlException catch (e) {
    throw WorkspaceReadException('$lockPath is not valid YAML: ${e.message}');
  } on FileSystemException catch (e) {
    throw WorkspaceReadException('$lockPath cannot be read: ${e.message}');
  }
  if (document case {'packages': final Map<Object?, Object?> packages}) {
    return [
      for (final MapEntry(:key, :value) in packages.entries)
        switch ((key, value)) {
          (
            final String name,
            final Map<Object?, Object?> entry &&
                {
                  'source': final String source,
                  'version': final String version,
                },
          ) =>
            LockedPackage(
              name,
              version,
              source,
              sha256: switch (entry['description']) {
                {'sha256': final String hash} => hash,
                _ => null,
              },
            ),
          _ => throw WorkspaceReadException(
            '$lockPath: package "$key" has no string source and version',
          ),
        },
    ];
  }
  throw const WorkspaceReadException('$lockPath has no packages: map');
}

/// Maps each package name to the directory holding its files.
///
/// Throws a [WorkspaceReadException] naming [resolveHint] when the package
/// config does not exist, and one naming the config when it cannot be read.
Map<String, String> readResolvedPackageRoots(FileSystem fileSystem) {
  if (fileSystem.kindOf(packageConfigPath) != FsEntryKind.file) {
    throw const WorkspaceReadException(
      '$packageConfigPath not found: the workspace is not resolved; '
      '$resolveHint',
    );
  }
  try {
    return readPackageRoots(fileSystem);
  } on PackageConfigException catch (e) {
    throw WorkspaceReadException(e.message);
  }
}

/// Reads the normalised licence text of package [name] at [version] from
/// its directory [root] (`null` when the package config does not list it).
///
/// The licence file is the first of [licenceFileNames] (compared without
/// regard to case; ties broken by name) in [root]. Throws a
/// [NoLicenceFileException] when there is none, and a
/// [WorkspaceReadException] when the directory is missing or the file is
/// empty, not UTF-8 or unreadable.
String readLicenceText(
  FileSystem fileSystem,
  String name,
  String version,
  String? root,
) {
  if (root == null || fileSystem.kindOf(root) != FsEntryKind.directory) {
    throw WorkspaceReadException(
      'package $name $version: its directory is not in '
      '$packageConfigPath or does not exist; $resolveHint',
    );
  }
  final entries = fileSystem.list(root)
    ..sort((a, b) => a.name.compareTo(b.name));
  for (final candidate in licenceFileNames) {
    for (final FsEntry(name: file, :kind) in entries) {
      if (kind == FsEntryKind.directory ||
          file.toLowerCase() != candidate.toLowerCase()) {
        continue;
      }
      final String raw;
      try {
        raw = fileSystem.readAsString(p.posix.join(root, file));
      } on FileSystemException catch (e) {
        throw WorkspaceReadException(
          'package $name $version: licence file $file cannot be read: '
          '${e.message}',
        );
      } on FormatException catch (e) {
        throw WorkspaceReadException(
          'package $name $version: licence file $file is not UTF-8: '
          '${e.message}',
        );
      }
      final text = normaliseLicence(raw);
      if (text.isEmpty) {
        throw WorkspaceReadException(
          'package $name $version: licence file $file is empty',
        );
      }
      return text;
    }
  }
  throw NoLicenceFileException(
    'package $name $version: no licence file '
    '(${licenceFileNames.join(', ')}) in its package directory',
  );
}

/// Normalises licence [raw] text.
///
/// A leading byte-order mark is dropped, `CRLF` and lone `CR` become `LF`,
/// trailing whitespace is stripped from every line (as [String.trimRight]
/// defines it), and leading and trailing blank lines are removed. Nothing
/// else changes.
String normaliseLicence(String raw) {
  final withoutBom = raw.startsWith('﻿') ? raw.substring(1) : raw;
  final lines = [
    for (final line
        in withoutBom
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n')
            .split('\n'))
      line.trimRight(),
  ];
  while (lines.isNotEmpty && lines.first.isEmpty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines.join('\n');
}
