/// A [StaticDataStore] that keeps everything in memory.
library;

import 'dart:typed_data';

import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart'
    show bundleFormatMajor, bundleFormatMinor;

import 'sde_rows.dart';
import 'static_data_store.dart';
import 'stored_bundle.dart';
import 'typed_files.dart';

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
/// given and a commit removes no other build (the import drops the staged
/// build first, with [dropStagedBuild]).
final class InMemoryStaticDataStore implements StaticDataStore {
  /// Creates a store; stores created with the same [lock] exclude each other.
  InMemoryStaticDataStore({InMemoryLock? lock}) : lock = lock ?? InMemoryLock();

  /// The lock this store takes.
  final InMemoryLock lock;

  final Map<int, BuildState> _builds = {};
  final Map<int, Map<String, List<TypedRow>>> _typed = {};
  final Map<int, List<RawRecord>> _raw = {};
  final List<StoredImportRecord> _records = [];
  final Set<int> _held = {};
  final List<CheckRecord> _checks = [];
  final List<SwitchRecord> _switches = [];
  final List<BuildDiffRecord> _diffs = [];
  final Map<int, StoredBundle> _bundles = {};
  final Map<int, ({String sha256, Uint8List bytes})> _bundleBytes = {};
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

  /// The builds that are held.
  Set<int> get heldBuilds => Set.unmodifiable(_held);

  /// The import records, oldest first.
  List<StoredImportRecord> get records => List.unmodifiable(_records);

  /// The check records, oldest first.
  List<CheckRecord> get checks => List.unmodifiable(_checks);

  /// The switch and rollback records, oldest first.
  List<SwitchRecord> get switches => List.unmodifiable(_switches);

  /// The stored comparisons, oldest first.
  List<BuildDiffRecord> get diffs => List.unmodifiable(_diffs);

  /// The stored bundle metadata, by build.
  Map<int, StoredBundle> get bundles => Map.unmodifiable(_bundles);

  /// The stored bundle bytes of [build] with their hash, or `null`.
  ({String sha256, Uint8List bytes})? bundleBytesOf(int build) =>
      _bundleBytes[build];

  /// Puts bundle metadata for [build] with no bytes, for tests that start
  /// from a stored bundle, such as one of another format version.
  void seedBundle(StoredBundle bundle) => _bundles[bundle.build] = bundle;

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
  void seedBuild(int build, BuildState state, {bool held = false}) {
    _builds[build] = state;
    if (held) {
      _held.add(build);
    } else {
      _held.remove(build);
    }
  }

  void _removeBuild(int build) {
    _builds.remove(build);
    _typed.remove(build);
    _raw.remove(build);
    _held.remove(build);
    _bundles.remove(build);
    _bundleBytes.remove(build);
    _diffs.removeWhere((d) => d.fromBuild == build || d.toBuild == build);
  }

  int? _buildIn(BuildState state) {
    for (final MapEntry(:key, :value) in _builds.entries) {
      if (value == state) return key;
    }
    return null;
  }

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
  Future<List<StoredBuild>> storedBuilds() async => [
    for (final build in _builds.keys.toList()..sort())
      StoredBuild(
        build: build,
        state: _builds[build]!,
        held: _held.contains(build),
      ),
  ];

  @override
  Future<int?> dropStagedBuild() async {
    final staged = _buildIn(BuildState.staged);
    if (staged != null) _removeBuild(staged);
    return staged;
  }

  @override
  Future<void> insertCheck(CheckRecord record) async => _checks.add(record);

  @override
  Future<DateTime?> newestCheckedAt() async {
    DateTime? newest;
    for (final CheckRecord(:checkedAt) in _checks) {
      if (newest == null || checkedAt.isAfter(newest)) newest = checkedAt;
    }
    return newest;
  }

  @override
  Future<void> pruneChecks({required int keep}) async =>
      _keepNewest(_checks, keep, (c) => c.checkedAt);

  @override
  Future<void> insertFailedSwitch(SwitchRecord record) async {
    if (record.outcome != SwitchOutcome.failed) {
      throw ArgumentError.value(record, 'record', 'must be a failed switch');
    }
    _switches.add(record);
  }

  @override
  Future<void> pruneSwitches({required int keep}) async =>
      _keepNewest(_switches, keep, (s) => s.at);

