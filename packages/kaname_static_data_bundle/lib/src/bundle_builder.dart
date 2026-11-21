/// The builder core: one build's records in, bundle bytes out.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'bundle_format.dart';
import 'bundle_reader.dart';
import 'bundle_section.dart';
import 'canonical_json.dart';
import 'record_shape.dart';

/// A record of a typed section, as the import keeps it.
///
/// The typed [values] are already projected by the import, so a value of
/// the wrong JSON type is `null` and only the first record of a duplicate
/// key is fed; the builder never re-projects them from [raw].
final class TypedRecord {
  /// Creates the record with SDE key [key].
  const TypedRecord({
    required this.key,
    required this.values,
    required this.raw,
  });

  /// The record's SDE key (`_key`).
  final int key;

  /// The typed column values, keyed by [BundleColumn.name].
  ///
  /// A column missing from the map is written as `null`. Values are `null`,
  /// [int], [double], [bool] or [String], matching the column's kind.
  final Map<String, Object?> values;

  /// The record's full JSON as shipped.
  ///
  /// Written as `raw` only for a section that [BundleSection.carriesRaw];
  /// types take their [BundleSection.typeExtras] from it.
  final Map<String, Object?> raw;
}

/// A record of a raw-only section, as the import stores it.
final class RawRecord {
  /// Creates the record with stored key [key] read from line [line].
  const RawRecord({
    required this.key,
    required this.line,
    required this.record,
  });

  /// The stored key, as text; it must be a decimal integer (assumption A2).
  final String key;

  /// The record's line in its file, which orders records of the same key.
  final int line;

  /// The record's full JSON as shipped.
  final Map<String, Object?> record;
}

/// Thrown when the builder cannot write a bundle from its records.
final class BundleBuildException implements Exception {
  /// Creates the failure of [section] for [message].
  const BundleBuildException(this.section, this.message);

  /// The section whose records cannot be written.
  final BundleSection section;

  /// Why the records cannot be written.
  final String message;

  @override
  String toString() =>
      'BundleBuildException: section ${section.file}: $message';
}

/// A bundle the builder wrote.
final class BuiltBundle {
  /// Creates the result.
  const BuiltBundle({
    required this.buildNumber,
    required this.bytes,
    required this.sha256,
    required this.records,
  });

  /// The SDE build the bundle holds.
  final int buildNumber;

  /// The gzip-compressed bundle file.
  final Uint8List bytes;

  /// The SHA-256 of [bytes], as 64 lower-case hexadecimal digits.
  final String sha256;

  /// The count of accepted records of each section, every section listed.
  final Map<BundleSection, int> records;
}

/// Builds the bundle of one SDE build from its records.
///
/// Feed every record with [addTyped] and [addRaw], in any order, then call
/// [build]. The bytes depend only on the records, the build number, the
/// release date and the format (C1): records are written in ascending key
/// order (raw-only records of the same key in line order, duplicates kept),
/// JSON keys sorted and numbers canonical, and the file is gzip'd with a
/// zero modification time at [bundleGzipLevel].
final class BundleBuilder {
  /// Creates a builder for build [buildNumber], released on [releaseDate].
  BundleBuilder({required this.buildNumber, required this.releaseDate});

  /// The SDE build number written in the header.
  final int buildNumber;

  /// The release date written in the header, or `null` when unknown.
  ///
  /// [selectReleaseDate] picks it from the build's `_sde.jsonl` objects.
  final String? releaseDate;

  /// Adds [record] to the typed [section].
  ///
  /// Throws a [BundleBuildException] when [section] is raw-only, when a
  /// value is keyed by a name that is not one of the section's columns or
  /// does not match its column's kind, when [record]'s key is outside
  /// the bundle key range ([bundleMaxKey]), or when it was already added
  /// to [section].
  void addTyped(BundleSection section, TypedRecord record) {
    final columns = section.columns;
    if (columns == null) {
      throw BundleBuildException(
        section,
        'is raw-only and takes raw records, not typed record ${record.key}',
      );
    }
    _checkKeyRange(section, record.key);
    final keys = _typedKeys.putIfAbsent(section, () => {});
    if (!keys.add(record.key)) {
      throw BundleBuildException(
        section,
        'record ${record.key} was added twice; the import keeps only the '
        'first record of a key',
      );
    }
    final known = {for (final column in columns) column.name};
    for (final name in record.values.keys) {
      if (!known.contains(name)) {
        throw BundleBuildException(
          section,
          'record ${record.key} has a value for "$name", which is not one of '
          "the section's columns",
        );
      }
    }
    final typed = <String, Object?>{
      for (final column in columns)
        column.field: _typedValue(section, record.key, column, record.values),
      if (section == BundleSection.types)
        for (final extra in BundleSection.typeExtras)
          extra.field: _extraValue(extra, record.raw[extra.field]),
    };
    _lines(section).add(
      _Line(
        key: record.key,
        line: 0,
        typed: typed,
        raw: section.carriesRaw ? record.raw : null,
      ),
    );
  }

  /// Adds [record] to the raw-only [section].
  ///
  /// Throws a [BundleBuildException] when [section] is typed or when the
  /// record's key is not a decimal integer (assumption A2) in the bundle
  /// key range ([bundleMaxKey]).
  void addRaw(BundleSection section, RawRecord record) {
    if (!section.isRawOnly) {
      throw BundleBuildException(
        section,
        'is typed and takes typed records, not raw record "${record.key}"',
      );
    }
    final key = _integerKey.hasMatch(record.key)
        ? int.tryParse(record.key)
        : null;
    if (key == null) {
      throw BundleBuildException(
        section,
        'key "${record.key}" on line ${record.line} is not an integer',
      );
    }
    _checkKeyRange(section, key);
    _lines(section).add(
      _Line(key: key, line: record.line, typed: const {}, raw: record.record),
    );
  }

