import 'dart:convert';
import 'dart:io';

import 'package:kaname_tools/kaname_tools.dart';
import 'package:path/path.dart' as p;

/// A [FileSystem] held in memory for tests.
///
/// Models symbolic links: [addLink] makes a path that reports
/// [FsEntryKind.link] but, like a real link, exposes its target's contents
/// to anyone who follows it. A check that wrongly follows links therefore
/// sees the target's files.
final class InMemoryFileSystem implements FileSystem {
  final Map<String, String> _files = {};
  final Map<String, String> _links = {};

  /// How many times [writeAsString] and [rename] changed the file system.
  int writeCount = 0;

  /// Every file path, sorted.
  List<String> get filePaths => _files.keys.toList()..sort();

  /// Creates or replaces the file at [path] with [content].
  void writeFile(String path, [String content = '']) => _files[path] = content;

  /// Deletes the file at [path].
  void deleteFile(String path) => _files.remove(path);

  /// Makes [path] a symbolic link to the directory or file [target].
  void addLink(String path, {required String target}) => _links[path] = target;

  String _resolve(String path) {
    for (final MapEntry(key: link, value: target) in _links.entries) {
      if (path == link) return target;
      if (path.startsWith('$link/')) {
        return p.posix.join(target, path.substring(link.length + 1));
      }
    }
    return path;
  }

  bool _isDirectory(String path) {
    final prefix = path.isEmpty ? '' : '$path/';
    return path.isEmpty ||
        _files.keys.any((file) => file.startsWith(prefix)) ||
        _links.keys.any((link) => link.startsWith(prefix));
  }

  @override
  FsEntryKind? kindOf(String path) {
    if (_links.containsKey(path)) return FsEntryKind.link;
    final resolved = _resolve(path);
    if (_files.containsKey(resolved)) return FsEntryKind.file;
    if (_isDirectory(resolved)) return FsEntryKind.directory;
    return null;
  }

  @override
  List<FsEntry> list(String directory) {
    final resolved = _resolve(directory);
    if (!_isDirectory(resolved)) {
      throw FileSystemException('not a directory', directory);
    }
    final prefix = resolved.isEmpty ? '' : '$resolved/';
    final names = <String>{
      for (final path in [..._files.keys, ..._links.keys])
        if (path.startsWith(prefix))
          path.substring(prefix.length).split('/')[0],
    };
    return [
      for (final name in names)
        FsEntry(name, kindOf(p.posix.join(directory, name))!),
    ];
  }

  @override
  String readAsString(String path) =>
      _files[_resolve(path)] ?? (throw FileSystemException('no file', path));

  @override
  List<int> readAsBytes(String path) => utf8.encode(readAsString(path));

  @override
  void writeAsString(String path, String content) {
    writeCount++;
    _files[_resolve(path)] = content;
  }

  @override
  void rename(String from, String to) {
    writeCount++;
    final content =
        _files.remove(_resolve(from)) ??
        (throw FileSystemException('no file', from));
    _files[_resolve(to)] = content;
  }

  @override
  void delete(String path) {
    if (_files.remove(_resolve(path)) == null) {
      throw FileSystemException('no file', path);
    }
  }
}