  @override
  Future<void> insertDiff(BuildDiffRecord record) async => _diffs.add(record);

  @override
  Future<BuildDiffRecord?> diff(int fromBuild, int toBuild) async {
    BuildDiffRecord? newest;
    for (final record in _diffs) {
      if (record.fromBuild != fromBuild || record.toBuild != toBuild) continue;
      if (newest == null || !record.createdAt.isBefore(newest.createdAt)) {
        newest = record;
      }
    }
    return newest;
  }

  @override
  Future<List<TypedRow>> readTypedRows(int build, TypedFile file) async =>
      typedRows(build, file.table);

  @override
  Future<List<RawRecord>> readRawRecords(int build, String file) async =>
      rawRecordsOf(build, file)..sort((a, b) => a.line.compareTo(b.line));

  @override
  Future<StoredBundle?> storedBundle(int build) async => _bundles[build];

  @override
  Future<void> recordBundle(BundleWrite write) async {
    switch (write) {
      case BundleWriteBuilt(:final build, :final at, :final built):
        _bundles[build] = StoredBundle(
          build: build,
          outcome: BundleOutcome.built,
          formatMajor: bundleFormatMajor,
          formatMinor: bundleFormatMinor,
          builtAt: at,
          sha256: built.sha256,
          size: built.bytes.length,
        );
        _bundleBytes[build] = (sha256: built.sha256, bytes: built.bytes);
      case BundleWriteFailed(:final build, :final at, :final reason):
        _bundles[build] = StoredBundle(
          build: build,
          outcome: BundleOutcome.failed,
          formatMajor: bundleFormatMajor,
          formatMinor: bundleFormatMinor,
          builtAt: at,
          reason: reason,
        );
        _bundleBytes.remove(build);
    }
  }

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(StaticDataWriter writer) body,
  ) async {
    final transaction = _Transaction(this);
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

/// Keeps the newest [keep] of [items] by [timeOf], dropping the rest.
void _keepNewest<T>(List<T> items, int keep, DateTime Function(T) timeOf) {
  if (items.length <= keep) return;
  final indexed = [for (final (i, item) in items.indexed) (i, item)]
    ..sort((a, b) {
      final byTime = timeOf(b.$2).compareTo(timeOf(a.$2));
      return byTime != 0 ? byTime : b.$1.compareTo(a.$1);
    });
  final kept = indexed.take(keep).map((e) => e.$1).toSet();
  final survivors = [
    for (final (i, item) in items.indexed)
      if (kept.contains(i)) item,
  ];
  items
    ..clear()
    ..addAll(survivors);
}

final class _Transaction implements StaticDataWriter {
  _Transaction(this._store);

  final InMemoryStaticDataStore _store;
  final List<void Function(InMemoryStaticDataStore store)> _writes = [];

  @override
  Future<void> switchTo(int build, {required DateTime at}) async {
    if (_store._builds[build] != BuildState.staged) {
      throw StateError('build $build is not staged');
    }
    final fromBuild = _store._buildIn(BuildState.active);
    _writes.add((store) {
      final oldPrevious = store._buildIn(BuildState.previous);
      if (oldPrevious != null) store._removeBuild(oldPrevious);
      if (fromBuild != null) store._builds[fromBuild] = BuildState.previous;
      store._builds[build] = BuildState.active;
      store._held.removeWhere((held) => held < build);
      store._switches.add(
        SwitchRecord(
          kind: SwitchKind.forward,
          fromBuild: fromBuild,
          toBuild: build,
          at: at,
          outcome: SwitchOutcome.succeeded,
        ),
      );
    });
  }

  @override
  Future<void> rollBack({required DateTime at}) async {
    final active = _store._buildIn(BuildState.active);
    final previous = _store._buildIn(BuildState.previous);
    if (active == null || previous == null) {
      throw StateError('no previous build to roll back to');
    }
    _writes.add((store) {
      store._builds[active] = BuildState.previous;
      store._builds[previous] = BuildState.active;
      store._held
        ..add(active)
        ..remove(previous);
      store._switches.add(
        SwitchRecord(
          kind: SwitchKind.rollback,
          fromBuild: active,
          toBuild: previous,
          at: at,
          outcome: SwitchOutcome.succeeded,
        ),
      );
    });
  }

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
