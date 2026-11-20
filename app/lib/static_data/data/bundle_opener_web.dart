/// The web [BundleOpener]: the browser's own hashing and inflating.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';
import 'package:web/web.dart' as web;

import 'bundle_hash.dart';
import 'bundle_store.dart';

/// A [BundleOpener] for the web, where the app's Dart code runs on the
/// browser's main thread (design D12, assumption A17).
///
/// It hashes with `SubtleCrypto.digest` and inflates with
/// `DecompressionStream`, both asynchronous and native. Without
/// `SubtleCrypto`, as outside a secure context, it hashes with
/// [chunkedSha256], which yields between chunks. It then parses the
/// inflated bytes with the reader's `openInflatedBundleChunked`, which
/// yields between chunks of 2,000 lines and checks the format and build.
final class BrowserBundleOpener implements BundleOpener {
  /// Creates the opener hashing with [subtle], or with [chunkedSha256] when
  /// it is `null`.
  const BrowserBundleOpener({this._subtle});

  /// Creates the opener for [window], using its `SubtleCrypto` only when
  /// the page is a secure context that offers it.
  factory BrowserBundleOpener.ofWindow(web.Window window) {
    final crypto = window.crypto as JSObject;
    final hasSubtle =
        window.isSecureContext &&
        crypto.has('subtle') &&
        crypto['subtle'] != null;
    return BrowserBundleOpener(subtle: hasSubtle ? window.crypto.subtle : null);
  }

  final web.SubtleCrypto? _subtle;

  @override
  Future<BundleOpenResult> open(
    Uint8List compressed,
    BundleIdentity identity,
  ) async {
    final subtle = _subtle;
    final String actual;
    try {
      actual = subtle == null
          ? await chunkedSha256(compressed)
          : await _digest(subtle, compressed);
    } catch (error) {
      // A JavaScript rejection is not a Dart exception, so every thrown
      // value is caught here and turned into a refusal.
      return BundleRefused(
        CorruptBundle('the bundle cannot be hashed: $error'),
      );
    }
    if (actual != identity.sha256.toLowerCase()) {
      return BundleRefused(
        HashMismatch(expected: identity.sha256, actual: actual),
      );
    }
    final Uint8List inflated;
    try {
      inflated = await _inflate(compressed);
    } catch (error) {
      return BundleRefused(
        CorruptBundle('the bundle cannot be inflated: $error'),
      );
    }
    return openInflatedBundleChunked(inflated, build: identity.build);
  }

  static Future<String> _digest(
    web.SubtleCrypto subtle,
    Uint8List bytes,
  ) async {
    final digest = await subtle.digest('SHA-256'.toJS, bytes.toJS).toDart;
    final hash = (digest! as JSArrayBuffer).toDart.asUint8List();
    return [for (final byte in hash) byte.toRadixString(16).padLeft(2, '0')]
        .join();
  }

  static Future<Uint8List> _inflate(Uint8List compressed) async {
    final gunzip = web.DecompressionStream('gzip');
    final inflated = web.Blob(<JSAny>[compressed.toJS].toJS)
        .stream()
        .pipeThrough(
          web.ReadableWritablePair(
            readable: gunzip.readable,
            writable: gunzip.writable,
          ),
        );
    final buffer = await web.Response(inflated).arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }
}