  /// Throws a [BundleBuildException] when [key] is outside the range every
  /// reader decodes exactly ([bundleMaxKey]).
  static void _checkKeyRange(BundleSection section, int key) {
    if (key > bundleMaxKey || key < -bundleMaxKey) {
      throw BundleBuildException(
        section,
        'key $key is outside the bundle key range of plus or minus '
        '$bundleMaxKey',
      );
    }
  }

  /// Writes the bundle of every record added so far.
  ///
  /// Throws a [BundleBuildException] when a record's JSON cannot be written,
  /// or when the reader would refuse its line ([isRecordLine]).
  BuiltBundle build() {
    final records = {
      for (final section in BundleSection.values)
        section: _sections[section]?.length ?? 0,
    };
    final out = StringBuffer();
    _write(out, BundleSection.values.first, {
      'build': buildNumber,
      'formatMajor': bundleFormatMajor,
      'formatMinor': bundleFormatMinor,
      'locales': bundleLocales,
      'releaseDate': releaseDate,
      'sections': [
        for (final MapEntry(key: section, value: count) in records.entries)
          {'file': section.file, 'present': count > 0, 'records': count},
      ],
    });
    out.write('\n');
    for (final section in BundleSection.values) {
      final lines = _sections[section];
      if (lines == null || lines.isEmpty) continue;
      lines.sort(
        (a, b) =>
            a.key != b.key ? a.key.compareTo(b.key) : a.line.compareTo(b.line),
      );
      _write(out, section, {'section': section.file});
      out.write('\n');
      for (final line in lines) {
        final record = StringBuffer();
        _write(record, section, [line.key, line.typed, line.raw]);
        // The reader's own check (D12): a record it would refuse, such as
        // raw JSON nested past its depth limit, fails the build instead of
        // shipping a bundle no app opens.
        final text = record.toString();
        final encoded = utf8.encode(text);
        if (!isRecordLine(
          encoded,
          0,
          encoded.length,
          raw: section.carriesRaw,
        )) {
          throw BundleBuildException(
            section,
            'record ${line.key} cannot be read back as a record line, '
            'for example because its JSON nests deeper than '
            '$recordMaxDepth levels',
          );
        }
        out
          ..write(text)
          ..write('\n');
      }
    }
    final bytes = deterministicGzip(
      utf8.encode(out.toString()),
      level: bundleGzipLevel,
    );
    return BuiltBundle(
      buildNumber: buildNumber,
      bytes: bytes,
      sha256: bundleSha256(bytes),
      records: records,
    );
  }

  final Map<BundleSection, List<_Line>> _sections = {};
  final Map<BundleSection, Set<int>> _typedKeys = {};

  static final _integerKey = RegExp(r'^(0|-?[1-9][0-9]*)$');

  List<_Line> _lines(BundleSection section) =>
      _sections.putIfAbsent(section, () => []);

  static void _write(StringBuffer out, BundleSection section, Object? value) {
    try {
      writeCanonicalJson(value, out);
    } on ArgumentError catch (error) {
      throw BundleBuildException(
        section,
        'cannot be written: ${error.message}',
      );
    }
  }

  static Object? _typedValue(
    BundleSection section,
    int key,
    BundleColumn column,
    Map<String, Object?> values,
  ) {
    final value = values[column.name];
    final fits = switch ((column.kind, value)) {
      (_, null) => true,
      (BundleColumnKind.integer, final int value) => _inKeyRange(value),
      (BundleColumnKind.real, num()) => true,
      (BundleColumnKind.boolean, bool()) => true,
      (BundleColumnKind.text || BundleColumnKind.localizedText, String()) =>
        true,
      _ => false,
    };
    if (!fits) {
      throw BundleBuildException(
        section,
        'record $key has $value for "${column.name}", which is not a '
        '${column.kind.name} value',
      );
    }
    return switch (column.kind) {
      BundleColumnKind.localizedText => {'en': ?value},
      _ => value,
    };
  }

  /// The value of type extra [extra], or null when it is not one: an
  /// integer extra holds only an integral number in the range every reader
  /// decodes as the same `int` ([bundleMaxKey]).
  static Object? _extraValue(BundleColumn extra, Object? value) =>
      switch ((extra.kind, value)) {
        (BundleColumnKind.real, final num value) => value,
        (BundleColumnKind.integer, final int value) when _inKeyRange(value) =>
          value,
        (BundleColumnKind.integer, final double value)
            when value.isFinite &&
                value == value.truncateToDouble() &&
                value.abs() <= bundleMaxKey =>
          value,
        _ => null,
      };

  /// Whether [value] is in the range every reader decodes exactly.
  static bool _inKeyRange(int value) =>
      value <= bundleMaxKey && value >= -bundleMaxKey;
}

final class _Line {
  const _Line({
    required this.key,
    required this.line,
    required this.typed,
    required this.raw,
  });

  final int key;
  final int line;
  final Map<String, Object?> typed;
  final Map<String, Object?>? raw;
}

/// The gzip compression level every bundle is written at.
const int bundleGzipLevel = 6;

/// The release date of build [build], from its `_sde.jsonl` [objects] in
/// line order.
///
/// Takes the first object whose `buildNumber` is a number numerically equal
/// to [build], so `42e0` and `42.0` match 42 as `42` does, and returns its
/// `releaseDate` when that is a string. Returns `null` when that object has
/// none, or when no object matches; later objects are never read.
String? selectReleaseDate(int build, Iterable<Map<String, Object?>> objects) {
  for (final object in objects) {
    if (object['buildNumber'] case final num number when number == build) {
      return switch (object['releaseDate']) {
        final String date => date,
        _ => null,
      };
    }
  }
  return null;
}
