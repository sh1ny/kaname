/// Decoding helpers the generated models use (design D1 of
/// `esi-client-generator`).
library;

import 'call.dart';
import 'values.dart';

/// Reads one JSON value against a schema, or raises [EsiDecodeException]
/// naming the JSON path of the mismatch.
typedef EsiRead<T> = T Function(Object? json, String path);

/// Reads JSON values as the pinned spec types them.
///
/// Paths look like `$.items[2].type_id`; `$` is the body itself.
abstract final class EsiJson {
  static Never _mismatch(String path, String expected, Object? json) =>
      throw EsiDecodeException(path, 'expected $expected, got ${_kind(json)}');

  static String _kind(Object? json) => switch (json) {
    null => 'null',
    bool() => 'a boolean',
    int() => 'an integer',
    double() => 'a number',
    String() => 'a string',
    List<Object?>() => 'an array',
    Map<String, Object?>() => 'an object',
    _ => 'an unexpected value',
  };

  /// A JSON object.
  static Map<String, Object?> object(Object? json, String path) =>
      switch (json) {
        final Map<String, Object?> map => map,
        _ => _mismatch(path, 'an object', json),
      };

  /// The value of the required field [key] of [object], which must be
  /// present.
  static Object? required(
    Map<String, Object?> object,
    String key,
    String path,
  ) => object.containsKey(key)
      ? object[key]
      : throw EsiDecodeException(
          '$path.$key',
          'required field "$key" is missing',
        );

  /// The optional field [key] of [object] read with [read], or `null` when
  /// it is absent.
  ///
  /// Optional only permits omission: a present `null` is read like any
  /// other value, so a schema that does not allow `null` rejects it.
  static T? optional<T extends Object>(
    Map<String, Object?> object,
    String key,
    String path,
    EsiRead<T> read,
  ) => object.containsKey(key) ? read(object[key], '$path.$key') : null;

  /// The optional, nullable field [key] of [object] read with [read], or
  /// `null` when it is absent or `null`.
  static T? optionalNullable<T extends Object>(
    Map<String, Object?> object,
    String key,
    String path,
    EsiRead<T> read,
  ) => switch (object[key]) {
    null => null,
    final value => read(value, '$path.$key'),
  };

  /// [read]'s value, or `null` for a JSON `null` (a nullable schema).
  static T? nullable<T extends Object>(
    Object? json,
    String path,
    EsiRead<T> read,
  ) => json == null ? null : read(json, path);

  /// An integer. ESI's int64 values are Dart [int]s.
  static int integer(Object? json, String path) => switch (json) {
    final int value => value,
    _ => _mismatch(path, 'an integer', json),
  };

  /// A number; integers are accepted.
  static double number(Object? json, String path) => switch (json) {
    final num value => value.toDouble(),
    _ => _mismatch(path, 'a number', json),
  };

  /// A string.
  static String string(Object? json, String path) => switch (json) {
    final String value => value,
    _ => _mismatch(path, 'a string', json),
  };

  /// A boolean.
  static bool boolean(Object? json, String path) => switch (json) {
    final bool value => value,
    _ => _mismatch(path, 'a boolean', json),
  };

  /// A `uuid` string: 32 hex digits in the 8-4-4-4-12 form.
  static String uuid(Object? json, String path) {
    final text = string(json, path);
    if (isUuid(text)) return text;
    throw EsiDecodeException(path, 'expected a UUID, got "$text"');
  }

