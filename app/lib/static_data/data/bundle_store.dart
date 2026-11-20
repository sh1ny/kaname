/// The device's one kept copy of the bundle in use, behind a plain-Dart
/// interface.
library;

import 'dart:typed_data';

import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';

/// Which bundle a set of bytes is: its SDE build and the SHA-256 of its
/// compressed bytes.
final class BundleIdentity {
  /// Creates the identity of build [build]'s bundle hashing to [sha256].
  const BundleIdentity({required this.build, required this.sha256});

  /// The SDE build the bundle holds.
  final int build;

  /// The SHA-256 of the compressed bundle, as 64 lower-case hexadecimal
  /// digits.
  final String sha256;

  @override
  bool operator ==(Object other) =>
      other is BundleIdentity && other.build == build && other.sha256 == sha256;

  @override
  int get hashCode => Object.hash(build, sha256);

  @override
  String toString() => 'BundleIdentity($build, $sha256)';
}

/// A bundle's compressed bytes together with their [identity].
final class BundleCopy {
  /// Creates the copy of [bytes], the bundle [identity] names.
  const BundleCopy({required this.identity, required this.bytes});

  /// Which bundle [bytes] are.
  final BundleIdentity identity;

  /// The gzip-compressed bundle file, as the server serves it.
  final Uint8List bytes;
}

/// The outcome of loading the kept copy.
sealed class KeptBundleLoad {
  const KeptBundleLoad();
}

/// No copy is kept, or the store cannot be used on this device.
final class NoKeptBundle extends KeptBundleLoad {
  /// Creates the outcome.
  const NoKeptBundle();
}

/// The kept copy passed every check of the reader.
final class KeptBundleLoaded extends KeptBundleLoad {
  /// Creates the outcome holding [bundle], the bundle [identity] names.
  const KeptBundleLoaded({required this.identity, required this.bundle});

  /// Which bundle was loaded.
  final BundleIdentity identity;

  /// The opened bundle.
  final ClientBundle bundle;
}

/// The kept copy was refused and is not used.
///
/// It is left where it is: the next save replaces it.
final class KeptBundleRejected extends KeptBundleLoad {
  /// Creates the outcome for [refusal].
  const KeptBundleRejected(this.refusal);

  /// Why the kept copy was refused; an [UnsupportedFormat] means a copy of
  /// another format major, for example after an app update.
  final BundleRefusal refusal;
}

/// The outcome of saving a copy.
sealed class BundleSaveOutcome {
  const BundleSaveOutcome();
}

/// The copy replaced the kept one whole.
final class BundleSaved extends BundleSaveOutcome {
  /// Creates the outcome.
  const BundleSaved();
}

/// The copy was not kept; the previously kept copy, if any, is unchanged.
///
/// The bundle stays usable from memory. [detail] is for the log only, never
/// for the UI.
final class BundleNotSaved extends BundleSaveOutcome {
  /// Creates the outcome, explained by [detail].
  const BundleNotSaved(this.detail);

  /// Why the copy was not kept.
  final String detail;
}

/// Checks a bundle's compressed bytes and opens them.
///
/// Hashing, inflating and parsing run off the UI: in `Isolate.run` on
/// native platforms, with the browser's asynchronous APIs on the web
/// (design D12).
abstract interface class BundleOpener {
  /// Opens [compressed] as the bundle [identity] names.
  ///
  /// Refuses it, as `openBundle` of `kaname_static_data_bundle` does, when
  /// its SHA-256, format major or build differs, or when it does not
  /// inflate or parse.
  Future<BundleOpenResult> open(Uint8List compressed, BundleIdentity identity);
}

/// Keeps one copy of the bundle in use on this device.
///
/// Plain Dart with no state management (ADR 0010: `data/` never imports
/// Riverpod). On native platforms the copy is a file in the app's support
/// directory; on the web it is one Cache Storage entry under a fixed key.
/// The copy is a cache of the bundle in use; it is not the M4 local store
/// (C22).
///
/// Carried constraint C17: the app swaps a verified bundle in before saving
/// it and saves only the bundle in use; a save that completes after the
/// bundle in use changed is followed by a save of the bundle in use, so the
/// kept copy converges; each save replaces the one kept copy whole; neither
/// store ever deletes the kept copy, a bad one being replaced by the next
/// save (design D6, D16).
///
/// So a reader, in this process or another app process or tab, always
/// finds a whole old or a whole new copy, and between two writers the last
/// save wins. The caller runs one save at a time.
abstract interface class BundleStore {
  /// Loads and checks the kept copy.
  ///
  /// A copy that fails a check is rejected in memory only
  /// ([KeptBundleRejected]) and never deleted.
  Future<KeptBundleLoad> load();

  /// Replaces the kept copy whole with [copy].
  ///
  /// Never throws: a failed or refused write is [BundleNotSaved] and
  /// leaves the previous copy as it was.
  Future<BundleSaveOutcome> save(BundleCopy copy);
}
