/// The bundle file's format version and its deterministic gzip framing.
library;

import 'dart:typed_data';

import 'package:archive/archive.dart';

/// The major format version this package writes and reads.
///
/// Readers refuse any other major version. Changing a section's order,
/// columns or line layout is a major change (C2).
const int bundleFormatMajor = 1;

/// The minor format version this package writes.
///
/// Readers accept any minor version of a major they know; adding a section
/// at the end or a header key is a minor change (C2).
const int bundleFormatMinor = 0;

/// The locales a bundle built by this package holds names in.
const List<String> bundleLocales = ['en'];

/// Gzips [data] the same way on every runtime.
///
/// The header has no file name, a zero modification time, no extra flags
/// and the "unknown" operating system, and the data is deflated by
/// `package:archive`'s pure-Dart [Deflate] at [level], never by the
/// platform's zlib, so the bytes do not depend on the host (assumption A1).
Uint8List deterministicGzip(Uint8List data, {required int level}) {
  final deflated = Deflate(data, level: level).getBytes();
  final crc = getCrc32(data);
  final out = BytesBuilder(copy: false)
    ..add(const [
      0x1f, 0x8b, // magic
      0x08, // deflate
      0x00, // flags: no name, comment or extra field
      0x00, 0x00, 0x00, 0x00, // modification time: none
      0x00, // extra flags
      0xff, // operating system: unknown
    ])
    ..add(deflated)
    ..add(_uint32(crc))
    ..add(_uint32(data.length));
  return out.takeBytes();
}

/// Inflates the gzip file [bytes], checking its CRC.
///
/// Throws a [FormatException] when [bytes] is not a valid gzip file.
Uint8List inflateGzip(Uint8List bytes) {
  try {
    return const GZipDecoder().decodeBytes(
      bytes,
      verify: true,
      throwOnError: true,
    );
  } on FormatException {
    rethrow;
  } on Object catch (error) {
    throw FormatException('not a valid gzip file: $error');
  }
}

Uint8List _uint32(int value) =>
    Uint8List(4)
      ..buffer.asByteData().setUint32(0, value & 0xffffffff, Endian.little);
