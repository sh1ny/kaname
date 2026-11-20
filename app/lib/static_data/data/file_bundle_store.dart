/// The native [BundleStore]: one kept file in the app's support directory.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';
import 'package:path/path.dart' as p;

import 'bundle_store.dart';

/// A [BundleStore] keeping the bundle in use as one file in [directory].
///
/// The kept file starts with one JSON line naming the copy's build and
/// SHA-256, followed by the bundle's compressed bytes. A save writes its
/// own uniquely named temporary file next to it and renames it over the
/// kept file, so a reader in this or another app process sharing the
/// directory finds a whole old or a whole new file. Nothing here deletes
/// the kept file: an unreadable one is rejected in memory and left for the
/// next save's rename to replace (design D16). A save stopped before its
/// rename leaves its temporary file behind; [load] removes temporary files
/// older than [staleTemporaryAge], which no running save still owns.
final class FileBundleStore implements BundleStore {
  /// Creates the store over [directory], checking loads with [opener].
  ///
  /// [now] gives the time temporary files' ages are measured against.
  /// [beforeRename] runs after a save has written its temporary file and
  /// before it renames it; tests use it to stop a save there.
  FileBundleStore({
    required this.directory,
    required this._opener,
    DateTime Function()? now,
    @visibleForTesting this._beforeRename,
  }) : _now = now ?? DateTime.now;

  /// The name of the kept file in [directory].
  static const keptFileName = 'bundle.kbundle';

  /// How old a save's temporary file must be before [load] removes it.
  static const staleTemporaryAge = Duration(hours: 1);

  static const _temporaryPrefix = 'bundle.';
  static const _temporaryExtension = '.tmp';

  /// The longest header line the kept file may start with.
  static const _maxHeaderLength = 512;

  /// The directory holding the kept file and saves' temporary files.
  final Directory directory;

  final BundleOpener _opener;
  final DateTime Function() _now;
  final Future<void> Function()? _beforeRename;
  final Random _random = Random.secure();

  File get _keptFile => File(p.join(directory.path, keptFileName));

  @override
  Future<KeptBundleLoad> load() async {
    await _removeStaleTemporaryFiles();
    final Uint8List contents;
    try {
      contents = await _keptFile.readAsBytes();
    } on PathNotFoundException {
      return const NoKeptBundle();
    } on FileSystemException catch (error) {
      return KeptBundleRejected(
        CorruptBundle('the kept file cannot be read: ${error.message}'),
      );
    }
    final header = _readHeader(contents);
    if (header == null) {
      return const KeptBundleRejected(
        CorruptBundle('the kept file has no readable header'),
      );
    }
    final (identity, bundleStart) = header;
    final bytes = Uint8List.sublistView(contents, bundleStart);
    return switch (await _opener.open(bytes, identity)) {
      BundleOpened(:final bundle) => KeptBundleLoaded(
        identity: identity,
        bundle: bundle,
      ),
      BundleRefused(:final refusal) => KeptBundleRejected(refusal),
    };
  }

  @override
  Future<BundleSaveOutcome> save(BundleCopy copy) async {
    File? temporary;
    try {
      await directory.create(recursive: true);
      temporary = File(p.join(directory.path, _temporaryName()));
      final header = jsonEncode({
        'build': copy.identity.build,
        'sha256': copy.identity.sha256,
      });
      final sink = temporary.openWrite();
      try {
        sink
          ..add(utf8.encode('$header\n'))
          ..add(copy.bytes);
        await sink.flush();
      } finally {
        await sink.close();
      }
      await _beforeRename?.call();
      await temporary.rename(_keptFile.path);
      return const BundleSaved();
    } on FileSystemException catch (error) {
      // This save's own temporary file is never another process's, so it
      // is safe to remove; the kept file is not touched.
      if (temporary != null) {
        try {
          await temporary.delete();
        } on FileSystemException {
          // Already gone, or removed at a later start once stale.
        }
      }
      return BundleNotSaved('${error.message}: ${error.path}');
    }
  }

  /// A name no other save, in this or another process, writes to.
  String _temporaryName() {
    final nonce = [
      for (var i = 0; i < 8; i++)
        _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    return '$_temporaryPrefix$pid-$nonce$_temporaryExtension';
  }

  Future<void> _removeStaleTemporaryFiles() async {
    final cutoff = _now().subtract(staleTemporaryAge);
    try {
      await for (final entity in directory.list()) {
        final name = p.basename(entity.path);
        if (entity is! File ||
            !name.startsWith(_temporaryPrefix) ||
            p.extension(name) != _temporaryExtension) {
          continue;
        }
        try {
          if ((await entity.lastModified()).isBefore(cutoff)) {
            await entity.delete();
          }
        } on FileSystemException {
          // Removed meanwhile by another process's start, or in use.
        }
      }
    } on FileSystemException {
      // No directory yet, or it cannot be listed: nothing to remove.
    }
  }

  /// The kept file's identity and the offset its bundle bytes start at, or
  /// `null` when its header line is missing or malformed.
  static (BundleIdentity, int)? _readHeader(Uint8List contents) {
    final end = contents.indexOf(0x0a);
    if (end < 0 || end > _maxHeaderLength) return null;
    final Object? header;
    try {
      header = jsonDecode(utf8.decode(Uint8List.sublistView(contents, 0, end)));
    } on FormatException {
      return null;
    }
    return switch (header) {
      {'build': final int build, 'sha256': final String sha256} => (
        BundleIdentity(build: build, sha256: sha256),
        end + 1,
      ),
      _ => null,
    };
  }
}
