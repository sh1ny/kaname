import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:kaname_static_data_bundle/src/bundle_format.dart';
import 'package:test/test.dart';

Uint8List _hex(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

/// A gzip header (no flags) around [deflated], with the empty input's
/// trailer.
Uint8List _member(List<int> deflated) => Uint8List.fromList([
  0x1f, 0x8b, 0x08, 0, 0, 0, 0, 0, 0, 0xff, //
  ...deflated,
  0, 0, 0, 0, 0, 0, 0, 0,
]);

void main() {
  group('inflateGzip', () {
    // Pre-ship round 44: a short member's final end-of-block code ends in
    // its last byte, so a decoder that looked ahead into the trailer would
    // refuse it.
    test('decodes short members whose last code ends at the trailer', () {
      // Made by zlib (Python's gzip.compress, level 9, mtime 0).
      final zlibMade = {
        '1f8b080000000000020303000000000000000000': '',
        '1f8b08000000000002034b040043beb7e801000000': 'a',
        '1f8b08000000000002038b36d4318a0500bf508b0805000000': '[1,2]',
      };
      for (final MapEntry(key: hex, value: text) in zlibMade.entries) {
        expect(utf8.decode(inflateGzip(_hex(hex))), text, reason: hex);
      }
      for (var length = 0; length < 64; length++) {
        final data = utf8.encode(
          '{"a":[${List.filled(length, '1').join(',')}]}',
        );
        for (final level in const [1, 6, 9]) {
          final member = Uint8List.fromList(
            const GZipEncoder().encodeBytes(data, level: level),
          );
          expect(inflateGzip(member), data, reason: 'length $length');
        }
      }
    });

    test('refuses a member whose data never reaches a final block', () {
      // One empty stored block, not marked final.
      final member = _member(const [0x00, 0x00, 0x00, 0xff, 0xff]);

      expect(
        () => inflateGzip(member),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('final block'),
          ),
        ),
      );
    });

    test('refuses a member with bytes after its final block', () {
      // An empty final fixed block (03 00), then a stray byte.
      final member = _member(const [0x03, 0x00, 0x00]);

      expect(
        () => inflateGzip(member),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('exactly one gzip member'),
          ),
        ),
      );
    });
  });
}
