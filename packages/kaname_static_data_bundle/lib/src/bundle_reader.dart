/// The reader: checks a bundle and gives access to its sections.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'bundle_format.dart';
import 'bundle_models.dart';
import 'bundle_section.dart';

/// Why a reader refused a bundle.
sealed class BundleRefusal {
  const BundleRefusal();

  /// The short reason, for example `hash mismatch`.
  String get reason;

  /// The reason with the details that explain it.
  String get message;

  @override
  String toString() => message;
}

/// The bundle's SHA-256 is not the announced one.
final class HashMismatch extends BundleRefusal {
  /// Creates the refusal of a bundle hashing to [actual], not [expected].
  const HashMismatch({required this.expected, required this.actual});

  /// The announced SHA-256.
  final String expected;

  /// The SHA-256 of the bytes received.
  final String actual;

  @override
  String get reason => 'hash mismatch';

  @override
  String get message => '$reason: expected $expected, got $actual';
}

/// The bundle's major format version is not one this reader knows.
final class UnsupportedFormat extends BundleRefusal {
  /// Creates the refusal of a bundle of format [bundleMajor].[bundleMinor].
  const UnsupportedFormat({
    required this.bundleMajor,
    required this.bundleMinor,
    required this.supportedMajor,
  });

  /// The bundle's major format version.
  final int bundleMajor;

  /// The bundle's minor format version, or `null` when it names none.
  final int? bundleMinor;

  /// The major format version this reader reads.
  final int supportedMajor;

  @override
  String get reason => 'unsupported bundle format';

  @override
  String get message =>
      '$reason: the bundle is format $bundleMajor.${bundleMinor ?? 0}, '
      'this reader reads format $supportedMajor';
}

/// The bundle holds another build than the one asked for.
final class WrongBuild extends BundleRefusal {
  /// Creates the refusal of a bundle of build [actual], not [expected].
  const WrongBuild({required this.expected, required this.actual});

  /// The build asked for.
  final int expected;

  /// The build the bundle's header names.
  final int actual;

  @override
  String get reason => 'wrong build';

  @override
  String get message => '$reason: asked for build $expected, got $actual';
}

/// The bundle cannot be inflated or parsed.
final class CorruptBundle extends BundleRefusal {
  /// Creates the refusal for [detail].
  const CorruptBundle(this.detail);

  /// What is wrong with the bundle.
  final String detail;

  @override
  String get reason => 'corrupt bundle';

  @override
  String get message => '$reason: $detail';
}

/// The outcome of opening a bundle.
sealed class BundleOpenResult {
  const BundleOpenResult();
}

/// The bundle passed every check.
final class BundleOpened extends BundleOpenResult {
  /// Creates the result holding [bundle].
  const BundleOpened(this.bundle);

  /// The opened bundle.
  final ClientBundle bundle;
}

/// The bundle was refused and must not be used.
final class BundleRefused extends BundleOpenResult {
  /// Creates the result for [refusal].
  const BundleRefused(this.refusal);

  /// Why the bundle was refused.
  final BundleRefusal refusal;
}

/// What a section's header entry says about it.
final class BundleSectionInfo {
  /// Creates the entry.
  const BundleSectionInfo({required this.present, required this.records});

  /// Whether the section has records.
  final bool present;

  /// The count of the section's records.
  final int records;
}

/// A bundle's header line.
final class BundleHeader {
  /// Creates a header.
  const BundleHeader({
    required this.formatMajor,
    required this.formatMinor,
    required this.build,
    required this.releaseDate,
    required this.locales,
    required this.sections,
  });

  /// The major format version.
  final int formatMajor;

  /// The minor format version.
  final int formatMinor;

  /// The SDE build the bundle holds.
  final int build;

  /// The build's release date as CCP writes it, or `null` when unknown.
  final String? releaseDate;

  /// The locales the bundle's names cover.
  final List<String> locales;

  /// The entry of each section this reader knows; unknown ones are left out.
  final Map<BundleSection, BundleSectionInfo> sections;
}

/// One record line of a section.
final class BundleRecord {
  /// Creates a record.
  const BundleRecord({required this.key, required this.typed, this.raw});

  /// The record's SDE key.
  final int key;

  /// The record's typed columns, keyed by CCP's field names.
  final Map<String, Object?> typed;

  /// The record's full JSON, for a section that [BundleSection.carriesRaw].
  final Map<String, Object?>? raw;
}

/// An opened bundle.
///
/// It keeps the inflated bytes and the offset of each section. The sections
/// search needs (types, groups, regions, solar systems) were decoded when it
/// was opened; any other section is decoded only when [records] asks for it,
/// and is not kept.
abstract interface class ClientBundle {
  /// The bundle's header.
  BundleHeader get header;

