/// Generating the typed ESI client from the pinned snapshot (design D12 of
/// `esi-client-generator`).
library;

import 'dart:io' show Directory, FileSystemException;

import 'esi_pin.dart';
import 'esi_render.dart';
import 'esi_spec.dart';
import 'file_system.dart';
import 'real_file_system.dart';

/// What [renderPinnedEsiClient] produced.
sealed class EsiGeneration {
  const EsiGeneration();
}

/// Every generated file for the pinned snapshot, rendered in memory.
final class EsiGenerationReady extends EsiGeneration {
  /// Creates the result for [pin] with [files].
  const EsiGenerationReady(this.pin, this.files);

  /// The pin the snapshot matched.
  final EsiPin pin;

  /// Each file's text by its name inside [esiGeneratedDirectory].
  final Map<String, String> files;
}

/// Nothing can be generated; nothing may be written.
final class EsiGenerationRefused extends EsiGeneration {
  /// Creates a refusal listing [problems].
  const EsiGenerationRefused(this.problems);

  /// Why, naming the file, field, date, construct or name at fault.
  final List<String> problems;
}

/// Checks the pin and the snapshot's hash and dates, reads the snapshot and
/// renders every generated file in memory, without network access.
EsiGeneration renderPinnedEsiClient(FileSystem fileSystem) {
  final EsiPin pin;
  final Object? document;
  switch (loadEsiSnapshot(fileSystem)) {
    case EsiSnapshotRefused(:final problems):
      return EsiGenerationRefused(problems);
    case EsiSnapshotLoaded(pin: final loadedPin, document: final loaded):
      pin = loadedPin;
      document = loaded;
  }
  final EsiSpec spec;
  switch (const EsiSpecReader().read(document)) {
    case EsiSpecRefused(:final path, :final reason):
      return EsiGenerationRefused([
        '$esiSnapshotPath cannot be generated: $reason at $path',
      ]);
    case EsiSpecRead(spec: final read):
      spec = read;
  }
  return switch (renderEsiClient(spec, date: pin.date)) {
    EsiRendered(:final files) => EsiGenerationReady(pin, files),
    EsiRenderRefused(:final reason) => EsiGenerationRefused([
      '$esiSnapshotPath cannot be generated: $reason',
    ]),
  };
}

/// The generated `.dart` files on disk, by repository-relative path, in
/// every directory of [esiGeneratedDirectories] that exists.
List<String> existingEsiGeneratedFiles(FileSystem fileSystem) => [
  for (final directory in esiGeneratedDirectories)
    if (fileSystem.kindOf(directory) == FsEntryKind.directory)
      for (final entry in fileSystem.list(directory))
        if (entry.kind == FsEntryKind.file && entry.name.endsWith('.dart'))
          '$directory/${entry.name}',
];

/// What [writeEsiGeneratedFiles] changed.
typedef EsiWriteReport = ({List<String> written, List<String> removed});

/// Writes [files], keyed by repository-relative path, skipping files whose
/// text is already current, and removes generated files no longer
/// rendered.
EsiWriteReport writeEsiGeneratedFiles(
  FileSystem fileSystem,
  Map<String, String> files,
) {
  final existing = existingEsiGeneratedFiles(fileSystem);
  final written = <String>[];
  for (final MapEntry(key: path, value: text) in files.entries) {
    if (existing.contains(path) && fileSystem.readAsString(path) == text) {
      continue;
    }
    fileSystem.writeAsString(path, text);
    written.add(path);
  }
  final removed = [
    for (final name in existing)
      if (!files.containsKey(name)) name,
  ]..sort();
  removed.forEach(fileSystem.delete);
  return (written: written, removed: removed);
}

/// A temporary directory the drift check regenerates into, outside the
/// repository.
abstract interface class EsiScratch {
  /// Runs [body] over a fresh, empty temporary file system and removes it
  /// afterwards. Raises [FileSystemException] when none can be made.
  T use<T>(T Function(FileSystem scratch) body);
}

/// A scratch file system for runs without one: every use fails.
final class NoEsiScratch implements EsiScratch {
  /// Creates the scratch.
  const NoEsiScratch();

  @override
  T use<T>(T Function(FileSystem scratch) body) =>
      throw const FileSystemException('this run has no temporary directory');
}

/// A system temporary directory, deleted after each use.
final class TempDirectoryEsiScratch implements EsiScratch {
  /// Creates the scratch.
  const TempDirectoryEsiScratch();

  @override
  T use<T>(T Function(FileSystem scratch) body) {
    final directory = Directory.systemTemp.createTempSync('kaname_esi_');
    try {
      return body(RealFileSystem(directory.path));
    } finally {
      directory.deleteSync(recursive: true);
    }
  }
}

/// Regenerates the client into [scratch] and lists how the committed
/// output in [fileSystem] differs from it: missing, extra and differing
/// files, or why nothing could be generated. Writes nothing in
/// [fileSystem].
({EsiPin? pin, int files, List<String> problems}) checkEsiGenerated(
  FileSystem fileSystem,
  EsiScratch scratch,
) {
  final Map<String, String> generated;
  final EsiPin pin;
  switch (renderPinnedEsiClient(fileSystem)) {
    case EsiGenerationRefused(:final problems):
      return (pin: null, files: 0, problems: problems);
    case EsiGenerationReady(pin: final ready, :final files):
      pin = ready;
      try {
        generated = scratch.use((temporary) {
          writeEsiGeneratedFiles(temporary, files);
          return {
            for (final path in existingEsiGeneratedFiles(temporary))
              path: temporary.readAsString(path),
          };
        });
      } on FileSystemException catch (e) {
        return (
          pin: pin,
          files: 0,
          problems: ['the temporary directory cannot be written: $e'],
        );
      }
  }
  final committed = existingEsiGeneratedFiles(fileSystem);
  final problems = <String>[
    for (final path in generated.keys.toList()..sort())
      if (!committed.contains(path))
        '$path is missing'
      else if (fileSystem.readAsString(path) != generated[path])
        '$path differs from what the pinned snapshot generates',
    for (final path in committed.toList()..sort())
      if (!generated.containsKey(path))
        '$path is not generated from the pinned snapshot',
  ];
  if (problems.isNotEmpty) {
    problems.add(
      'Run `mise run esi:generate` and commit the result; never edit '
      'generated files by hand.',
    );
  }
  return (pin: pin, files: generated.length, problems: problems);
}
