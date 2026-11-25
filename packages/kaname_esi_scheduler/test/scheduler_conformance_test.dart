import 'dart:convert';

import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:test/test.dart';

SchedulerRequest request({
  String operation = 'GetExample',
  bool probe = false,
  String key = 'page',
  String scope = 'public',
  EsiPriority priority = EsiPriority.sync,
  int capacity = 25,
  bool poll = false,
  bool retained = false,
  String? corp,
  String? group = 'group',
}) => SchedulerRequest(
  operation: operation,
  scope: scope,
  group: group,
  capacity: capacity,
  windowMs: 900000,
  priority: priority,
  negativeKey: key,
  pollKey: poll ? (corp ?? key) : null,
  retained: retained,
  corpKey: corp,
  probe: probe,
);

void main() {
  schedulerConformance(MemorySchedulerState.new);

  test('never replays an ambiguous send', () async {
    var sends = 0;
    final scheduler = EsiScheduler(
      state: MemorySchedulerState(),
      key: const [1],
      send: (request, credential, validator) async {
        sends++;
        return const WireFailure();
      },
    );
    final result = await scheduler.client(EsiPriority.sync).getAlliances();
    expect(result, isA<EsiTransportFailed<List<int>>>());
    expect(sends, 1);
  });

  test('bearer boundary failures release the unsent reservation', () async {
    var failBearer = true;
    var sends = 0;
    final scheduler = EsiScheduler(
      state: MemorySchedulerState(),
      key: const [1],
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
      wait: (_) => fail('an unsent reservation remained active'),
      send: (request, credential, validator) async {
        sends++;
        return WireResponse(EsiResponse(status: 200, body: utf8.encode('[]')));
      },
    );
    final client = scheduler.client(
      EsiPriority.sync,
      principal: EsiPrincipal(
        application: 'test',
        character: 99000001,
        generation: 'one',
        bearer: () {
          if (failBearer) throw StateError('unavailable');
          return 'synthetic';
        },
      ),
    );
    for (var i = 0; i < 9; i++) {
      final result = await client.getCharactersCharacterIdAssets(
        characterId: 99000001,
      );
      expect(
        result,
        isA<EsiNotSent<List<CharactersCharacterIdAssetsGetItem>>>().having(
          (r) => r.refusal.reason,
          'reason',
          EsiRefusalReason.invalidContext,
        ),
      );
    }
    failBearer = false;
    expect(
      await client.getCharactersCharacterIdAssets(characterId: 99000001),
      isA<EsiSuccess<List<CharactersCharacterIdAssetsGetItem>>>(),
    );
    expect(sends, 1);
  });

  test('sender boundary failures settle without replay', () async {
    var sends = 0;
    final scheduler = EsiScheduler(
      state: MemorySchedulerState(),
      key: const [1],
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
      wait: (_) => fail('an ambiguous reservation remained active'),
      send: (request, credential, validator) async {
        sends++;
        throw StateError('failed exchange');
      },
    );
    final client = scheduler.client(EsiPriority.sync);
    for (var i = 0; i < 9; i++) {
      expect(await client.getAlliances(), isA<EsiTransportFailed<List<int>>>());
    }
    expect(sends, 9);
  });

  test('decoded VIP status does not resume polling', () async {
    final seen = <String>[];
    final scheduler = EsiScheduler(
      state: MemorySchedulerState(),
      key: const [1],
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
      send: (request, credential, validator) async {
        seen.add(request.operationId);
        if (seen.length == 1) {
          return const WireFailure(connectivityFailure: true);
        }
        return WireResponse(
          EsiResponse(
            status: 200,
            body: utf8.encode(
              '{"players":1,"server_version":"1",'
              '"start_time":"2026-11-01T00:00:00Z","vip":true}',
            ),
          ),
        );
      },
    );
    final poll = scheduler.client(EsiPriority.sync, poll: true);
    expect(await poll.getAlliances(), isA<EsiTransportFailed<List<int>>>());
    final paused = isA<EsiNotSent<List<int>>>().having(
      (r) => r.refusal.reason,
      'reason',
      EsiRefusalReason.outage,
    );
    expect(await poll.getAlliances(), paused);
    expect(await poll.getAlliances(), paused);
    expect(seen, ['GetAlliances', 'GetStatus']);
  });

  test('forwards retained page validator and wire 304', () async {
    String? seen;
    final scheduler = EsiScheduler(
      state: MemorySchedulerState(),
      key: const [1],
      send: (request, credential, validator) async {
        seen = validator;
        return WireResponse(EsiResponse(status: 304));
      },
    );
    final result = await scheduler
        .client(EsiPriority.sync, poll: true)
        .getAlliances(ifNoneMatch: '"representation"');
    expect(result, isA<EsiNotModified<List<int>>>());
    expect(seen, '"representation"');
  });

  for (final truncated in [true, false]) {
    final failure = truncated ? 'incomplete' : 'malformed';
    test('$failure body does not mark a retained poll fresh', () async {
      final validators = <String?>[];
      const headers = {'expires': 'Thu, 01 Jan 1970 01:00:00 GMT'};
      final scheduler = EsiScheduler(
        state: MemorySchedulerState(),
        key: const [1],
        now: () => DateTime.fromMillisecondsSinceEpoch(1000),
        send: (request, bearer, validator) async {
          validators.add(validator);
          if (validators.length > 1) {
            return WireResponse(EsiResponse(status: 304, headers: headers));
          }
          final head = EsiResponse(
            status: 200,
            headers: headers,
            body: truncated ? null : utf8.encode('{}'),
          );
          return truncated ? WireFailure(head: head) : WireResponse(head);
        },
      );
      final poll = scheduler.client(EsiPriority.sync, poll: true);
      Future<EsiResult<List<int>>> fetch() =>
          poll.getAlliances(ifNoneMatch: '"older"');
      expect(
        await fetch(),
        truncated
            ? isA<EsiTransportFailed<List<int>>>()
            : isA<EsiMalformed<List<int>>>(),
      );
      expect(await fetch(), isA<EsiNotModified<List<int>>>());
      expect(
        await fetch(),
        isA<EsiNotSent<List<int>>>().having(
          (result) => result.refusal.reason,
          'reason',
          EsiRefusalReason.notDue,
        ),
      );
      expect(validators, ['"older"', '"older"']);
    });
  }

  test('keeps live metadata when no safe slot can be allocated', () async {
    final state = MemorySchedulerState(maxMetadata: 1);
    final first = state.admit(request(), 1000) as Granted;
    state.complete(first.id, 1001, const Observation(status: 404));
    final noSlot = state.admit(request(key: 'other-page'), 1002) as Denied;
    expect(noSlot.refusal.reason, EsiRefusalReason.scopeCapacity);
    final retained = state.admit(request(), 1002) as Denied;
    expect(retained.refusal.reason, EsiRefusalReason.negativeCached);
    expect(state.admit(request(key: 'other-page'), 61001), isA<Granted>());
  });
}