  /// The bundle's types, in key order.
  List<BundleType> get types;

  /// The bundle's groups, in key order.
  List<BundleGroup> get groups;

  /// The bundle's regions, in key order.
  List<BundleRegion> get regions;

  /// The bundle's solar systems, in key order.
  List<BundleSolarSystem> get solarSystems;

  /// Decodes the records of [section], in the bundle's order.
  ///
  /// Returns an empty list for an absent section. Throws a
  /// [FormatException] when a line of the section is malformed.
  List<BundleRecord> records(BundleSection section);
}

/// Opens the downloaded gzip bundle [compressed].
///
/// Checks, in this order, that its SHA-256 is [sha256] ([HashMismatch]),
/// that it inflates and parses ([CorruptBundle]), that its major format is
/// [bundleFormatMajor] ([UnsupportedFormat]; any minor is accepted) and
/// that it holds build [build] ([WrongBuild]).
BundleOpenResult openBundle(
  Uint8List compressed, {
  required int build,
  required String sha256,
}) {
  final actual = bundleSha256(compressed);
  if (actual != sha256.toLowerCase()) {
    return BundleRefused(HashMismatch(expected: sha256, actual: actual));
  }
  final Uint8List inflated;
  try {
    inflated = inflateGzip(compressed);
  } on FormatException catch (error) {
    return BundleRefused(CorruptBundle(error.message));
  }
  return openInflatedBundle(inflated, build: build);
}

/// Opens the already inflated bundle [inflated], whose compressed bytes'
/// hash the caller has checked.
///
/// The web app hashes and inflates with the browser's own APIs (design
/// D12) and starts here; checks as [openBundle] does after its hash.
BundleOpenResult openInflatedBundle(Uint8List inflated, {required int build}) {
  try {
    switch (_prepare(inflated, build)) {
      case _Rejected(:final refused):
        return refused;
      case _Ready(:final bundle):
        // A chunk no bundle fills, so the decoding never pauses.
        bundle._decodeSearchSections(_onePass).forEach((_) {});
        return BundleOpened(bundle);
    }
  } on FormatException catch (error) {
    return BundleRefused(CorruptBundle(error.message));
  }
}

/// Opens the already inflated bundle [inflated] as [openInflatedBundle]
/// does, but decodes it in chunks of [linesPerChunk] record lines and yields
/// to the event loop between chunks.
///
/// The web app's Dart code runs on the browser's main thread (design D12),
/// where one long synchronous parse would freeze the page. The bundle and
/// the refusals are the same as the one-pass open gives. Throws an
/// [ArgumentError] when [linesPerChunk] is below one.
Future<BundleOpenResult> openInflatedBundleChunked(
  Uint8List inflated, {
  required int build,
  int linesPerChunk = 2000,
}) async {
  if (linesPerChunk < 1) {
    throw ArgumentError.value(linesPerChunk, 'linesPerChunk', 'below one');
  }
  try {
    switch (_prepare(inflated, build)) {
      case _Rejected(:final refused):
        return refused;
      case _Ready(:final bundle):
        for (final _ in bundle._decodeSearchSections(linesPerChunk)) {
          // A timer, not a microtask: only a timer lets the browser paint
          // and handle input.
          await Future<void>.delayed(Duration.zero);
        }
        return BundleOpened(bundle);
    }
  } on FormatException catch (error) {
    return BundleRefused(CorruptBundle(error.message));
  }
}

const _lineFeed = 0x0a;
const _openBrace = 0x7b;

/// A chunk size no bundle reaches: the one-pass open never pauses.
///
/// It is the largest integer JavaScript represents exactly, so the
/// reader also compiles for the web.
const _onePass = 0x1fffffffffffff;

/// What the cheap first step of an open found: a bundle whose search
/// sections are still to decode, or a refusal.
sealed class _Prepared {
  const _Prepared();
}

final class _Ready extends _Prepared {
  const _Ready(this.bundle);

  final _Bundle bundle;
}

final class _Rejected extends _Prepared {
  const _Rejected(this.refused);

  final BundleRefused refused;
}

