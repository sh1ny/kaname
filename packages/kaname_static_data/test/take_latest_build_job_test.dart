import 'dart:io';

import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:test/test.dart';

final _t0 = DateTime.utc(2026, 3, 10, 12);

void main() {
  late Directory scratch;
  late Directory zips;
  late InMemoryStaticDataStore store;
  late _FakeCcp ccp;

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('kaname_check_scratch_');
    zips = Directory.systemTemp.createTempSync('kaname_check_zips_');
    store = InMemoryStaticDataStore();
    ccp = _FakeCcp(zips, scratch);
  });
  tearDown(() {
    expect(scratch.listSync(), isEmpty, reason: 'the job leaves no temp files');
    scratch.deleteSync(recursive: true);
    zips.deleteSync(recursive: true);
  });

  Future<BuildCheckResult> check({
    StaticDataDiffer? differ,
    InMemoryStaticDataStore? on,
    StaticDataStore? using,
    DateTime Function()? clock,
  }) {
    final target = on ?? store;
    return TakeLatestBuildJob(
      store: using ?? target,
      source: ccp,
      differ: differ ?? InMemoryStaticDataDiffer(target),
      clock: clock ?? () => _t0,
      scratchRoot: scratch,
    ).run();
  }

  void expectClean({InMemoryStaticDataStore? on}) {
    final target = on ?? store;
    expect(target.isClosed, isTrue);
    expect(target.lock.isHeld, isFalse);
  }

  group('Given the active build 1000', () {
    setUp(() => store.seedBuild(1000, BuildState.active));

    test('a newer announced build is imported, compared and '
        'switched', () async {
      ccp.announce(1001);

      final result = await check();

      expect(result, isA<BuildSwitched>());
      expect((result as BuildSwitched).build, 1001);
      expect(store.builds, {
        1000: BuildState.previous,
        1001: BuildState.active,
      });
      final BuildDiffRecord(:fromBuild, :toBuild, :outcome) =
          store.diffs.single;
      expect(
        (fromBuild, toBuild, outcome),
        (1000, 1001, DiffOutcome.succeeded),
      );
      expect(store.switches.single.kind, SwitchKind.forward);
      final CheckRecord(:checkedAt, :latestBuild, outcome: checkOutcome) =
          store.checks.single;
      expect(
        (checkedAt, latestBuild, checkOutcome),
        (_t0, 1001, CheckOutcome.switched),
      );
      expectClean();
    });

    test('the active build announced gives up to date', () async {
      ccp.announce(1000);

      final result = await check();

      expect(result, isA<BuildUpToDate>());
      expect(ccp.opens, 0);
      expect(store.builds, {1000: BuildState.active});
      expect(store.checks.single.outcome, CheckOutcome.upToDate);
      expect(store.checks.single.latestBuild, 1000);
      expectClean();
    });

    test('an older announced build gives outcome older', () async {
      ccp.announce(999);

      final result = await check();

      expect(result, isA<BuildOlder>());
      expect(ccp.opens, 0);
      final CheckRecord(:outcome, :latestBuild) = store.checks.single;
      expect((outcome, latestBuild), (CheckOutcome.older, 999));
      expect(store.builds, {1000: BuildState.active});
      expectClean();
    });

    test('unreachable CCP records a failed check and keeps the active '
        'build', () async {
      ccp.unreachable('CCP unreachable: connection refused');

      final result = await check();

      expect(
        (result as BuildCheckFailed).reason,
        'CCP unreachable: connection refused',
      );
      final CheckRecord(:outcome, :failureReason, :latestBuild) =
          store.checks.single;
      expect(
        (outcome, failureReason, latestBuild),
        (CheckOutcome.failed, 'CCP unreachable: connection refused', null),
      );
      expect(store.builds, {1000: BuildState.active});
      expectClean();
    });

    test('a check while the lock is held records import already '
        'running', () async {
      ccp.announce(1001);
      final holder = InMemoryStaticDataStore(lock: store.lock);
      expect(await holder.tryLock(), isTrue);

      final result = await check();

      expect((result as BuildCheckFailed).reason, 'import already running');
      final CheckRecord(:outcome, :failureReason) = store.checks.single;
      expect(
        (outcome, failureReason),
        (CheckOutcome.failed, 'import already running'),
      );
      expect(ccp.opens, 0);
      expect(store.builds, {1000: BuildState.active});
      expect(store.isClosed, isTrue);
      expect(holder.lock.isHeld, isTrue, reason: 'the holder keeps its lock');
    });

    test('a held announced build gives outcome held', () async {
      // 1001 was rolled back from and is held; CCP still names it.
      store
        ..seedBuild(1000, BuildState.active)
        ..seedBuild(1001, BuildState.previous, held: true);
      ccp.announce(1001);

      final result = await check();

      expect((result as BuildHeld).build, 1001);
      expect(ccp.opens, 0);
      expect(store.checks.single.outcome, CheckOutcome.held);
      expect(store.checks.single.latestBuild, 1001);
      expect(store.switches, isEmpty);
      expectClean();
    });

    test('a newer build lifts the hold and makes the rolled-back-to build '
        'previous', () async {
      // 1001 was rolled back from: 1000 is active again, 1001 is previous
      // and held.
      store
        ..seedBuild(1000, BuildState.active)
        ..seedBuild(1001, BuildState.previous, held: true);
      ccp.announce(1002);

      final result = await check();

      expect(result, isA<BuildSwitched>());
      expect(store.builds, {
        1000: BuildState.previous,
        1002: BuildState.active,
      });
      expect(store.heldBuilds, isEmpty);
      expectClean();
    });

    test('a staged development import gets its report when switched '
        'to', () async {
      final fixture = SdeFixture.complete(build: 1001);
      final imported = await ImportSdeJob(
        store: store,
        source: LocalZipSdeSource(fixture.writeTo(zips), scratchRoot: scratch),
        scratchRoot: scratch,
      ).run();
      expect(imported, isA<ImportSucceeded>());
      expect(store.builds[1001], BuildState.staged);
      expect(store.diffs, isEmpty);
      store.isClosed = false;
      ccp.announce(1001);

      final result = await check();

      expect(result, isA<BuildSwitched>());
      expect(ccp.opens, 0, reason: 'the staged build is not imported again');
      expect(store.diffs.single.outcome, DiffOutcome.succeeded);
      expect(store.builds[1001], BuildState.active);
      expect(store.checks.single.outcome, CheckOutcome.switched);
      expectClean();
    });

    test('a staged build left by a failed switch is switched without '
        'being imported again', () async {
      store.seedBuild(1001, BuildState.staged);
      ccp.announce(1001);

      final result = await check();

      expect(result, isA<BuildSwitched>());
      expect(ccp.opens, 0);
      expect(store.builds, {
        1000: BuildState.previous,
        1001: BuildState.active,
      });
      expect(store.diffs.single.outcome, DiffOutcome.succeeded);
      expectClean();
    });

    test('a stored comparison of the pair is not made again', () async {
      store.seedBuild(1001, BuildState.staged);
      await store.insertDiff(
        BuildDiffRecord(
          fromBuild: 1000,
          toBuild: 1001,
          createdAt: _t0,
          outcome: DiffOutcome.succeeded,
          report: const SdeJson({'files': <Object?>[]}),
        ),
      );
      ccp.announce(1001);

      final result = await check(differ: _FailingDiffer());

      expect(result, isA<BuildSwitched>());
      expect(store.diffs, hasLength(1));
      expectClean();
    });

    test('a failed comparison is recorded and the switch still '
        'happens', () async {
      ccp.announce(1001);

      final result = await check(differ: _FailingDiffer());

      expect(result, isA<BuildSwitched>());
      final BuildDiffRecord(:outcome, :failureReason, :report, :toBuild) =
          store.diffs.single;
      expect(outcome, DiffOutcome.failed);
      expect(toBuild, 1001);
      expect(failureReason, contains('comparison broke'));
      expect(report, isNull);
      expect(store.builds[1001], BuildState.active);
      expect(store.checks.single.outcome, CheckOutcome.switched);
      expectClean();
    });

    test('a failed switch is recorded, the build stays staged and the check '
        'is staged', () async {
      ccp.announce(1001);
      final failing = _SwitchFailingStore(store);

      final result = await check(using: failing);

      expect(result, isA<BuildStaged>());
      expect((result as BuildStaged).build, 1001);
      expect(store.builds, {1000: BuildState.active, 1001: BuildState.staged});
      final SwitchRecord(
        :kind,
        :outcome,
        :fromBuild,
        :toBuild,
        :failureReason,
      ) = store.switches.single;
      expect(
        (kind, outcome, fromBuild, toBuild),
        (SwitchKind.forward, SwitchOutcome.failed, 1000, 1001),
      );
      expect(failureReason, contains('switch statement failed'));
      expect(store.checks.single.outcome, CheckOutcome.staged);
      expect(store.checks.single.latestBuild, 1001);
      expectClean();
    });

    test('an import failure records a failed check with the reason', () async {
      ccp
        ..announce(1001)
        ..zipFor(1001, SdeFixture.empty()..setBuild(1001));

      final result = await check();

      expect(result, isA<BuildCheckFailed>());
      final CheckRecord(:outcome, :failureReason, :latestBuild) =
          store.checks.single;
      expect(outcome, CheckOutcome.failed);
      expect(failureReason, contains('missing required files'));
      expect(latestBuild, 1001);
      expect(store.builds, {1000: BuildState.active});
      expect(store.records.single.record.outcome, ImportOutcome.failed);
      expectClean();
    });

    test('stale running records are swept under the lock', () async {
      await store.insertRecord(
        ImportRecord(
          source: SdeSourceKind.ccp,
          startedAt: _t0.subtract(const Duration(hours: 1)),
          outcome: ImportOutcome.running,
        ),
      );
      ccp.announce(1000);

      await check();

      final ImportRecord(:outcome, :failureReason) =
          store.records.single.record;
      expect((outcome, failureReason), (ImportOutcome.failed, 'interrupted'));
    });

    test('a stale scratch directory is removed under the lock', () async {
      final left = Directory('${scratch.path}/${sdeScratchPrefix}killed')
        ..createSync();
      ccp.announce(1000);

      await check();

      expect(left.existsSync(), isFalse);
    });

    test('it keeps the newest 100 check and switch records', () async {
      for (var i = 0; i < 101; i++) {
        await store.insertCheck(
          CheckRecord(
            checkedAt: _t0.subtract(Duration(days: 200 - i)),
            outcome: CheckOutcome.upToDate,
          ),
        );
      }
      ccp.announce(1000);

      await check();

      expect(store.checks, hasLength(100));
    });

    test('an importing check keeps the newest 100 import records', () async {
      for (var i = 0; i < 101; i++) {
        await store.insertRecord(
          ImportRecord(
            source: SdeSourceKind.ccp,
            startedAt: _t0.subtract(Duration(days: 200 - i)),
            outcome: ImportOutcome.failed,
          ),
        );
      }
      ccp.announce(1001);

      final result = await check();

      expect(result, isA<BuildSwitched>());
      expect(store.records, hasLength(100));
      expect(store.records.last.record.outcome, ImportOutcome.succeeded);
    });
  });

  group('Given no active build', () {
    test('the first build becomes active with no stored report', () async {
      ccp.announce(1000);

      final result = await check();

      expect(result, isA<BuildSwitched>());
      expect(store.builds, {1000: BuildState.active});
      expect(store.diffs, isEmpty);
      expect(store.checks.single.outcome, CheckOutcome.switched);
      expect(store.checks.single.latestBuild, 1000);
      expectClean();
    });
  });

  group('Given an older build staged by an import', () {
    test('an older build stays staged and is never switched to', () async {
      store.seedBuild(2000, BuildState.active);
      final imported = await ImportSdeJob(
        store: store,
        source: LocalZipSdeSource(
          SdeFixture.complete(build: 1000).writeTo(zips),
          scratchRoot: scratch,
        ),
        scratchRoot: scratch,
      ).run();
      expect(imported, isA<ImportSucceeded>());
      expect(store.builds[1000], BuildState.staged);
      store.isClosed = false;

      ccp.announce(2000);
      expect(await check(), isA<BuildUpToDate>());
      store.isClosed = false;
      ccp.announce(1000);
      expect(await check(), isA<BuildOlder>());

      expect(store.builds, {2000: BuildState.active, 1000: BuildState.staged});
      expect(store.switches, isEmpty);
      expect(store.diffs, isEmpty);
    });

    test('a later import is staged by the import and then switched '
        'to', () async {
      store.seedBuild(1000, BuildState.active);
      ccp.announce(1001);

      final result = await check();

      expect(result, isA<BuildSwitched>());
      final ImportRecord(:outcome, :build) = store.records.single.record;
      expect((outcome, build), (ImportOutcome.succeeded, 1001));
      expect(store.builds[1001], BuildState.active);
    });
  });
}

