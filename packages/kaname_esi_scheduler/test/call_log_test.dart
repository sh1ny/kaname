import 'dart:async';
import 'dart:convert';

import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:test/test.dart';

void main() {
  late List<EsiCallLogEntry> rows;
  late int elapsed;
  late int failures;

  setUp(() {
    rows = [];
    elapsed = 0;
    failures = 0;
  });

  EsiScheduler scheduler(EsiWireSend send, {EsiCallLogSink? write}) =>
      EsiScheduler(
        state: MemorySchedulerState(),
        key: const [1],
        send: send,
        now: () => DateTime.utc(2026),
        elapsedMicroseconds: () => elapsed,
        callLog: write ?? (row) async => rows.add(row),
        onCallLogFailure: () => failures++,
      );

  test('captures status cost and elapsed latency', () async {
    final runtime = scheduler((request, bearer, validator) async {
      elapsed += 6500;
      return WireResponse(
        EsiResponse(
          status: 200,
          headers: const {
            'x-ratelimit-group': 'not-the-catalogue-group',
            'x-ratelimit-limit': '1800/15m',
            'x-ratelimit-remaining': '1799',
            'x-ratelimit-used': '1',
          },
          body: utf8.encode('[]'),
        ),
      );
    });
    final client = runtime.client(
      EsiPriority.sync,
      principal: EsiPrincipal(
        application: 'app',
        character: 99000001,
        member: 5,
        generation: 'one',
        bearer: () => 'synthetic test token',
      ),
    );
    expect(
      await client.getCharactersCharacterIdAssets(characterId: 99000001),
      isA<EsiSuccess<List<CharactersCharacterIdAssetsGetItem>>>(),
    );
    await runtime.drainCallLog();
    final row = rows.single;
    expect(row.route.operationId, 'GetCharactersCharacterIdAssets');
    expect(row.bucket, 'char-asset');
    expect(row.member, 5);
    expect(row.character, 99000001);
    expect(row.recordedAt, DateTime.utc(2026));
    expect(row.status, 200);
    expect(row.cost, 1);
    expect(row.latency, const Duration(microseconds: 6500));
    expect(row.outcome, EsiCallLogOutcome.success);
  });

  test('refusals and failures retain distinct outcomes', () async {
    final runtime = scheduler(
      (_, _, _) async => WireFailure(head: EsiResponse(status: 503)),
    );
    final client = runtime.client(EsiPriority.sync);
    expect(
      await client.getCharactersCharacterIdAssets(characterId: 99000001),
      isA<EsiNotSent<List<CharactersCharacterIdAssetsGetItem>>>(),
    );
    expect(await client.getAlliances(), isA<EsiTransportFailed<List<int>>>());
    await runtime.drainCallLog();
    expect(rows.map((row) => (row.outcome, row.status, row.cost)), [
      (EsiCallLogOutcome.notSent, null, 0),
      (EsiCallLogOutcome.error, 503, null),
    ]);
  });

  test('unknown route never reaches sink', () async {
    final runtime = scheduler((_, _, _) async => fail('sent unknown route'));
    final result = await runtime
        .client(EsiPriority.sync)
        .transport
        .send(
          EsiRequest(
            method: EsiMethod.get,
            operationId: 'unknown',
            target: Uri(path: '/unknown'),
            headers: const {},
          ),
        );
    await runtime.drainCallLog();
    expect(result, isA<EsiTransportRefused>());
    expect(rows, isEmpty);
  });

  test('poll and non-poll decode failures retain HTTP status', () async {
    final runtime = scheduler(
      (_, _, _) async =>
          WireResponse(EsiResponse(status: 200, body: utf8.encode('{}'))),
    );
    for (final poll in [true, false]) {
      expect(
        await runtime.client(EsiPriority.sync, poll: poll).getAlliances(),
        isA<EsiMalformed<List<int>>>(),
      );
    }
    await runtime.drainCallLog();
    expect(rows.map((row) => (row.outcome, row.status)), [
      (EsiCallLogOutcome.error, 200),
      (EsiCallLogOutcome.error, 200),
    ]);
  });

  test(
    'write failure and capacity never change or replay the exchange',
    () async {
      final held = Completer<void>();
      final writerStarted = Completer<void>();
      var sends = 0;
      final runtime = scheduler(
        (_, _, _) async {
          sends++;
          return WireResponse(EsiResponse(status: 304));
        },
        write: (_) async {
          if (!writerStarted.isCompleted) writerStarted.complete();
          await held.future;
          throw StateError('private storage error');
        },
      );
      final client = runtime.client(EsiPriority.sync);
      try {
        expect(await client.getAlliances(), isA<EsiNotModified<List<int>>>());
        await writerStarted.future;
        for (var i = 1; i <= EsiScheduler.callLogCapacity; i++) {
          expect(await client.getAlliances(), isA<EsiNotModified<List<int>>>());
        }
        expect(failures, 1);
      } finally {
        held.complete();
        await runtime.drainCallLog();
      }
      expect(failures, EsiScheduler.callLogCapacity + 1);
      expect(sends, EsiScheduler.callLogCapacity + 1);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