/// Checks the header and indexes the sections of [bytes], without decoding a
/// record line.
_Prepared _prepare(Uint8List bytes, int build) {
  final headerEnd = bytes.indexOf(_lineFeed);
  if (headerEnd < 0) throw const FormatException('no header line');
  final header = switch (_decodeJson(bytes, 0, headerEnd)) {
    final Map<String, Object?> header => header,
    _ => throw const FormatException('the header is not a JSON object'),
  };
  final major = switch (header['formatMajor']) {
    final int major => major,
    _ => throw const FormatException('the header has no formatMajor'),
  };
  if (major != bundleFormatMajor) {
    return _Rejected(
      BundleRefused(
        UnsupportedFormat(
          bundleMajor: major,
          bundleMinor: switch (header['formatMinor']) {
            final int minor => minor,
            _ => null,
          },
          supportedMajor: bundleFormatMajor,
        ),
      ),
    );
  }
  final bundleBuild = switch (header['build']) {
    final int build => build,
    _ => throw const FormatException('the header has no build'),
  };
  if (bundleBuild != build) {
    return _Rejected(
      BundleRefused(WrongBuild(expected: build, actual: bundleBuild)),
    );
  }
  final bundle = _Bundle(bytes, _parseHeader(header, bundleBuild))
    .._index(headerEnd + 1);
  return _Ready(bundle);
}

BundleHeader _parseHeader(Map<String, Object?> header, int build) {
  final sections = <BundleSection, BundleSectionInfo>{};
  for (final entry in _list(header['sections'], 'sections')) {
    switch (entry) {
      case {
        'file': final String file,
        'present': final bool present,
        'records': final int records,
      }:
        final section = BundleSection.fromFile(file);
        if (section != null) {
          sections[section] = BundleSectionInfo(
            present: present,
            records: records,
          );
        }
      default:
        throw FormatException('malformed section entry in the header', entry);
    }
  }
  return BundleHeader(
    formatMajor: bundleFormatMajor,
    formatMinor: switch (header['formatMinor']) {
      final int minor => minor,
      _ => throw const FormatException('the header has no formatMinor'),
    },
    build: build,
    releaseDate: switch (header['releaseDate']) {
      final String? date => date,
      final other => throw FormatException('malformed releaseDate', other),
    },
    locales: [
      for (final locale in _list(header['locales'], 'locales'))
        switch (locale) {
          final String locale => locale,
          _ => throw FormatException('malformed locale', locale),
        },
    ],
    sections: sections,
  );
}

List<Object?> _list(Object? value, String name) => switch (value) {
  final List<Object?> list => list,
  _ => throw FormatException('the header has no $name list'),
};

Object? _decodeJson(Uint8List bytes, int start, int end) =>
    jsonDecode(utf8.decode(Uint8List.sublistView(bytes, start, end)));

final class _Bundle implements ClientBundle {
  _Bundle(this._bytes, this.header);

  final Uint8List _bytes;

  @override
  final BundleHeader header;

  /// The byte range of each known section's record lines.
  final Map<BundleSection, (int, int)> _ranges = {};

  @override
  late final List<BundleType> types;

  @override
  late final List<BundleGroup> groups;

  @override
  late final List<BundleRegion> regions;

  @override
  late final List<BundleSolarSystem> solarSystems;

  /// Records where each section's record lines start and end, from [start].
  ///
  /// Only section marker lines are decoded; record lines start with `[` and
  /// are skipped. Unknown sections are passed over.
  void _index(int start) {
    BundleSection? current;
    var currentStart = start;
    var position = start;
    void close(int end) {
      if (current != null) _ranges[current] = (currentStart, end);
    }

    while (position < _bytes.length) {
      var end = _bytes.indexOf(_lineFeed, position);
      if (end < 0) end = _bytes.length;
      if (_bytes[position] == _openBrace) {
        close(position);
        current = switch (_decodeJson(_bytes, position, end)) {
          {'section': final String file} => BundleSection.fromFile(file),
          final other => throw FormatException('malformed section line', other),
        };
        currentStart = end + 1;
      }
      position = end + 1;
    }
    close(_bytes.length);
  }

  /// The count of record lines decoded since the last pause.
  int _sinceYield = 0;

  /// Decodes the sections search needs, pausing after every [linesPerChunk]
  /// record lines.
  ///
  /// The pauses are the iterable's elements: the one-pass open drains it at
  /// once, the chunked open awaits the event loop at each.
  Iterable<void> _decodeSearchSections(int linesPerChunk) sync* {
    final typeList = <BundleType>[];
    yield* _decodeSection(BundleSection.types, linesPerChunk, (record) {
      typeList.add(_type(record.key, _Fields(record, BundleSection.types)));
    });
    types = typeList;
    final groupList = <BundleGroup>[];
    yield* _decodeSection(BundleSection.groups, linesPerChunk, (record) {
      groupList.add(_group(record.key, _Fields(record, BundleSection.groups)));
    });
    groups = groupList;
    final regionList = <BundleRegion>[];
    yield* _decodeSection(BundleSection.mapRegions, linesPerChunk, (record) {
      regionList.add(
        _region(record.key, _Fields(record, BundleSection.mapRegions)),
      );
    });
    regions = regionList;
    final systemList = <BundleSolarSystem>[];
    yield* _decodeSection(BundleSection.mapSolarSystems, linesPerChunk, (
      record,
    ) {
      systemList.add(
        _solarSystem(
          record.key,
          _Fields(record, BundleSection.mapSolarSystems),
        ),
      );
    });
    solarSystems = systemList;
  }