  /// Whether [text] has the 8-4-4-4-12 hex form of a UUID.
  static bool isUuid(String text) => _uuid.hasMatch(text);

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );

  /// A `date` string, `YYYY-MM-DD`, as a UTC midnight.
  ///
  /// Anything else, or a day the calendar does not have, is a mismatch:
  /// nothing is normalised.
  static DateTime date(Object? json, String path) {
    final text = string(json, path);
    if (_date.firstMatch(text) case final match?) {
      final [year, month, day] = [
        for (final group in [1, 2, 3]) int.parse(match[group]!),
      ];
      if (_isDay(year, month, day)) return DateTime.utc(year, month, day);
    }
    throw EsiDecodeException(path, 'expected a date, got "$text"');
  }

  /// A `date-time` string as RFC 3339 states it: a date, a time and an
  /// offset (`Z` or `±hh:mm`).
  ///
  /// A missing time or offset, or a component out of range, is a mismatch:
  /// nothing is normalised.
  static DateTime dateTime(Object? json, String path) {
    final text = string(json, path);
    if (_dateTime.firstMatch(text) case final match?) {
      final [year, month, day, hour, minute, second] = [
        for (final group in [1, 2, 3, 4, 5, 6]) int.parse(match[group]!),
      ];
      final offsetHour = int.tryParse(match[7] ?? '') ?? 0;
      final offsetMinute = int.tryParse(match[8] ?? '') ?? 0;
      if (_isDay(year, month, day) &&
          hour < 24 &&
          minute < 60 &&
          second < 60 &&
          offsetHour < 24 &&
          offsetMinute < 60) {
        return DateTime.parse(text).toUtc();
      }
    }
    throw EsiDecodeException(path, 'expected a date-time, got "$text"');
  }

  static final RegExp _date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static final RegExp _dateTime = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[Tt](\d{2}):(\d{2}):(\d{2})(?:\.\d+)?'
    r'(?:[Zz]|[+-](\d{2}):(\d{2}))$',
  );

  /// Whether [day] exists in [month] of [year].
  static bool _isDay(int year, int month, int day) =>
      month >= 1 &&
      month <= 12 &&
      day >= 1 &&
      DateTime.utc(year, month, day).day == day;

  /// Any JSON value, as decoded.
  static Object? any(Object? json, String path) => json;

  /// Reads nothing: the operation states no response body.
  static void ignore(Object? json, String path) {}

  /// A string enum value: a listed value, or [EsiUnknown] holding a string
  /// the pinned spec does not list. A non-string is a mismatch.
  static EsiEnum<E> enumValue<E extends EsiWireEnum>(
    Object? json,
    String path,
    List<E> values,
  ) {
    final wire = string(json, path);
    for (final value in values) {
      if (value.wire == wire) return EsiKnown(value);
    }
    return EsiUnknown(wire);
  }

  /// An array whose items are read with [read].
  static List<T> list<T>(Object? json, String path, EsiRead<T> read) =>
      switch (json) {
        final List<Object?> items => [
          for (final (i, item) in items.indexed) read(item, '$path[$i]'),
        ],
        _ => _mismatch(path, 'an array', json),
      };

  /// An object used as a map, whose values are read with [read].
  static Map<String, T> map<T>(Object? json, String path, EsiRead<T> read) => {
    for (final MapEntry(:key, :value) in object(json, path).entries)
      key: read(value, '$path.$key'),
  };

  /// The single key of a `oneOf` object; zero or several keys are a
  /// mismatch.
  static String oneOfKey(Map<String, Object?> object, String path) =>
      switch (object.keys.toList()) {
        [final key] => key,
        final keys => throw EsiDecodeException(
          path,
          'expected an object with exactly one key, got ${keys.length}',
        ),
      };

  /// A `date` value as written on the wire, `YYYY-MM-DD`.
  static String encodeDate(DateTime value) =>
      value.toIso8601String().substring(0, 10);

  /// A `date-time` value as written on the wire, in UTC.
  static String encodeDateTime(DateTime value) =>
      value.toUtc().toIso8601String();
}

/// Writes one argument value as JSON against a schema, or raises
/// [EsiInvalidArgument] naming the [path] of the broken bound.
typedef EsiWrite<T> = Object? Function(T value, String path);

