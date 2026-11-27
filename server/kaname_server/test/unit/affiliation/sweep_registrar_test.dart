import 'dart:async';

import 'package:kaname_server/src/affiliation/sweep_registrar.dart';
import 'package:test/test.dart';

import '../../support/manual_sweep_clock.dart';

void main() {
  const minute = Duration(minutes: 1);
  const hour = Duration(hours: 1);
  const startup = (boot: 'current', slot: 0);
  const hourly = (boot: 'current', slot: 1);
  late ManualSweepClock clock;
  late SweepRegistrar registrar;
  late List<SweepSlot> enqueued;
  late List<SweepSlot> failed;
  late Future<bool> Function(SweepSlot) exists;
  late Future<void> Function(SweepSlot) enqueue;

  setUp(() {
    clock = ManualSweepClock();
    enqueued = [];
    failed = [];
    exists = (_) async => false;
    enqueue = (_) async {};
    registrar = SweepRegistrar(
      boot: 'current',
      elapsed: () => clock.elapsed,
      arm: clock.arm,
      exists: (slot) => exists(slot),
      enqueue: (slot) async {
        enqueued.add(slot);
        await enqueue(slot);
      },
      onFailure: failed.add,
    );
    addTearDown(registrar.stop);
  });

  test(
    'repairs failed startup and hourly enqueues without replaying sweeps',
    () async {
      final queued = <SweepSlot>{};
      final rejected = <SweepSlot>{};
      enqueue = (slot) async {
        if (rejected.add(slot)) throw StateError('lost insert');
        queued.add(slot);
      };
      exists = (slot) async => queued.contains(slot);
      await registrar.start();
      expect(failed, [startup]);
      await clock.advance(minute);
      await clock.advance(minute); // A live existing one-shot is left alone.
      expect(enqueued, [startup, startup]);
      expect(registrar.accept(queued.single), isTrue);
      queued.clear();
      await clock.advance(hour - clock.elapsed);
      expect(failed, [startup, hourly]);
      await clock.advance(minute);
      expect(registrar.accept(queued.single), isTrue);
      expect(enqueued, [startup, startup, hourly, hourly]);
      expect(clock.due, hour * 2);
    },
  );

  test(
    'a dispatch during the presence check does not requeue that slot',
    () async {
      final checking = Completer<void>();
      final missing = Completer<bool>();
      exists = (_) {
        checking.complete();
        return missing.future;
      };
      await registrar.start();
      final repair = clock.advance(minute);
      await checking.future;
      expect(registrar.accept(startup), isTrue);
      missing.complete(false);
      await repair;
      expect(enqueued, [startup]);
      expect(clock.due, hour);
    },
  );

  test('a presence miss arriving after stop cannot enqueue or rearm', () async {
    final checking = Completer<void>();
    final missing = Completer<bool>();
    exists = (_) {
      checking.complete();
      return missing.future;
    };
    await registrar.start();
    final repair = clock.advance(minute);
    await checking.future;
    registrar.stop();
    missing.complete(false);
    await repair;
    expect(enqueued, [startup]);
    expect(clock.due, isNull);
    expect(registrar.accept(startup), isFalse);
  });

  test('serial duplicate startup dispatches start only one sweep', () async {
    final physicalEntries = <SweepSlot>[];
    enqueue = (slot) async {
      physicalEntries.add(slot);
      if (physicalEntries.length == 1) throw StateError('lost acknowledgement');
    };
    await registrar.start();
    await clock.advance(minute);
    expect(physicalEntries.where(registrar.accept).toList(), [startup]);
    expect(clock.due, hour);
  });

  test('an old boot cannot satisfy this boot\'s startup slot', () async {
    await registrar.start();
    expect(registrar.accept((boot: 'old', slot: 19)), isFalse);
    expect(registrar.accept(startup), isTrue);
    expect(clock.due, hour);
  });

  test(
    'pending registration collapses missed hours into one catch-up slot',
    () async {
      await registrar.start();
      exists = (_) async => true;
      await clock.advance(hour * 4);
      expect(registrar.accept(startup), isTrue);
      await clock.advance(Duration.zero);
      const catchUp = (boot: 'current', slot: 4);
      expect(registrar.accept(catchUp), isTrue);
      expect(enqueued, [startup, catchUp]);
      expect(clock.due, hour * 5);
    },
  );
}
