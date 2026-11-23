/// Generating the typed ESI client from the pinned snapshot (design D12 of
/// `esi-client-generator`).
library;

import 'esi_pin.dart';
import 'esi_render.dart';
import 'esi_spec.dart';
import 'file_system.dart';

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

/// The generated `.dart` files on disk, by name inside
/// [esiGeneratedDirectory]; none when the directory does not exist.
List<String> existingEsiGeneratedFiles(FileSystem fileSystem) =>
    fileSystem.kindOf(esiGeneratedDirectory) == FsEntryKind.directory
    ? [
        for (final entry in fileSystem.list(esiGeneratedDirectory))
          if (entry.kind == FsEntryKind.file && entry.name.endsWith('.dart'))
            entry.name,
      ]
    : const [];

/// What [writeEsiGeneratedFiles] changed.
typedef EsiWriteReport = ({List<String> written, List<String> removed});

/// Writes [files] into [esiGeneratedDirectory], skipping files whose text
/// is already current, and removes generated files no longer rendered.
EsiWriteReport writeEsiGeneratedFiles(
  FileSystem fileSystem,
  Map<String, String> files,
) {
  final existing = existingEsiGeneratedFiles(fileSystem);
  final written = <String>[];
  for (final MapEntry(key: name, value: text) in files.entries) {
    final path = '$esiGeneratedDirectory/$name';
    if (existing.contains(name) && fileSystem.readAsString(path) == text) {
      continue;
    }
    fileSystem.writeAsString(path, text);
    written.add(name);
  }
  final removed = [
    for (final name in existing)
      if (!files.containsKey(name)) name,
  ]..sort();
  for (final name in removed) {
    fileSystem.delete('$esiGeneratedDirectory/$name');
  }
  return (written: written, removed: removed);
}
