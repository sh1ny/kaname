/// The canonical JSON text a bundle is written in.
library;

import 'dart:convert';

/// Writes [value] as canonical JSON text to [out].
///
/// Object keys are sorted by [String.compareTo]. A number is written in
/// Dart's shortest form, and an integral number as an integer whether it
/// arrived as an `int` or as a `double`: Postgres `jsonb` returns `1e2` as
/// `100`, while decoding the text `1e2` gives the `double` `100.0`, and both
/// are written `100` (assumption A6). Strings are escaped as [jsonEncode]
/// escapes them.
///
/// [value] must be a JSON value: `null`, a [bool], a [num], a [String], a
/// [List] of JSON values or a [Map] with [String] keys and JSON values.
/// Throws an [ArgumentError] for anything else, including a non-finite
/// number.
void writeCanonicalJson(Object? value, StringSink out) {
  switch (value) {
    case null:
      out.write('null');
    case bool():
      out.write(value ? 'true' : 'false');
    case int():
      out.write(value);
    case double():
      out.write(canonicalNumberText(value));
    case String():
      out.write(jsonEncode(value));
    case List<Object?>():
      out.write('[');
      for (var i = 0; i < value.length; i++) {
        if (i > 0) out.write(',');
        writeCanonicalJson(value[i], out);
      }
      out.write(']');
    case Map<Object?, Object?>():
      final keys = [
        for (final key in value.keys)
          switch (key) {
            final String key => key,
            _ => throw ArgumentError.value(key, 'key', 'is not a string'),
          },
      ]..sort();
      out.write('{');
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) out.write(',');
        out
          ..write(jsonEncode(keys[i]))
          ..write(':');
        writeCanonicalJson(value[keys[i]], out);
      }
      out.write('}');
    default:
      throw ArgumentError.value(value, 'value', 'is not a JSON value');
  }
}

/// Returns [value] as canonical JSON text; see [writeCanonicalJson].
String canonicalJson(Object? value) {
  final out = StringBuffer();
  writeCanonicalJson(value, out);
  return out.toString();
}

/// The canonical text of the number [value].
///
/// An integral value is written with its exact integer digits and no
/// fraction or exponent; any other value in Dart's shortest round-trip
/// form. Throws an [ArgumentError] when [value] is not finite.
String canonicalNumberText(double value) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', 'is not a finite number');
  }
  if (value != value.truncateToDouble()) return value.toString();
  // An integral double below 2^63 in magnitude converts exactly to an int;
  // beyond that BigInt keeps its exact digits.
  if (value.abs() < 9223372036854775808.0) return value.toInt().toString();
  return BigInt.from(value).toString();
}
