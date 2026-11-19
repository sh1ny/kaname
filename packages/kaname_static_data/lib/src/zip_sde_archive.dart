/// Reads an SDE build from a zip file on disk.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'sde_limits.dart';
import 'sde_source.dart';

/// An [SdeArchive] over a zip file, unpacking one entry at a time.
///
/// Opening reads only the zip's central directory. An entry is unpacked into
/// the working directory when its [lines] are read, and deleted when they
/// have been consumed. Each entry's declared unpacked size is checked against
/// [SdeLimits.maxEntryBytes], and the sum of all of them against
/// [SdeLimits.maxTotalBytes], before anything is unpacked; the decoder itself
/// stops an entry at its declared size, so a zip that lies about a size
/// cannot grow past the check.
final class ZipSdeArchive implements SdeArchive {
  ZipSdeArchive._(
    this._input,
    this._entries,
    this._workDir,
    this._limits,
    this._sourceName,
  );

  /// Opens [zipFile] and lists its entries.
  ///
  /// [workDir] must exist and is owned by the archive: entries are unpacked
  /// into it and it is deleted, with everything in it, on [close] or when
  /// opening fails. [zipFile] may live inside [workDir].
  ///
  /// Throws an [SdeSourceException] naming [sourceName] when the zip cannot
  /// be read or its entries are larger than [limits] allow.
  static Future<ZipSdeArchive> open({
    required File zipFile,
    required Directory workDir,
    required SdeLimits limits,
    required String sourceName,
  }) async {
    InputFileStream? input;
    try {
      input = InputFileStream(zipFile.path);
      final archive = ZipDecoder().decodeStream(input, verify: true);
      final entries = <String, ArchiveFile>{};
      var declaredTotal = 0;
      for (final entry in archive) {
        if (!entry.isFile || !_isTopLevelJsonl(entry.name)) continue;
        if (entry.size > limits.maxEntryBytes) {
          throw SdeSourceException(
            '$sourceName entry ${entry.name} exceeds '
            '${SdeLimits.describeBytes(limits.maxEntryBytes)} unpacked',
          );
        }
        declaredTotal += entry.size;
        entries[entry.name] = entry;
      }
      if (declaredTotal > limits.maxTotalBytes) {
        throw SdeSourceException(
          '$sourceName entries exceed '
          '${SdeLimits.describeBytes(limits.maxTotalBytes)} unpacked',
        );
      }
      return ZipSdeArchive._(input, entries, workDir, limits, sourceName);
    } on Object catch (error) {
      try {
        input?.closeSync();
      } on Object {
        // Closing a broken file is best effort.
      }
      await _deleteQuietly(workDir);
      if (error is SdeSourceException) rethrow;
      throw SdeSourceException(
        '$sourceName cannot be read: ${describeFailure(error)}',
      );
    }
  }

  final InputFileStream _input;
  final Map<String, ArchiveFile> _entries;
  final Directory _workDir;
  final SdeLimits _limits;
  final String _sourceName;
  int _unpackedTotal = 0;

  static bool _isTopLevelJsonl(String name) =>
      !name.contains('/') && !name.contains(r'\') && name.endsWith('.jsonl');

  @override
  List<String> get fileNames => _entries.keys.toList()..sort();

  @override
  Stream<SdeLine> lines(String fileName) async* {
    final entry = _entries[fileName];
    if (entry == null) {
      throw ArgumentError.value(fileName, 'fileName', 'not in this archive');
    }
    final unpacked = File(p.join(_workDir.path, 'unpacked', fileName));
    try {
      _unpack(entry, unpacked);
      yield* _readLines(unpacked);
    } finally {
      try {
        if (unpacked.existsSync()) unpacked.deleteSync();
      } on FileSystemException {
        // The working directory is deleted on close anyway.
      }
    }
  }

  void _unpack(ArchiveFile entry, File target) {
    if (_unpackedTotal + entry.size > _limits.maxTotalBytes) {
      throw SdeSourceException(
        '$_sourceName entries exceed '
        '${SdeLimits.describeBytes(_limits.maxTotalBytes)} unpacked',
      );
    }
    OutputFileStream? output;
    try {
      output = OutputFileStream(target.path);
      entry.writeContent(output);
      _unpackedTotal += output.length;
    } on SdeSourceException {
      rethrow;
    } on Object catch (error) {
      throw SdeSourceException(
        '$_sourceName entry ${entry.name} cannot be unpacked: '
        '${describeFailure(error)}',
      );
    } finally {
      output?.closeSync();
    }
  }

  Stream<SdeLine> _readLines(File file) async* {
    final max = _limits.maxLineBytes;
    final line = BytesBuilder(copy: false);
    var lineNumber = 1;
    var oversized = false;
    var first = true;

    SdeLine? finish() {
      final number = lineNumber++;
      var bytes = line.takeBytes();
      final tooLong = oversized;
      oversized = false;
      if (tooLong) {
        return SdeUnreadableLine(
          number,
          'line exceeds ${SdeLimits.describeBytes(max)}',
        );
      }
      if (first) {
        first = false;
        if (bytes.length >= 3 &&
            bytes[0] == 0xEF &&
            bytes[1] == 0xBB &&
            bytes[2] == 0xBF) {
          bytes = Uint8List.sublistView(bytes, 3);
        }
      }
      var end = bytes.length;
      if (end > 0 && bytes[end - 1] == 13) end--;
      final trimmed = Uint8List.sublistView(bytes, 0, end);
      if (trimmed.every(_isBlank)) return null;
      try {
        return SdeTextLine(number, utf8.decode(trimmed));
      } on FormatException {
        return SdeUnreadableLine(number, 'invalid UTF-8');
      }
    }

    try {
      await for (final chunk in file.openRead()) {
        var start = 0;
        while (start < chunk.length) {
          final newline = chunk.indexOf(10, start);
          final end = newline < 0 ? chunk.length : newline;
          if (!oversized) {
            if (line.length + (end - start) > max) {
              oversized = true;
              line.clear();
            } else {
              line.add(chunk.sublist(start, end));
            }
          }
          if (newline < 0) break;
          final done = finish();
          if (done != null) yield done;
          start = newline + 1;
        }
      }
      if (line.length > 0 || oversized) {
        final done = finish();
        if (done != null) yield done;
      }
    } on FileSystemException catch (error) {
      throw SdeSourceException(
        '$_sourceName entry cannot be read: ${describeFailure(error)}',
      );
    }
  }

  static bool _isBlank(int byte) =>
      byte == 32 || byte == 9 || byte == 13 || byte == 10;

  @override
  Future<void> close() async {
    try {
      _input.closeSync();
    } on Object {
      // Closing a broken file is best effort.
    }
    for (final entry in _entries.values) {
      try {
        entry.closeSync();
      } on Object {
        // Entry handles share the input; nothing more to free.
      }
    }
    await _deleteQuietly(_workDir);
  }
}

/// Describes [error] for a failure reason without leaking local paths.
///
/// A [FileSystemException] contributes its message and the operating
/// system's, never its path.
String describeFailure(Object error) {
  final text = switch (error) {
    FileSystemException(:final message, :final osError) =>
      osError == null ? message : '$message (${osError.message})',
    ArchiveException(:final message) => message,
    FormatException(:final message) => message,
    _ => error.toString(),
  };
  return text.length > 300 ? '${text.substring(0, 300)}...' : text;
}

Future<void> _deleteQuietly(Directory dir) async {
  try {
    if (dir.existsSync()) await dir.delete(recursive: true);
  } on FileSystemException {
    // Best effort: a leftover temp directory must not hide the real error.
  }
}
