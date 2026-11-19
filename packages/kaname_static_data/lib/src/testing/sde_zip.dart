/// Builds synthetic JSON Lines zips for tests.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Encodes a zip with one entry per file; each file is its lines joined by
/// line breaks, with a final one.
///
/// A line is a JSON-encodable value, or a [String] that is written as is
/// when wrapped in [RawLine] (to build invalid JSON lines).
Uint8List buildZip(Map<String, List<Object?>> files) {
  final archive = Archive();
  for (final MapEntry(:key, :value) in files.entries) {
    final text = StringBuffer();
    for (final line in value) {
      text
        ..write(line is RawLine ? line.text : jsonEncode(line))
        ..write('\n');
    }
    final bytes = utf8.encode(text.toString());
    archive.add(ArchiveFile(key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Encodes a zip with one entry per file, each holding the given bytes.
Uint8List buildZipBytes(Map<String, List<int>> files) {
  final archive = Archive();
  for (final MapEntry(:key, :value) in files.entries) {
    archive.add(ArchiveFile(key, value.length, value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// A line written to a file as is, without JSON encoding.
final class RawLine {
  /// Creates a raw line.
  const RawLine(this.text);

  /// The text of the line.
  final String text;
}

/// Writes [bytes] to a new file named [name] in [dir] and returns it.
File writeFile(Directory dir, String name, List<int> bytes) =>
    File(p.join(dir.path, name))..writeAsBytesSync(bytes);
