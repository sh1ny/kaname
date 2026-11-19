import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:test/test.dart';

final _t0 = DateTime.utc(2026, 1, 1, 12);

void main() {
  group('Given an in-memory store', () {
    late InMemoryStaticDataStore store;

    setUp(() => store = InMemoryStaticDataStore());

    Future<RollbackResult> rollBack() =>
        RollbackJob(store: store, clock: () => _t0).run();

    test('when a previous build exists then it swaps the builds, moves the '
        'hold and records the rollback', () async {
      store
        ..seedBuild(1, BuildState.previous)
        ..seedBuild(2, BuildState.active);

      final result = await rollBack();

      expect(result, isA<RollbackSucceeded>());
      final RollbackSucceeded(:fromBuild, :toBuild) =
          result as RollbackSucceeded;
      expect((fromBuild, toBuild), (2, 1));
      expect(store.builds, {1: BuildState.active, 2: BuildState.previous});
      expect(store.heldBuilds, {2});
      final SwitchRecord(:kind, fromBuild: from, toBuild: to, :outcome) =
          store.switches.single;
      expect(
        (kind, from, to, outcome),
        (SwitchKind.rollback, 2, 1, SwitchOutcome.succeeded),
      );
      expect(store.isClosed, isTrue);
      expect(store.lock.isHeld, isFalse);
    });

    test('when the build made active was held then its hold clears', () async {
      store
        ..seedBuild(1, BuildState.previous, held: true)
        ..seedBuild(2, BuildState.active);

      await rollBack();

      expect(store.heldBuilds, {2});
    });

    test('when no build is previous then it fails, keeps the active build '
        'and records the failure', () async {
      store.seedBuild(2, BuildState.active);

      final result = await rollBack();

      expect((result as RollbackFailed).reason, 'no previous build');
      expect(store.builds, {2: BuildState.active});
      final SwitchRecord(:kind, :outcome, :failureReason) =
          store.switches.single;
      expect(
        (kind, outcome, failureReason),
        (SwitchKind.rollback, SwitchOutcome.failed, 'no previous build'),
      );
      expect(store.isClosed, isTrue);
      expect(store.lock.isHeld, isFalse);
    });

    test('when the lock is held then it fails at once with import running and '
        'writes nothing', () async {
      store
        ..seedBuild(1, BuildState.previous)
        ..seedBuild(2, BuildState.active);
      final holder = InMemoryStaticDataStore(lock: store.lock);
      expect(await holder.tryLock(), isTrue);

      final result = await rollBack();

      expect((result as RollbackFailed).reason, 'import running');
      expect(store.builds, {1: BuildState.previous, 2: BuildState.active});
      expect(store.switches, isEmpty);
      expect(store.isClosed, isTrue);
      expect(holder.lock.isHeld, isTrue);
    });

    test('when it runs often then it keeps the newest 100 switch '
        'records', () async {
      for (var i = 0; i < 101; i++) {
        store
          ..seedBuild(1, BuildState.previous)
          ..seedBuild(2, BuildState.active);
        await RollbackJob(
          store: store,
          clock: () => _t0.add(Duration(minutes: i)),
        ).run();
        store.isClosed = false;
      }

      expect(store.switches, hasLength(100));
      expect(store.switches.first.at, _t0.add(const Duration(minutes: 1)));
    });
  });
}