/// A CCP stand-in: announces one build and serves a zip of it.
final class _FakeCcp implements SdeSource {
  _FakeCcp(this._zips, this._scratch);

  final Directory _zips;
  final Directory _scratch;
  final Map<int, File> _files = {};
  int? _announced;
  String? _unreachable;

  /// How many times a build was opened (downloaded).
  int opens = 0;

  void announce(int build) => _announced = build;

  void unreachable(String reason) => _unreachable = reason;

  void zipFor(int build, SdeFixture fixture) =>
      _files[build] = fixture.writeTo(_zips, 'sde_$build.zip');

  @override
  SdeSourceKind get kind => SdeSourceKind.ccp;

  @override
  Future<int?> announcedBuild() async {
    final reason = _unreachable;
    if (reason != null) throw SdeSourceException(reason);
    return _announced;
  }

  @override
  Future<SdeArchive> open() {
    opens++;
    final build = _announced!;
    final file =
        _files[build] ??
        SdeFixture.complete(build: build).writeTo(_zips, 'sde_$build.zip');
    return LocalZipSdeSource(file, scratchRoot: _scratch).open();
  }
}

final class _FailingDiffer implements StaticDataDiffer {
  @override
  Future<BuildDiffReport> compare(int fromBuild, int toBuild) =>
      Future.error(StateError('comparison broke'));
}

