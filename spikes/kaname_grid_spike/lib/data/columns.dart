/// Column-oriented storage for the grid spike's rows.
///
/// Engine columns use only web-portable typed lists with integers below 2^31,
/// and the sort is total (ties broken by row index), so both compilers give
/// identical results.
///
/// Text and categorical columns are dictionary-encoded: an `Int32List` of
/// codes, the distinct strings, and a precomputed sort rank per code. Rows are
/// never materialised as objects; a row is an index into every column.
///
/// This library is plain Dart: no Flutter, no Riverpod and no web-only
/// imports, so it compiles on the VM, dart2js and dart2wasm.
library;

import 'dart:typed_data';

/// How a [Column] presents its values.
enum ColumnKind {
  /// Dictionary-encoded text or category.
  text,

  /// 32-bit integer below 2^31.
  integer,

  /// 64-bit floating point.
  decimal,

  /// Flag stored as one byte.
  flag,
}

/// A named, typed column of [length] values addressed by row index.
sealed class Column {
  /// Creates a column called [name].
  const Column(this.name);

  /// The column heading.
  final String name;

  /// The number of rows.
  int get length;

  /// The value family of this column.
  ColumnKind get kind;

  /// Formats the value at [row] for display.
  String format(int row);
}

/// A dictionary-encoded text or category column.
final class DictColumn extends Column {
  /// Creates a column from per-row [codes], the distinct [dictionary]
  /// strings, and the sort [ranks] of each code.
  ///
  /// Prefer [DictColumn.fromDictionary], which computes [ranks].
  DictColumn(
    super.name, {
    required this.codes,
    required this.dictionary,
    required this.ranks,
  });

  /// Creates a column from a [dictionary] of distinct strings and per-row
  /// [codes], computing the sort ranks by code-unit order.
  ///
  /// Throws an [ArgumentError] if [dictionary] holds duplicates, since equal
  /// strings would make the rank order ambiguous.
  factory DictColumn.fromDictionary(
    String name, {
    required List<String> dictionary,
    required Int32List codes,
  }) {
    if (dictionary.toSet().length != dictionary.length) {
      throw ArgumentError.value(dictionary, 'dictionary', 'has duplicates');
    }
    final order = List<int>.generate(dictionary.length, (i) => i)
      ..sort((a, b) => dictionary[a].compareTo(dictionary[b]));
    final ranks = Int32List(dictionary.length);
    for (var rank = 0; rank < order.length; rank++) {
      ranks[order[rank]] = rank;
    }
    return DictColumn(name, codes: codes, dictionary: dictionary, ranks: ranks);
  }

  /// The dictionary code of each row.
  final Int32List codes;

  /// The distinct strings; a code indexes this list.
  final List<String> dictionary;

  /// The sort rank of each code, a permutation of `0..dictionary.length-1`.
  final Int32List ranks;

  /// The dictionary strings in lower case, for case-insensitive filtering.
  late final List<String> lowercased = [
    for (final value in dictionary) value.toLowerCase(),
  ];

  @override
  int get length => codes.length;

  @override
  ColumnKind get kind => ColumnKind.text;

  @override
  String format(int row) => dictionary[codes[row]];
}

/// A column of integers below 2^31.
final class IntColumn extends Column {
  /// Creates a column called [name] over [values].
  const IntColumn(super.name, this.values);

  /// The value of each row.
  final Int32List values;

  @override
  int get length => values.length;

  @override
  ColumnKind get kind => ColumnKind.integer;

  @override
  String format(int row) => '${values[row]}';
}

/// A column of 64-bit floating point values.
final class FloatColumn extends Column {
  /// Creates a column called [name] over [values], shown with
  /// [fractionDigits] decimals.
  const FloatColumn(super.name, this.values, {this.fractionDigits = 2});

  /// The value of each row.
  final Float64List values;

  /// The number of decimals [format] shows.
  final int fractionDigits;

  @override
  int get length => values.length;

  @override
  ColumnKind get kind => ColumnKind.decimal;

  @override
  String format(int row) => values[row].toStringAsFixed(fractionDigits);
}

/// A column of flags stored as bytes, 0 for no and 1 for yes.
final class BoolColumn extends Column {
  /// Creates a column called [name] over [values].
  const BoolColumn(super.name, this.values);

  /// The value of each row.
  final Uint8List values;

  @override
  int get length => values.length;

  @override
  ColumnKind get kind => ColumnKind.flag;

  @override
  String format(int row) => values[row] == 0 ? 'No' : 'Yes';
}

/// The columns of one grid, with the four the engine reads by role.
///
/// [name] is what the text filter matches, [category] is what the category
/// filter matches, and [quantity] and [totalValue] are summed per group. Each
/// is also an element of [columns], at the given index.
final class GridColumns {
  /// Creates a grid over [columns].
  ///
  /// Throws an [ArgumentError] if [columns] is empty, the lengths differ, or
  /// a role index points at a column of the wrong type.
  GridColumns({
    required this.columns,
    required this.nameIndex,
    required this.categoryIndex,
    required this.quantityIndex,
    required this.totalValueIndex,
  }) : rowCount = _rowCount(columns),
       name = _dictAt(columns, nameIndex),
       category = _dictAt(columns, categoryIndex),
       quantity = _intAt(columns, quantityIndex),
       totalValue = _floatAt(columns, totalValueIndex);

  /// Every column, in display order.
  final List<Column> columns;

  /// The number of rows in every column.
  final int rowCount;

  /// The index of [name] in [columns].
  final int nameIndex;

  /// The index of [category] in [columns].
  final int categoryIndex;

  /// The index of [quantity] in [columns].
  final int quantityIndex;

  /// The index of [totalValue] in [columns].
  final int totalValueIndex;

  /// The column the text filter matches.
  final DictColumn name;

  /// The column the category filter matches.
  final DictColumn category;

  /// The column summed as a group's quantity.
  final IntColumn quantity;

  /// The column summed as a group's total value.
  final FloatColumn totalValue;

  static int _rowCount(List<Column> columns) {
    if (columns.isEmpty) throw ArgumentError.value(columns, 'columns', 'empty');
    final count = columns.first.length;
    for (final column in columns) {
      if (column.length != count) {
        throw ArgumentError.value(column.name, 'columns', 'length differs');
      }
    }
    return count;
  }

  static DictColumn _dictAt(List<Column> columns, int index) =>
      switch (columns[index]) {
        final DictColumn column => column,
        final other => throw ArgumentError.value(
          other.name,
          'columns[$index]',
          'is not a text column',
        ),
      };

  static IntColumn _intAt(List<Column> columns, int index) =>
      switch (columns[index]) {
        final IntColumn column => column,
        final other => throw ArgumentError.value(
          other.name,
          'columns[$index]',
          'is not an integer column',
        ),
      };

  static FloatColumn _floatAt(List<Column> columns, int index) =>
      switch (columns[index]) {
        final FloatColumn column => column,
        final other => throw ArgumentError.value(
          other.name,
          'columns[$index]',
          'is not a float column',
        ),
      };
}
