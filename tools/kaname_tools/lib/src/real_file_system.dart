import 'dart:io';

import 'package:path/path.dart' as p;

import 'file_system.dart';
import 'pubspec.dart';

/// A [FileSystem] over the real disk, rooted at the repository root.
final class RealFileSystem implements FileSystem {
  /// Creates a file system rooted at the directory [root].
  RealFileSystem(this.root);

  /// Finds the repository root by walking up from [start].
  ///
  /// The root is the nearest directory whose `pubspec.yaml` has a
  /// `workspace:` key. Returns `null` when there is none.
  static RealFileSystem? locate(String start) {
    var directory = p.absolute(start);
    while (true) {
      final pubspec = File(p.join(directory, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        try {
          if (Pubspec.parse(pubspec.readAsStringSync()).workspace.isNotEmpty) {
            return RealFileSystem(directory);
          }
        } on FormatException {
          // Not a workspace root; keep walking up.
        }
      }
      final parent = p.dirname(directory);
      if (parent == directory) return null;
      directory = parent;
    }
  }

  /// The absolute path of the repository root.
  final String root;

  String _absolute(String path) =>
      path.isEmpty ? root : p.joinAll([root, ...p.posix.split(path)]);

  @override
  FsEntryKind? kindOf(String path) =>
      switch (FileSystemEntity.typeSync(_absolute(path), followLinks: false)) {
        FileSystemEntityType.file => FsEntryKind.file,
        FileSystemEntityType.directory => FsEntryKind.directory,
        FileSystemEntityType.link => FsEntryKind.link,
        _ => null,
      };

  @override
  List<FsEntry> list(String directory) => [
    for (final entity in Directory(
      _absolute(directory),
    ).listSync(followLinks: false))
      if (kindOf(p.posix.join(directory, p.basename(entity.path)))
          case final FsEntryKind kind)
        FsEntry(p.basename(entity.path), kind),
  ];

  @override
  String readAsString(String path) => File(_absolute(path)).readAsStringSync();
}
