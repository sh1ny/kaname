/// The pure-Dart SHA-256 the web app falls back to without `SubtleCrypto`.
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// How many bytes [chunkedSha256] hashes before it yields.
const int sha256ChunkBytes = 256 * 1024;

/// The SHA-256 of [bytes] as 64 lower-case hexadecimal digits, hashed
/// [chunkBytes] at a time with a yield to the event loop between chunks.
///
/// Browsers offer `SubtleCrypto` only in a secure context; elsewhere the
/// web app hashes with this, so a large bundle never blocks the UI in one
/// long task (design D12). It gives the same digest as the reader's
/// `bundleSha256`.
Future<String> chunkedSha256(
  Uint8List bytes, {
  int chunkBytes = sha256ChunkBytes,
}) async {
  final result = _DigestSink();
  final input = crypto.sha256.startChunkedConversion(result);
  for (var start = 0; start < bytes.length; start += chunkBytes) {
    final end = start + chunkBytes < bytes.length
        ? start + chunkBytes
        : bytes.length;
    input.add(Uint8List.sublistView(bytes, start, end));
    await Future<void>.delayed(Duration.zero);
  }
  input.close();
  return result.digest.toString();
}

final class _DigestSink implements Sink<crypto.Digest> {
  late final crypto.Digest digest;

  @override
  void add(crypto.Digest data) => digest = data;

  @override
  void close() {}
}
