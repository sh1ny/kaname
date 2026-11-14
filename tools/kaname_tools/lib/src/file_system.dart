/// What a directory entry is, without following symbolic links.
enum FsEntryKind {
  /// A regular file.
  file,

  /// A directory.
  directory,

  /// A symbolic link, whatever it points to.
  link,
}

/// One entry returned by [FileSystem.list].
final class FsEntry {
  /// Creates an entry called [name] of the given [kind].
  const FsEntry(this.name, this.kind);

  /// The entry's file name, without its parent directory.
  final String name;

  /// What the entry is. Links are reported as [FsEntryKind.link].
  final FsEntryKind kind;
}

/// Read-only view of the repository, injected into every check.
///
/// All paths are relative to the repository root and use `/` as separator.
/// The empty string names the root itself. Implementations never follow
/// symbolic links when describing an entry, so the checks can skip them.
abstract interface class FileSystem {
  /// Describes the entry at [path], or returns `null` when nothing exists
  /// there.
  FsEntryKind? kindOf(String path);

  /// Lists the entries directly inside the directory [directory].
  List<FsEntry> list(String directory);

  /// Reads the file at [path] as UTF-8 text.
  ///
  /// Throws a `FileSystemException` when the file cannot be read.
  String readAsString(String path);
}
