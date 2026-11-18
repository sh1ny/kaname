/// The seams between the grid notifier and the seed and engine functions, and
/// the startup self-check of the seed.
///
/// [GridSeeder] and [GridEngine] are interfaces so tests can replace the
/// 200,000-row seed and the engine with small fakes. The default
/// implementations only call [buildSeed] and [runGrid].
///
/// This library is plain Dart: no Flutter, no Riverpod and no web-only
/// imports.
library;

import 'columns.dart';
import 'grid_engine.dart';
import 'prng.dart';
import 'seed.dart';

/// Builds the grid's columns.
abstract interface class GridSeeder {
  /// Builds the columns and reports how long that took.
  SeedResult seed();
}

/// Runs a [GridQuery] over columns.
abstract interface class GridEngine {
  /// Returns the view of [columns] under [query].
  GridRowView run(GridColumns columns, GridQuery query);
}

/// A [GridSeeder] that calls [buildSeed].
final class GeneratedSeeder implements GridSeeder {
  /// Creates the seeder.
  const GeneratedSeeder();

  @override
  SeedResult seed() => buildSeed();
}

/// A [GridEngine] that calls [runGrid].
final class ColumnEngine implements GridEngine {
  /// Creates the engine.
  const ColumnEngine();

  @override
  GridRowView run(GridColumns columns, GridQuery query) =>
      runGrid(columns, query);
}

/// The startup self-check that failed.
///
/// Carries no exception text, so a screen can name the check without leaking
/// internals.
sealed class SeedCheck {
  const SeedCheck();
}

/// The generator's first outputs differ from [prngGolden].
final class PrngGoldenMismatch extends SeedCheck {
  /// Creates the failure.
  const PrngGoldenMismatch();

  @override
  bool operator ==(Object other) => other is PrngGoldenMismatch;

  @override
  int get hashCode => (PrngGoldenMismatch).hashCode;
}

/// The seed has another row or column count than [seedRowCount] by
/// [seedColumnCount].
final class ShapeMismatch extends SeedCheck {
  /// Creates the failure for the [rows] and [columns] that were found.
  const ShapeMismatch({required this.rows, required this.columns});

  /// The number of rows found.
  final int rows;

  /// The number of columns found.
  final int columns;

  @override
  bool operator ==(Object other) =>
      other is ShapeMismatch && other.rows == rows && other.columns == columns;

  @override
  int get hashCode => Object.hash(rows, columns);
}

/// The checksum of a column differs from [seedChecksums].
final class ChecksumMismatch extends SeedCheck {
  /// Creates the failure for the column at [index] called [columnName].
  const ChecksumMismatch({required this.index, required this.columnName});

  /// The index of the column in the seed.
  final int index;

  /// The heading of the column.
  final String columnName;

  @override
  bool operator ==(Object other) =>
      other is ChecksumMismatch &&
      other.index == index &&
      other.columnName == columnName;

  @override
  int get hashCode => Object.hash(index, columnName);
}

/// Checks [result] against the golden values and returns the first check that
/// failed, or `null` when all pass.
///
/// The checks run in order: the generator's first outputs against [golden],
/// the row and column counts, then each column's checksum. A divergence in
/// how a compiler computes integers shows up here instead of as silent wrong
/// data. Pass another [golden] only to test the check.
SeedCheck? selfCheck(SeedResult result, {List<int> golden = prngGolden}) {
  final prng = Xorshift32(goldenSeed);
  for (final expected in golden) {
    if (prng.next() != expected) return const PrngGoldenMismatch();
  }
  final columns = result.columns;
  if (columns.rowCount != seedRowCount ||
      columns.columns.length != seedColumnCount) {
    return ShapeMismatch(
      rows: columns.rowCount,
      columns: columns.columns.length,
    );
  }
  for (var index = 0; index < columns.columns.length; index++) {
    final column = columns.columns[index];
    if (checksumColumn(column) != seedChecksums[index]) {
      return ChecksumMismatch(index: index, columnName: column.name);
    }
  }
  return null;
}
