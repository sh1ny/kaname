import 'dart:io';

import 'package:yaml/yaml.dart';

import 'file_system.dart';

/// The pubspec sections that declare dependencies.
enum DependencySection {
  /// `dependencies:`.
  dependencies('dependencies'),

  /// `dev_dependencies:`.
  devDependencies('dev_dependencies'),

  /// `dependency_overrides:`.
  dependencyOverrides('dependency_overrides');

  const DependencySection(this.key);

  /// The YAML key of the section.
  final String key;
}

/// A dependency declared in a pubspec.
final class Dependency {
  /// Creates a dependency on [name] declared in [section].
  const Dependency(this.name, this.section, {this.sdk});

  /// The depended-on package name.
  final String name;

  /// The section that declares it.
  final DependencySection section;

  /// The SDK the dependency comes from (`flutter`), or `null` for hosted,
  /// git and path dependencies.
  final String? sdk;
}

/// A pubspec that is missing, unreadable or does not have the expected shape.
final class PubspecException implements Exception {
  /// Creates an exception for the pubspec at [path].
  const PubspecException(this.path, this.message);

  /// Repository-relative path of the offending file.
  final String path;

  /// What is wrong with it.
  final String message;

  @override
  String toString() => '$path: $message';
}

/// The parts of a `pubspec.yaml` the repository checks care about.
final class Pubspec {
  /// Creates a pubspec value.
  const Pubspec({
    required this.name,
    this.resolution,
    this.workspace = const [],
    this.dependencies = const [],
  });

  /// Parses pubspec [source] text.
  ///
  /// Throws a [FormatException] when the YAML is invalid or a field has the
  /// wrong type.
  factory Pubspec.parse(String source) {
    final Object? document;
    try {
      document = loadYaml(source);
    } on YamlException catch (e) {
      throw FormatException(e.message);
    }
    if (document is! Map) {
      throw const FormatException('expected a YAML mapping');
    }
    final map = document.cast<Object?, Object?>();
    return Pubspec(
      name: switch (map['name']) {
        final String name when name.isNotEmpty => name,
        _ => throw const FormatException('missing or invalid "name"'),
      },
      resolution: switch (map['resolution']) {
        null => null,
        final String resolution => resolution,
        _ => throw const FormatException('"resolution" must be a string'),
      },
      workspace: switch (map['workspace']) {
        null => const [],
        final List<Object?> entries => [
          for (final entry in entries)
            switch (entry) {
              final String path => path,
              _ => throw const FormatException(
                '"workspace" entries must be strings',
              ),
            },
        ],
        _ => throw const FormatException('"workspace" must be a list'),
      },
      dependencies: [
        for (final section in DependencySection.values)
          ..._parseSection(section, map[section.key]),
      ],
    );
  }

  /// Reads and parses the pubspec at [path] through [fileSystem].
  ///
  /// Throws a [PubspecException] naming [path] when it cannot be read or
  /// parsed.
  factory Pubspec.load(FileSystem fileSystem, String path) {
    try {
      return Pubspec.parse(fileSystem.readAsString(path));
    } on FileSystemException {
      throw PubspecException(path, 'cannot be read');
    } on FormatException catch (e) {
      throw PubspecException(path, 'is not a valid pubspec: ${e.message}');
    }
  }

  /// The package name.
  final String name;

  /// The `resolution:` value, `workspace` for workspace members.
  final String? resolution;

  /// The `workspace:` member paths; empty unless this is a workspace root.
  final List<String> workspace;

  /// Every dependency across all dependency sections.
  final List<Dependency> dependencies;

  static List<Dependency> _parseSection(
    DependencySection section,
    Object? raw,
  ) => switch (raw) {
    null => const [],
    final Map<Object?, Object?> entries => [
      for (final MapEntry(:key, :value) in entries.entries)
        Dependency(
          switch (key) {
            final String name => name,
            _ => throw FormatException('"${section.key}" keys must be strings'),
          },
          section,
          sdk: switch (value) {
            {'sdk': final String sdk} => sdk,
            _ => null,
          },
        ),
    ],
    _ => throw FormatException('"${section.key}" must be a mapping'),
  };
}
