/// A [StaticDataStore] that keeps everything in memory.
library;

import 'sde_rows.dart';
import 'static_data_store.dart';

/// A stored import record with its id.
final class StoredImportRecord {
  /// Creates the pair.
  const StoredImportRecord(this.id, this.record);

  /// The record's id.
  final int id;

  /// The record.
  final ImportRecord record;
}

/// A hand-written fake of [StaticDataStore] for tests and solo mode.
///
/// It models the lock (one holder at a time across stores that share a
/// [InMemoryStaticDataStore.lock]), transactions that discard their writes
/// when the body throws, and the commit rules: a build is `active` only as
/// given, the other staged builds go in the same commit, and the active
/// build is never removed.
final class InMemoryStaticDataStore implements StaticDataStore {
  /// Creates a store; stores created with the same [lock] exclude each other.
  InMemoryStaticDataStore({InMemoryLock? lock}) : lock = lock ?? InMemoryLock();

  /// The lock this store takes.
  final InMemoryLock lock;

  final Map<int, BuildState> _builds = {};
  final Map<int, Map<String, List<TypedRow>>> _typed = {};
  final Map<int, List<RawRecord>> _raw = {};
  final List<StoredImportRecord> _records = [];
  int _nextRecordId = 1;
  bool _holdsLock = false;

  /// How many transactions were committed.
  int committedTransactions = 0;

  /// How many rows (typed and raw) were written by committed transactions.
  int rowsWritten = 0;

  /// Whether [close] was called.
  bool isClosed = false;

  /// The stored builds and their states.
  Map<int, BuildState> get builds => Map.unmodifiable(_builds);

  /// The import records, oldest first.
  List<StoredImportRecord> get records => List.unmodifiable(_records);

  /// The typed rows of [table] for [build].
  List<TypedRow> typedRows(int build, String table) =>
      List.unmodifiable(_typed[build]?[table] ?? const []);

  /// The untyped records for [build].
  List<RawRecord> rawRecords(int build) =>
      List.unmodifiable(_raw[build] ?? const []);

  /// The untyped records of [file] for [build].
  List<RawRecord> rawRecordsOf(int build, String file) => [
    for (final record in rawRecords(build))
      if (record.file == file) record,
  ];

  /// Puts an already stored build, for tests that start from one.
  void seedBuild(int build, BuildState state) => _builds[build] = state;

  @override
  Future<bool> tryLock() async {
    if (lock.isHeld) return false;
    lock.isHeld = true;
    _holdsLock = true;
    return true;
  }

  @override
  Future<void> unlock() async {
    if (_holdsLock) {
      lock.isHeld = false;
      _holdsLock = false;
    }
  }

  @override
  Future<int> failRunningRecords({
    required String reason,
    required DateTime at,
  }) async {
    var changed = 0;
    for (var i = 0; i < _records.length; i++) {
      final StoredImportRecord(:id, :record) = _records[i];
      if (record.outcome != ImportOutcome.running) continue;
      _records[i] = StoredImportRecord(
        id,
        record.finished(ImportOutcome.failed, at: at, failureReason: reason),
      );
      changed++;
    }
    return changed;
  }

  @override
  Future<int> insertRecord(ImportRecord record) async {
    final id = _nextRecordId++;
    _records.add(StoredImportRecord(id, record));
    return id;
  }

  @override
  Future<void> updateRecord(int id, ImportRecord record) async {
    final index = _records.indexWhere((stored) => stored.id == id);
    if (index < 0) throw StateError('no import record $id');
    _records[index] = StoredImportRecord(id, record);
  }

  @override
  Future<void> pruneRecords({required int keep}) async {
    if (_records.length <= keep) return;
    final newest = [..._records]
      ..sort((a, b) {
        final byStart = b.record.startedAt.compareTo(a.record.startedAt);
        return byStart != 0 ? byStart : b.id.compareTo(a.id);
      });
    final kept = newest.take(keep).map((stored) => stored.id).toSet();
    _records.removeWhere((stored) => !kept.contains(stored.id));
  }

  @override
  Future<bool> hasBuild(int build) async => _builds.containsKey(build);

  @override
  Future<bool> hasActiveBuild() async =>
      _builds.values.any((state) => state == BuildState.active);

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(StaticDataWriter writer) body,
  ) async {
    final transaction = _Transaction();
    final result = await body(transaction);
    transaction.applyTo(this);
    committedTransactions++;
    return result;
  }

  @override
  Future<void> close() async {
    isClosed = true;
    await unlock();
  }
}

/// The lock that [InMemoryStaticDataStore]s share, standing in for the
/// database's advisory lock.
final class InMemoryLock {
  /// Whether a store holds the lock.
  bool isHeld = false;
}

final class _Transaction implements StaticDataWriter {
  final List<void Function(InMemoryStaticDataStore store)> _writes = [];

  @override
  Future<void> insertTyped(int build, List<TypedRow> rows) async {
    final copy = [...rows];
    _writes.add((store) {
      for (final row in copy) {
        ((store._typed[build] ??= {})[row.table] ??= []).add(row);
      }
      store.rowsWritten += copy.length;
    });
  }

  @override
  Future<void> insertRaw(int build, List<RawRecord> records) async {
    final copy = [...records];
    _writes.add((store) {
      (store._raw[build] ??= []).addAll(copy);
      store.rowsWritten += copy.length;
    });
  }

  @override
  Future<void> commitBuild({
    required int build,
    required BuildState state,
    required DateTime importedAt,
    required int recordId,
    required ImportRecord record,
  }) async {
    _writes.add((store) {
      final staged = [
        for (final MapEntry(:key, :value) in store._builds.entries)
          if (value == BuildState.staged && key != build) key,
      ];
      for (final other in staged) {
        store._builds.remove(other);
        store._typed.remove(other);
        store._raw.remove(other);
      }
      store._builds[build] = state;
      store.rowsWritten++;
      final index = store._records.indexWhere((s) => s.id == recordId);
      store._records[index] = StoredImportRecord(recordId, record);
    });
  }

  void applyTo(InMemoryStaticDataStore store) {
    for (final write in _writes) {
      write(store);
    }
  }
}