/// Checks call arguments against the bounds the spec states and writes them
/// as JSON (design D10 of `esi-client-generator`).
///
/// Each check raises [EsiInvalidArgument] naming the parameter path, such as
/// `body[0]` or `page`; the generated call turns it into
/// `EsiInvalidRequest` and sends nothing.
abstract final class EsiCheck {
  /// [value] unchanged: a schema with no bounds.
  static Object? plain(Object? value, String path) => value;

  /// [value] against [minimum] and [maximum], inclusive.
  static T range<T extends num>(
    T value,
    String path, {
    num? minimum,
    num? maximum,
  }) {
    if (minimum != null && value < minimum) {
      throw EsiInvalidArgument(path, 'must be at least $minimum, got $value');
    }
    if (maximum != null && value > maximum) {
      throw EsiInvalidArgument(path, 'must be at most $maximum, got $value');
    }
    return value;
  }

  /// [value]'s length against [minLength] and [maxLength], counted in
  /// Unicode code points as OpenAPI counts them, not UTF-16 code units.
  static String length(
    String value,
    String path, {
    int? minLength,
    int? maxLength,
  }) {
    final length = value.runes.length;
    if (minLength != null && length < minLength) {
      throw EsiInvalidArgument(
        path,
        'must be at least $minLength characters long',
      );
    }
    if (maxLength != null && length > maxLength) {
      throw EsiInvalidArgument(
        path,
        'must be at most $maxLength characters long',
      );
    }
    return value;
  }

  /// [value] as a JSON array of its items written with [write], checked
  /// against [minItems] and [maxItems], and for repeats when [unique].
  static List<Object?> list<T>(
    List<T> value,
    String path,
    EsiWrite<T> write, {
    int? minItems,
    int? maxItems,
    bool unique = false,
  }) {
    if (minItems != null && value.length < minItems) {
      throw EsiInvalidArgument(path, 'must hold at least $minItems items');
    }
    if (maxItems != null && value.length > maxItems) {
      throw EsiInvalidArgument(path, 'must hold at most $maxItems items');
    }
    final json = [
      for (final (i, item) in value.indexed) write(item, '$path[$i]'),
    ];
    if (unique && json.toSet().length != json.length) {
      throw EsiInvalidArgument(path, 'must not repeat an item');
    }
    return json;
  }

  /// [value] as a JSON object whose values are written with [write].
  static Map<String, Object?> map<T>(
    Map<String, T> value,
    String path,
    EsiWrite<T> write,
  ) => {
    for (final MapEntry(:key, :value) in value.entries)
      key: write(value, '$path.$key'),
  };

  /// [value] written with [write], or `null` when it is `null`.
  static Object? optional<T extends Object>(
    T? value,
    String path,
    EsiWrite<T> write,
  ) => value == null ? null : write(value, path);

  /// The wire form of an enum argument.
  static String wire(EsiWireEnum value, String path) => value.wire;

  /// The wire form of an enum value; ESI would refuse one the pinned spec
  /// does not list.
  static String known(EsiEnum<EsiWireEnum> value, String path) =>
      switch (value) {
        EsiKnown(:final wire) => wire,
        EsiUnknown(:final wire) => throw EsiInvalidArgument(
          path,
          'holds "$wire", which the pinned spec does not list',
        ),
      };

  /// A `date` argument as written on the wire, `YYYY-MM-DD`.
  static String date(DateTime value, String path) => EsiJson.encodeDate(value);

  /// A `uuid` argument, which must have the 8-4-4-4-12 hex form.
  static String uuid(String value, String path) => EsiJson.isUuid(value)
      ? value
      : throw EsiInvalidArgument(path, 'must be a UUID, got "$value"');

  /// A `date-time` argument as written on the wire, in UTC.
  static String dateTime(DateTime value, String path) =>
      EsiJson.encodeDateTime(value);

  /// A `oneOf` argument: an unlisted variant cannot be sent.
  static Never unknownVariant(String key, String path) =>
      throw EsiInvalidArgument(
        path,
        'holds the variant "$key", which the pinned spec does not list',
      );
}