/// Runs the behavioral contract against either state implementation.
void schedulerConformance(SchedulerState Function() create) {
  late SchedulerState state;
  setUp(() => state = create());

  test('admits exactly one last reservation', () async {
    final calls = await Future.wait([
      for (var i = 0; i < 8; i++)
        Future<Admission>.sync(() => state.admit(request(capacity: 5), 1000)),
    ]);
    expect(calls.whereType<Granted>(), hasLength(1));
    expect(calls.whereType<Denied>(), hasLength(7));
  });

  test('charges outstanding work against observed remaining', () async {
    await learnBudget();
    final first = await state.admit(request(), 1000) as Granted;
    await state.admit(request(), 1000) as Granted;
    await state.complete(
      first.id,
      1001,
      const Observation(
        cost: 2,
        group: 'group',
        capacity: 25,
        windowMs: 900000,
        remaining: 8,
      ),
    );
    expect(await state.admit(request(), 1002), isA<Denied>());
  });

  test('retains the learned group for live windows and cooldowns', () async {
    final input = request(group: null);
    final first = await state.admit(input, 1000) as Granted;
    await state.complete(
      first.id,
      1001,
      const Observation(
        status: 200,
        group: 'group',
        capacity: 100,
        windowMs: 10000,
        remaining: 90,
      ),
    );
    final later = await state.admit(input, 9000) as Granted;
    await state.complete(
      later.id,
      9001,
      const Observation(
        status: 200,
        group: 'group',
        capacity: 100,
        windowMs: 1000,
        remaining: 10,
      ),
    );
    final stopped = await state.admit(input, 12000) as Denied;
    expect(stopped.refusal.reason, EsiRefusalReason.stopped);

    final afterWindow = await state.admit(input, 19001) as Granted;
    await state.complete(
      afterWindow.id,
      30002,
      const Observation(status: 429, retryMs: 100000),
    );
    final cooldown = await state.admit(input, 100000) as Denied;
    expect(cooldown.refusal.reason, EsiRefusalReason.budget);
    expect(await state.admit(input, 130002), isA<Granted>());
  });

  test('accounts for outstanding calls on group discovery', () async {
    final input = request(group: null);
    final first = await state.admit(input, 1000) as Granted;
    final pending = await state.admit(input, 1001) as Granted;
    await state.admit(request(group: null, scope: 'other'), 1001) as Granted;
    await state.complete(
      first.id,
      1002,
      const Observation(
        status: 200,
        group: 'group',
        capacity: 25,
        windowMs: 900000,
        remaining: 8,
      ),
    );
    final blocked = await state.admit(input, 1003) as Denied;
    expect(blocked.refusal.reason, EsiRefusalReason.budget);
    await state.complete(pending.id, 1004, const Observation(status: 503));
    expect(await state.admit(input, 2001), isA<Granted>());
  });

  test('distinguishes group cooldown from connection reset', () async {
    final first = await state.admit(request(), 1000) as Granted;
    await state.complete(
      first.id,
      1001,
      const Observation(status: 429, retryMs: 5000),
    );
    expect(await state.admit(request(), 1002), isA<Denied>());
    final other = await state.admit(request(scope: 'other'), 1002) as Granted;
    await state.complete(
      other.id,
      1003,
      const Observation(status: 420, retryMs: 6000),
    );
    expect(await state.admit(request(scope: 'third'), 1004), isA<Denied>());
    expect(await state.admit(request(scope: 'third'), 7003), isA<Granted>());
  });

  test('settles late response without replacing ceiling', () async {
    await learnBudget();
    final first = await state.admit(request(), 1000) as Granted;
    final second = await state.admit(request(), 1001) as Granted;
    await state.complete(
      second.id,
      1002,
      const Observation(
        cost: 2,
        group: 'group',
        capacity: 25,
        windowMs: 900000,
        remaining: 5,
      ),
    );
    await state.complete(
      first.id,
      1003,
      const Observation(
        cost: 0,
        group: 'group',
        capacity: 25,
        windowMs: 900000,
        remaining: 25,
      ),
    );
    expect(await state.admit(request(), 1004), isA<Granted>());
    expect(await state.admit(request(), 1005), isA<Denied>());
  });

  test('applies all four tiers at exact thresholds', () async {
    const cases = [
      (51, EsiGovernor.full),
      (50, EsiGovernor.spaced),
      (25, EsiGovernor.single),
      (10, EsiGovernor.stopped),
    ];
    var now = 1000;
    for (final (remaining, tier) in cases) {
      final input = request(scope: tier.name, capacity: 100);
      final sample = await state.admit(input, now) as Granted;
      await state.complete(
        sample.id,
        now,
        Observation(
          status: 200,
          cost: 2,
          group: 'group',
          capacity: 100,
          windowMs: 900000,
          remaining: remaining,
        ),
      );
      final next = await state.admit(input, now);
      switch (tier) {
        case EsiGovernor.full:
          expect(next, isA<Granted>());
        case EsiGovernor.spaced:
          final wait = next as Waiting;
          for (final delay in [250, 500, 750]) {
            expect(await state.advance(wait.id, now + delay), isA<Waiting>());
          }
          expect(await state.advance(wait.id, now + 1000), isA<Granted>());
        case EsiGovernor.single:
          expect(next, isA<Granted>());
          expect(await state.admit(input, now + 1000), isA<Waiting>());
        case EsiGovernor.stopped:
          expect((next as Denied).refusal.reason, EsiRefusalReason.stopped);
      }
      now += 2000;
    }
  });

  test('chooses highest eligible live waiter before FIFO peers', () async {
    final slots = [
      for (var i = 0; i < 8; i++)
        await state.admit(request(scope: '$i'), 1000) as Granted,
    ];
    final low = await state.admit(
      request(scope: 'low', priority: EsiPriority.backfill),
      1001,
    ) as Waiting;
    final high = await state.admit(
      request(scope: 'high', priority: EsiPriority.interactive),
      1002,
    ) as Waiting;
    final peer = await state.admit(
      request(scope: 'peer', priority: EsiPriority.interactive),
      1003,
    ) as Waiting;
    await state.complete(slots.first.id, 1004, const Observation(status: 200));
    expect(await state.advance(low.id, 1251), isA<Waiting>());
    expect(await state.advance(peer.id, 1253), isA<Waiting>());
    expect(await state.advance(high.id, 1254), isA<Granted>());
    await state.complete(slots[1].id, 1255, const Observation(status: 200));
    expect(await state.advance(peer.id, 1503), isA<Granted>());
  });

  test('displaces newest lowest-priority waiter', () async {
    for (var i = 0; i < 8; i++) {
      expect(await state.admit(request(scope: '$i'), 1000), isA<Granted>());
    }
    final waiting = [
      for (var i = 0; i < 64; i++)
        await state.admit(
          request(scope: 'wait', priority: EsiPriority.backfill),
          1001,
        ) as Waiting,
    ];
    expect(
      await state.admit(
        request(scope: 'fast', priority: EsiPriority.interactive),
        1002,
      ),
      isA<Waiting>(),
    );
    final refused = await state.advance(waiting.last.id, 1251) as Denied;
    expect(refused.refusal.reason, EsiRefusalReason.queueFull);
    expect(await state.advance(waiting.first.id, 1251), isA<Waiting>());
  });

  test('expires a lease and never sends an expired ticket', () async {
    final active = [
      for (var i = 0; i < 8; i++)
        await state.admit(request(scope: '$i'), 1000) as Granted,
    ];
    final ticket = await state.admit(request(scope: 'wait'), 1001) as Waiting;
    for (var now = 1251; now < 6001; now += 250) {
      expect(await state.advance(ticket.id, now), isA<Waiting>());
    }
    final expired = await state.advance(ticket.id, 6001) as Denied;
    expect(expired.refusal.reason, EsiRefusalReason.waitExpired);
    await state.complete(active.first.id, 6002, const Observation(status: 200));
    expect(await state.advance(ticket.id, 6002), isA<Denied>());
  });

  test('late wire completion still blocks the connection', () async {
    final grant = await state.admit(request(), 1000) as Granted;
    final completedAt = grant.dispatchByMs + 20000 + 4999;
    await state.complete(
      grant.id,
      completedAt,
      const Observation(status: 420, retryMs: 60000),
    );
    final blocked =
        await state.admit(request(scope: 'other'), completedAt) as Denied;
    expect(blocked.refusal.reason, EsiRefusalReason.stopped);
    expect(
      blocked.refusal.retryAt?.millisecondsSinceEpoch,
      completedAt + 60000,
    );
  });

  for (final (status, reason) in [
    (420, EsiRefusalReason.stopped),
    (429, EsiRefusalReason.budget),
    (403, EsiRefusalReason.negativeCached),
    (404, EsiRefusalReason.negativeCached),
  ]) {
    test('reconciles $status at the exact caller lease boundary', () async {
      final grant = await state.admit(request(), 1000) as Granted;
      await state.complete(
        grant.id,
        31000,
        Observation(status: status, retryMs: 60000),
      );
      final denied = await state.admit(
        request(scope: status == 420 ? 'other' : 'public'),
        31000,
      ) as Denied;
      expect(denied.refusal.reason, reason);
      expect(denied.refusal.retryAt?.millisecondsSinceEpoch, 91000);
      if (status == 403 || status == 404) {
        expect(denied.refusal.suppressedStatus, status);
      }
    });
  }

  test(
    'late completion does not occupy or release a renewed corp claim',
    () async {
      final input = request(corp: 'corp', poll: true);
      final old = await state.admit(input, 1000) as Granted;
      final renewed = await state.admit(input, 31000) as Granted;
      await state.complete(old.id, 31001, const Observation(status: 200));
      final held = await state.admit(input, 31001) as Denied;
      expect(held.refusal.reason, EsiRefusalReason.corpBusy);
      await state.complete(renewed.id, 31002, const Observation(status: 200));
      expect(await state.admit(input, 31003), isA<Granted>());
    },
  );

  test('ignores observations once the completion-only grace expires', () async {
    final grant = await state.admit(request(), 1000) as Granted;
    await state.complete(
      grant.id,
      36000,
      const Observation(status: 420, retryMs: 60000),
    );
    expect(await state.admit(request(scope: 'other'), 36000), isA<Granted>());
  });

  test('skips a head whose worker stopped refreshing it', () async {
    final slots = [
      for (var i = 0; i < 8; i++)
        await state.admit(request(scope: '$i'), 1000) as Granted,
    ];
    final dead = await state.admit(
      request(scope: 'dead', priority: EsiPriority.interactive),
      1001,
    ) as Waiting;
    final live = await state.admit(request(scope: 'live'), 1002) as Waiting;
    expect(await state.advance(live.id, 1252), isA<Waiting>());
    expect(await state.advance(live.id, 1502), isA<Waiting>());
    expect(await state.advance(live.id, 1752), isA<Waiting>());
    await state.complete(slots.first.id, 2001, const Observation(status: 200));
    expect(await state.advance(live.id, 2002), isA<Granted>());
    expect(await state.advance(dead.id, 2002), isA<Denied>());
  });

  test('shares suppressed 403 and 404 without sending', () async {
    for (final status in [403, 404]) {
      final input = request(key: 'page-$status');
      final first = await state.admit(input, 1000) as Granted;
      await state.complete(first.id, 1001, Observation(status: status));
      final denial = await state.admit(input, 1002) as Denied;
      expect(denial.refusal.reason, EsiRefusalReason.negativeCached);
      expect(denial.refusal.suppressedStatus, status);
    }
  });

  test('isolates authorization and expires at logical deadline', () async {
    final first = await state.admit(request(), 1000) as Granted;
    await state.complete(first.id, 1001, const Observation(status: 403));
    expect(
      await state.admit(request(key: 'other-authorization'), 1002),
      isA<Granted>(),
    );
    expect(await state.admit(request(), 61001), isA<Granted>());
  });

  test('distinguishes not due from no local representation', () async {
    await learnBudget();
    final first = await state.admit(request(poll: true), 1000) as Granted;
    await state.complete(
      first.id,
      1001,
      const Observation(status: 304, freshUntilMs: 4000),
    );
    final early =
        await state.admit(request(poll: true, retained: true), 3999) as Denied;
    expect(early.refusal.reason, EsiRefusalReason.notDue);
    expect(
      await state.admit(
        request(key: 'next-page', poll: true, retained: true),
        3999,
      ),
      isA<Granted>(),
    );
    final unconditional =
        await state.admit(request(poll: true), 3999) as Granted;
    await state.complete(
      unconditional.id,
      3999,
      const Observation(status: 200),
    );
    final unchanged =
        await state.admit(request(poll: true, retained: true), 3999) as Denied;
    expect(unchanged.refusal.reason, EsiRefusalReason.notDue);
    expect(
      await state.admit(request(poll: true, retained: true), 4000),
      isA<Granted>(),
    );
  });

  test('deduplicates corp representation across holders', () async {
    final first = await state.admit(
      request(scope: 'holder-a', corp: 'corp', poll: true),
      1000,
    ) as Granted;
    final result = await state.admit(
      request(scope: 'holder-b', corp: 'corp', poll: true),
      1000,
    ) as Denied;
    expect(result.refusal.reason, EsiRefusalReason.corpBusy);
    await state.complete(first.id, 1001, const Observation(status: 200));
    expect(
      await state.admit(
        request(scope: 'holder-b', corp: 'corp', poll: true),
        1001,
      ),
      isA<Granted>(),
    );
  });

  test('reclaims expired corp lease', () async {
    await state.admit(
      request(scope: 'holder-a', corp: 'corp', poll: true),
      1000,
    ) as Granted;
    expect(
      await state.admit(
        request(scope: 'holder-b', corp: 'corp', poll: true),
        31000,
      ),
      isA<Granted>(),
    );
  });

  test('grants one shared status probe per retry opportunity', () async {
    final first = await state.admit(request(poll: true), 1000) as Granted;
    await state.complete(
      first.id,
      1001,
      const Observation(connectivityFailure: true),
    );
    final probe = await state.admit(request(probe: true), 1002) as Granted;
    expect(await state.admit(request(probe: true), 1002), isA<Denied>());
    expect(await state.admit(request(poll: true), 1002), isA<Denied>());
    await state.complete(
      probe.id,
      1003,
      const Observation(status: 200, probeHealthy: true),
    );
    expect(await state.admit(request(poll: true), 1004), isA<Granted>());
  });

  test('does not resume for a failed probe', () async {
    final initial = await state.admit(request(poll: true), 1000) as Granted;
    await state.complete(
      initial.id,
      1001,
      const Observation(connectivityFailure: true),
    );
    final probe = await state.admit(request(probe: true), 1002) as Granted;
    await state.complete(probe.id, 1003, const Observation(status: 200));
    expect(await state.admit(request(poll: true), 31002), isA<Denied>());
    expect(await state.admit(request(probe: true), 31002), isA<Denied>());
    expect(await state.admit(request(probe: true), 31003), isA<Granted>());
  });

  test(
    'repeated failures refresh the outage window for distinct routes',
    () async {
      Future<void> failPoll(String op, int now) async {
        final grant = await state.admit(
          request(operation: op, poll: true),
          now,
        ) as Granted;
        await state.complete(grant.id, now, const Observation(status: 503));
      }

      await failPoll('RouteOutside', 1000);
      await failPoll('RouteA', 32000);
      await failPoll('RouteA', 61000);
      final allowed = await state.admit(
        request(operation: 'Control', poll: true),
        61001,
      ) as Granted;
      await state.complete(allowed.id, 61001, const Observation(status: 200));
      await failPoll('RouteB', 63000);
      final probe = await state.admit(request(probe: true), 63001) as Granted;
      await state.complete(probe.id, 63002, const Observation(status: 503));
      final result = await state.admit(request(poll: true), 63003) as Denied;
      expect(result.refusal.reason, EsiRefusalReason.outage);
    },
  );
}
