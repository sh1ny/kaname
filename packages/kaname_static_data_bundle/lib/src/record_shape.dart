/// The shape check of a bundle's record lines, which builds no values.
library;

import 'dart:typed_data';

/// Whether the bytes of [bytes] from [start] to [end] are one record line:
/// UTF-8 JSON holding an array of an integer key, an object and an object
/// or `null`, with only whitespace around it.
///
/// Every line it accepts, the reader's lazy decoding accepts too, yet it
/// allocates no JSON values (design D12): the open checks the sections it
/// does not decode without materializing them.
bool isRecordLine(Uint8List bytes, int start, int end) {
  final scanner = _Scanner(bytes, start, end);
  try {
    scanner.recordLine();
    return true;
  } on _Malformed {
    return false;
  }
}

/// Thrown inside the scanner at the first byte that breaks the shape.
final class _Malformed implements Exception {
  const _Malformed();
}

/// A recursive-descent scan of RFC 8259 JSON over UTF-8 bytes.
final class _Scanner {
  _Scanner(this._bytes, this._i, this._end);

  /// Deeper nesting is refused rather than risking the stack.
  static const _maxDepth = 512;

  static const _quote = 0x22;
  static const _backslash = 0x5C;
  static const _comma = 0x2C;
  static const _colon = 0x3A;
  static const _openBracket = 0x5B;
  static const _closeBracket = 0x5D;
  static const _openBrace = 0x7B;
  static const _closeBrace = 0x7D;
  static const _minus = 0x2D;
  static const _plus = 0x2B;
  static const _dot = 0x2E;
  static const _zero = 0x30;

  final Uint8List _bytes;
  final int _end;
  int _i;

  int get _peek => _i < _end ? _bytes[_i] : -1;

  Never _fail() => throw const _Malformed();

  void _expect(int byte) {
    if (_peek != byte) _fail();
    _i++;
  }

  void _whitespace() {
    while (_i < _end) {
      switch (_bytes[_i]) {
        case 0x20 || 0x09 || 0x0A || 0x0D:
          _i++;
        default:
          return;
      }
    }
  }

  void recordLine() {
    _whitespace();
    _expect(_openBracket);
    _whitespace();
    final keyStart = _i;
    _number(integer: true);
    // At most 18 digits: every such key decodes as an `int` on every
    // platform.
    final signed = _bytes[keyStart] == _minus ? 1 : 0;
    if (_i - keyStart - signed > 18) _fail();
    _whitespace();
    _expect(_comma);
    _whitespace();
    _object(1);
    _whitespace();
    _expect(_comma);
    _whitespace();
    if (_peek == 0x6E) {
      _literal('null');
    } else {
      _object(1);
    }
    _whitespace();
    _expect(_closeBracket);
    _whitespace();
    if (_i != _end) _fail();
  }

  void _value(int depth) {
    if (depth > _maxDepth) _fail();
    switch (_peek) {
      case _openBrace:
        _object(depth);
      case _openBracket:
        _array(depth);
      case _quote:
        _string();
      case 0x74:
        _literal('true');
      case 0x66:
        _literal('false');
      case 0x6E:
        _literal('null');
      default:
        _number(integer: false);
    }
  }

  void _object(int depth) {
    _expect(_openBrace);
    _whitespace();
    if (_peek == _closeBrace) {
      _i++;
      return;
    }
    while (true) {
      _string();
      _whitespace();
      _expect(_colon);
      _whitespace();
      _value(depth + 1);
      _whitespace();
      if (_peek == _comma) {
        _i++;
        _whitespace();
        continue;
      }
      _expect(_closeBrace);
      return;
    }
  }

  void _array(int depth) {
    _expect(_openBracket);
    _whitespace();
    if (_peek == _closeBracket) {
      _i++;
      return;
    }
    while (true) {
      _value(depth + 1);
      _whitespace();
      if (_peek == _comma) {
        _i++;
        _whitespace();
        continue;
      }
      _expect(_closeBracket);
      return;
    }
  }

  void _literal(String word) {
    for (final unit in word.codeUnits) {
      _expect(unit);
    }
  }

  bool _isDigit(int byte) => byte >= _zero && byte <= 0x39;

  /// A JSON number; with [integer], one with no fraction or exponent, as
  /// the reader's `int` key pattern needs.
  void _number({required bool integer}) {
    if (_peek == _minus) _i++;
    if (_peek == _zero) {
      _i++;
    } else if (_isDigit(_peek)) {
      while (_isDigit(_peek)) {
        _i++;
      }
    } else {
      _fail();
    }
    if (integer) return;
    if (_peek == _dot) {
      _i++;
      if (!_isDigit(_peek)) _fail();
      while (_isDigit(_peek)) {
        _i++;
      }
    }
    if (_peek == 0x65 || _peek == 0x45) {
      _i++;
      if (_peek == _plus || _peek == _minus) _i++;
      if (!_isDigit(_peek)) _fail();
      while (_isDigit(_peek)) {
        _i++;
      }
    }
  }

  void _string() {
    _expect(_quote);
    while (true) {
      final byte = _peek;
      if (byte < 0) _fail();
      if (byte == _quote) {
        _i++;
        return;
      }
      if (byte < 0x20) _fail();
      if (byte == _backslash) {
        _i++;
        _escape();
      } else if (byte < 0x80) {
        _i++;
      } else {
        _utf8Sequence();
      }
    }
  }

  void _escape() {
    switch (_peek) {
      case _quote || _backslash || 0x2F || 0x62 || 0x66 || 0x6E || 0x72 || 0x74:
        _i++;
      case 0x75:
        _i++;
        for (var n = 0; n < 4; n++) {
          final byte = _peek;
          final hex =
              _isDigit(byte) ||
              (byte >= 0x41 && byte <= 0x46) ||
              (byte >= 0x61 && byte <= 0x66);
          if (!hex) _fail();
          _i++;
        }
      default:
        _fail();
    }
  }

  /// One multi-byte UTF-8 sequence, as Dart's strict decoder accepts it: no
  /// overlong forms, no surrogates, nothing above U+10FFFF.
  void _utf8Sequence() {
    final lead = _bytes[_i];
    final (int length, int low, int high) = switch (lead) {
      >= 0xC2 && <= 0xDF => (2, 0x80, 0xBF),
      0xE0 => (3, 0xA0, 0xBF),
      >= 0xE1 && <= 0xEC || 0xEE || 0xEF => (3, 0x80, 0xBF),
      0xED => (3, 0x80, 0x9F),
      0xF0 => (4, 0x90, 0xBF),
      >= 0xF1 && <= 0xF3 => (4, 0x80, 0xBF),
      0xF4 => (4, 0x80, 0x8F),
      _ => _fail(),
    };
    if (_i + length > _end) _fail();
    final second = _bytes[_i + 1];
    if (second < low || second > high) _fail();
    for (var k = 2; k < length; k++) {
      final next = _bytes[_i + k];
      if (next < 0x80 || next > 0xBF) _fail();
    }
    _i += length;
  }
}
