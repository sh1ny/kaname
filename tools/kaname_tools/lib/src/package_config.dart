import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'file_system.dart';

/// Repository-relative path of the resolved package config.
const String packageConfigPath = '.dart_tool/package_config.json';

/// The package config is missing, unreadable or does not have the expected
/// shape.
final class PackageConfigException implements Exception {
  /// Creates an exception explaining what is wrong.
  const PackageConfigException(this.message);

  /// What is wrong, naming [packageConfigPath].
  final String message;

  @override
  String toString() => message;
}

/// Maps each package name in [packageConfigPath] to the directory holding
/// its files.
///
/// A root URI in the package config is either absolute (`file:///...`,
/// returned as an absolute path) or relative to the `.dart_tool` directory
/// that holds the config (returned repository-relative; the root itself is
/// the empty string). Throws a [PackageConfigException] when the file cannot
/// be read or parsed; callers check that it exists first.
Map<String, String> readPackageRoots(FileSystem fileSystem) {
  final Object? document;
  try {
    document = jsonDecode(fileSystem.readAsString(packageConfigPath));
  } on FormatException catch (e) {
    throw PackageConfigException(
      '$packageConfigPath is not valid JSON: ${e.message}',
    );
  } on FileSystemException catch (e) {
    throw PackageConfigException(
      '$packageConfigPath cannot be read: ${e.message}',
    );
  }
  if (document case {'packages': final List<Object?> packages}) {
    final roots = <String, String>{};
    for (final entry in packages) {
      if (entry case {'name': final String name, 'rootUri': final String uri}) {
        roots[name] = _rootPath(uri);
      } else {
        throw PackageConfigException(
          '$packageConfigPath: entry without name and rootUri: $entry',
        );
      }
    }
    return roots;
  }
  throw const PackageConfigException('$packageConfigPath has no packages list');
}

String _rootPath(String rootUri) {
  final uri = Uri.parse(rootUri);
  if (!uri.hasScheme) {
    final relative = p.posix.normalize(
      p.posix.join('.dart_tool', Uri.decodeComponent(uri.path)),
    );
    return relative == '.' ? '' : relative;
  }
  if (uri.scheme != 'file') {
    throw PackageConfigException(
      '$packageConfigPath: unsupported root URI "$rootUri"',
    );
  }
  final path = uri.toFilePath(windows: false);
  return path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
}