  Iterable<void> _decodeSection(
    BundleSection section,
    int linesPerChunk,
    void Function(BundleRecord record) add,
  ) sync* {
    for (final record in _recordLines(section)) {
      add(record);
      if (++_sinceYield >= linesPerChunk) {
        _sinceYield = 0;
        yield null;
      }
    }
  }

  @override
  List<BundleRecord> records(BundleSection section) =>
      _recordLines(section).toList();

  /// Decodes the record lines of [section] one at a time.
  Iterable<BundleRecord> _recordLines(BundleSection section) sync* {
    final range = _ranges[section];
    if (range == null) return;
    final (start, end) = range;
    var position = start;
    while (position < end) {
      var lineEnd = _bytes.indexOf(_lineFeed, position);
      if (lineEnd < 0 || lineEnd > end) lineEnd = end;
      if (lineEnd > position) {
        yield switch (_decodeJson(_bytes, position, lineEnd)) {
          [
            final int key,
            final Map<String, Object?> typed,
            final Map<String, Object?>? raw,
          ] =>
            BundleRecord(key: key, typed: typed, raw: raw),
          final other => throw FormatException(
            'malformed record line in section ${section.file}',
            other,
          ),
        };
      }
      position = lineEnd + 1;
    }
  }
}

BundleType _type(int id, _Fields fields) => BundleType(
  id: id,
  name: fields.localized('name'),
  groupId: fields.integer('groupID'),
  published: fields.boolean('published') ?? false,
  volume: fields.real('volume'),
  capacity: fields.real('capacity'),
  portionSize: fields.integer('portionSize'),
  mass: fields.real('mass'),
  marketGroupId: fields.integer('marketGroupID'),
  metaGroupId: fields.integer('metaGroupID'),
  radius: fields.real('radius'),
  factionId: fields.integer('factionID'),
  raceId: fields.integer('raceID'),
  variationParentTypeId: fields.integer('variationParentTypeID'),
);

BundleGroup _group(int id, _Fields fields) => BundleGroup(
  id: id,
  name: fields.localized('name'),
  categoryId: fields.integer('categoryID'),
  published: fields.boolean('published') ?? false,
);

BundleRegion _region(int id, _Fields fields) => BundleRegion(
  id: id,
  name: fields.localized('name'),
  factionId: fields.integer('factionID'),
);

BundleSolarSystem _solarSystem(int id, _Fields fields) => BundleSolarSystem(
  id: id,
  name: fields.localized('name'),
  constellationId: fields.integer('constellationID'),
  regionId: fields.integer('regionID'),
  securityStatus: fields.real('securityStatus'),
  securityClass: fields.text('securityClass'),
);

/// Typed access to one record's `typed` object; a value of another JSON
/// type than expected is a [FormatException].
extension type _Fields._((BundleRecord, BundleSection) _of) {
  _Fields(BundleRecord record, BundleSection section)
    : this._((record, section));

  Object? _value(String field) => _of.$1.typed[field];

  Never _wrong(String field) => throw FormatException(
    'record ${_of.$1.key} of section ${_of.$2.file} has a malformed $field',
    _value(field),
  );

  int? integer(String field) => switch (_value(field)) {
    final int? value => value,
    _ => _wrong(field),
  };

  double? real(String field) => switch (_value(field)) {
    final num value => value.toDouble(),
    null => null,
    _ => _wrong(field),
  };

  bool? boolean(String field) => switch (_value(field)) {
    final bool? value => value,
    _ => _wrong(field),
  };

  String? text(String field) => switch (_value(field)) {
    final String? value => value,
    _ => _wrong(field),
  };

  LocalizedText localized(String field) => switch (_value(field)) {
    null => LocalizedText.none,
    final Map<String, Object?> byLocale => LocalizedText({
      for (final MapEntry(:key, :value) in byLocale.entries)
        key: switch (value) {
          final String text => text,
          _ => _wrong(field),
        },
    }),
    _ => _wrong(field),
  };
}

/// The SHA-256 of [bytes] as 64 lower-case hexadecimal digits.
String bundleSha256(List<int> bytes) => crypto.sha256.convert(bytes).toString();
