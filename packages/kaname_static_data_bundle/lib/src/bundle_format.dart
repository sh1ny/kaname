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

/// The largest record key a bundle holds, 2^53 - 1; keys run from
/// `-bundleMaxKey` to `bundleMaxKey`.
///
/// Every key in that range decodes as the same `int` on native platforms
/// and on the web, where JSON numbers are doubles; the builder refuses any
/// other key and the reader's record check accepts exactly these.
const int bundleMaxKey = 9007199254740991;

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

/// Inflates the gzip file [bytes], checking its CRC and length.
///
/// Throws a [FormatException] when [bytes] is not exactly one valid gzip
/// member: the web opener's `DecompressionStream('gzip')` takes nothing
/// else, so neither does this. The header is checked first, because the
/// native decoder also takes zlib framing (pre-ship round 39); the member
/// must end exactly at the end of [bytes], because the native decoder also
/// takes concatenated members (pre-ship round 43). The builder writes one
/// member ([deterministicGzip]).
Uint8List inflateGzip(Uint8List bytes) {
  const notGzip = 'not a valid gzip file';
  final length = bytes.length;
  if (length < 18 || bytes[0] != 0x1f || bytes[1] != 0x8b || bytes[2] != 0x08) {
    throw const FormatException(
      '$notGzip: no gzip header with the deflate method',
    );
  }
  final flags = bytes[3];
  if (flags & 0xe0 != 0) {
    throw const FormatException('$notGzip: reserved header flags are set');
  }
  var position = 10;
  if (flags & 0x04 != 0) {
    if (position + 2 > length) {
      throw const FormatException('$notGzip: truncated header');
    }
    position += 2 + (bytes[position] | bytes[position + 1] << 8);
  }
  for (final flag in const [0x08, 0x10]) {
    // A file name or comment, each ending in a zero byte.
    if (flags & flag == 0) continue;
    while (position < length && bytes[position] != 0) {
      position++;
    }
    position++;
  }
  if (flags & 0x02 != 0) {
    // The header's own checksum: the low 16 bits of the CRC-32 of the
    // header bytes before it, which the browser checks too (pre-ship
    // round 45).
    if (position + 2 > length - 8) {
      throw const FormatException('$notGzip: truncated header');
    }
    final expected = bytes[position] | bytes[position + 1] << 8;
    final actual = getCrc32(Uint8List.sublistView(bytes, 0, position)) & 0xffff;
    if (actual != expected) {
      throw const FormatException('$notGzip: header CRC mismatch');
    }
    position += 2;
  }
  if (position > length - 8) {
    throw const FormatException('$notGzip: truncated header');
  }
  // The inflater gets only the DEFLATE data, so its lookahead never reads
  // the trailer, and must reach the final block and use every byte of it
  // (pre-ship round 44).
  final deflated = Uint8List.sublistView(bytes, position, length - 8);
  final input = InputMemoryStream(deflated);
  final Inflate inflater;
  try {
    inflater = Inflate.stream(input);
  } on Object catch (error) {
    throw FormatException('$notGzip: $error');
  }
  if (!inflater.isFinished) {
    throw const FormatException(
      '$notGzip: the compressed data ends before its final block',
    );
  }
  final inflated = inflater.getBytes();
  if (input.position != deflated.length) {
    throw const FormatException(
      '$notGzip: the file is not exactly one gzip member',
    );
  }
  final trailer = ByteData.sublistView(bytes, length - 8);
  if (trailer.getUint32(0, Endian.little) != getCrc32(inflated)) {
    throw const FormatException('$notGzip: CRC mismatch');
  }
  if (trailer.getUint32(4, Endian.little) != inflated.length & 0xffffffff) {
    throw const FormatException('$notGzip: length mismatch');
  }
  return inflated;
}

Uint8List _uint32(int value) =>
    Uint8List(4)
      ..buffer.asByteData().setUint32(0, value & 0xffffffff, Endian.little);
