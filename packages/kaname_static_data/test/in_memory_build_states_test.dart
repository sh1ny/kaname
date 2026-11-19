import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:test/test.dart';

final _t0 = DateTime.utc(2026, 1, 1, 12);

void main() {
  group('Given an in-memory store with active, previous and staged builds', () {
    late InMemoryStaticDataStore store;

    setUp(() {
      store = InMemoryStaticDataStore()
        ..seedBuild(1, BuildState.previous)
        ..seedBuild(2, BuildState.active)
        ..seedBuild(3, BuildState.staged);
    });

    test('when the staged build is dropped then only it is removed', () async {
      expect(await store.dropStagedBuild(), 3);
      expect(await store.dropStagedBuild(), isNull);
      expect(store.builds, {1: BuildState.previous, 2: BuildState.active});
    });

    test('when it switches then the states move, the old previous build and '
        'its diffs go, holds older than the new build clear and the switch '
        'is recorded', () async {
      store.seedBuild(2, BuildState.active, held: true);
      await store.insertDiff(
        BuildDiffRecord(
          fromBuild: 1,
          toBuild: 2,
          createdAt: _t0,
          outcome: DiffOutcome.failed,
          failureReason: 'x',
        ),
      );
      await store.insertDiff(
        BuildDiffRecord(
          fromBuild: 2,
          toBuild: 3,
          createdAt: _t0,
          outcome: DiffOutcome.failed,
          failureReason: 'y',
        ),
      );

      await store.inTransaction((writer) => writer.switchTo(3, at: _t0));

      expect(store.builds, {2: BuildState.previous, 3: BuildState.active});
      expect(store.heldBuilds, isEmpty);
      expect(await store.diff(1, 2), isNull);
      expect(await store.diff(2, 3), isNotNull);
      final SwitchRecord(:kind, :fromBuild, :toBuild, :outcome) =
          store.switches.single;
      expect(
        (kind, fromBuild, toBuild, outcome),
        (SwitchKind.forward, 2, 3, SwitchOutcome.succeeded),
      );
    });

    test('when it switches to a build that is not staged then it throws and '
        'nothing changes', () async {
      await expectLater(
        store.inTransaction((writer) => writer.switchTo(1, at: _t0)),
        throwsStateError,
      );
      expect(store.builds, {
        1: BuildState.previous,
        2: BuildState.active,
        3: BuildState.staged,
      });
      expect(store.switches, isEmpty);
    });

    test('when it rolls back then the builds swap, the hold follows and the '
        'rollback is recorded', () async {
      await store.inTransaction((writer) => writer.rollBack(at: _t0));

      expect(await store.storedBuilds(), [
        isA<StoredBuild>().having(
          (b) => (b.build, b.state, b.held),
          'build 1',
          (1, BuildState.active, false),
        ),
        isA<StoredBuild>().having(
          (b) => (b.build, b.state, b.held),
          'build 2',
          (2, BuildState.previous, true),
        ),
        isA<StoredBuild>().having(
          (b) => (b.build, b.state, b.held),
          'build 3',
          (3, BuildState.staged, false),
        ),
      ]);
      final SwitchRecord(:kind, :fromBuild, :toBuild) = store.switches.single;
      expect((kind, fromBuild, toBuild), (SwitchKind.rollback, 2, 1));

      await store.inTransaction((writer) => writer.rollBack(at: _t0));
      expect(store.heldBuilds, {1});
    });

    test('when there is no previous build then rolling back throws', () async {
      final bare = InMemoryStaticDataStore()..seedBuild(2, BuildState.active);
      await expectLater(
        bare.inTransaction((writer) => writer.rollBack(at: _t0)),
        throwsStateError,
      );
    });

    test('when checks and switches pass the limit then pruning keeps the '
        'newest and the newest check time is read', () async {
      for (var i = 0; i < 4; i++) {
        final at = _t0.add(Duration(days: i));
        await store.insertCheck(
          CheckRecord(checkedAt: at, outcome: CheckOutcome.upToDate),
        );
        await store.insertFailedSwitch(
          SwitchRecord(
            kind: SwitchKind.forward,
            toBuild: i,
            at: at,
            outcome: SwitchOutcome.failed,
            failureReason: 'boom',
          ),
        );
      }

      await store.pruneChecks(keep: 2);
      await store.pruneSwitches(keep: 2);

      expect(store.checks.map((c) => c.checkedAt.day), [3, 4]);
      expect(store.switches.map((s) => s.toBuild), [2, 3]);
      expect(await store.newestCheckedAt(), _t0.add(const Duration(days: 3)));
    });
  });
}