/// Forwards to [_inner], but the switch statement fails.
final class _SwitchFailingStore implements StaticDataStore {
  _SwitchFailingStore(this._inner);

  final InMemoryStaticDataStore _inner;

  @override
  Future<bool> tryLock() => _inner.tryLock();
  @override
  Future<void> unlock() => _inner.unlock();
  @override
  Future<int> failRunningRecords({
    required String reason,
    required DateTime at,
  }) => _inner.failRunningRecords(reason: reason, at: at);
  @override
  Future<int> insertRecord(ImportRecord record) => _inner.insertRecord(record);
  @override
  Future<void> updateRecord(int id, ImportRecord record) =>
      _inner.updateRecord(id, record);
  @override
  Future<void> pruneRecords({required int keep}) =>
      _inner.pruneRecords(keep: keep);
  @override
  Future<bool> hasBuild(int build) => _inner.hasBuild(build);
  @override
  Future<bool> hasActiveBuild() => _inner.hasActiveBuild();
  @override
  Future<List<StoredBuild>> storedBuilds() => _inner.storedBuilds();
  @override
  Future<int?> dropStagedBuild() => _inner.dropStagedBuild();
  @override
  Future<void> insertCheck(CheckRecord record) => _inner.insertCheck(record);
  @override
  Future<DateTime?> newestCheckedAt() => _inner.newestCheckedAt();
  @override
  Future<void> pruneChecks({required int keep}) =>
      _inner.pruneChecks(keep: keep);
  @override
  Future<void> insertFailedSwitch(SwitchRecord record) =>
      _inner.insertFailedSwitch(record);
  @override
  Future<void> pruneSwitches({required int keep}) =>
      _inner.pruneSwitches(keep: keep);
  @override
  Future<void> insertDiff(BuildDiffRecord record) => _inner.insertDiff(record);
  @override
  Future<BuildDiffRecord?> diff(int fromBuild, int toBuild) =>
      _inner.diff(fromBuild, toBuild);
  @override
  Future<T> inTransaction<T>(
    Future<T> Function(StaticDataWriter writer) body,
  ) => _inner.inTransaction((writer) => body(_FailingSwitchWriter(writer)));
  @override
  Future<void> close() => _inner.close();
}

final class _FailingSwitchWriter implements StaticDataWriter {
  _FailingSwitchWriter(this._inner);

  final StaticDataWriter _inner;

  @override
  Future<void> switchTo(int build, {required DateTime at}) =>
      Future.error(StateError('switch statement failed'));
  @override
  Future<void> rollBack({required DateTime at}) => _inner.rollBack(at: at);
  @override
  Future<void> insertTyped(int build, List<TypedRow> rows) =>
      _inner.insertTyped(build, rows);
  @override
  Future<void> insertRaw(int build, List<RawRecord> records) =>
      _inner.insertRaw(build, records);
  @override
  Future<void> commitBuild({
    required int build,
    required BuildState state,
    required DateTime importedAt,
    required int recordId,
    required ImportRecord record,
  }) => _inner.commitBuild(
    build: build,
    state: state,
    importedAt: importedAt,
    recordId: recordId,
    record: record,
  );
}
