import 'package:kaname_server/src/generated/future_calls.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:serverpod/protocol.dart'
    show FutureCallClaimEntry, FutureCallEntry;
import 'package:serverpod/serverpod.dart';
// Drive the pinned framework executor directly so automatic scans cannot race.
// ignore: implementation_imports
import 'package:serverpod/src/server/serverpod.dart'
    show ServerpodInternalMethods;
import 'package:test/test.dart';

import '../support/in_process_pod.dart';

void main() {
  test('a due one-shot with a stale claim dispatches once', () async {
    final harness = await InProcessPod.start(
      configOverride: (config) => config.copyWith(
        futureCallExecutionEnabled: false,
        redis: RedisConfig(enabled: false, host: 'localhost', port: 8091),
      ),
    );
    addTearDown(harness.stop);
    await harness.pod.withSession((session) async {
      final old = await EsiCallLogRow.db.insertRow(
        session,
        EsiCallLogRow(
          recordedAt: DateTime.utc(2000),
          operation: 'GetStatus',
          outcome: 'success',
          latencyMicros: 1,
        ),
      );
      const name = 'affiliation-claim-test';
      final call = _CountingPrune();
      final manager = harness.pod.futureCallManager!;
      manager.registerFutureCall(call, name);
      await manager.scheduleFutureCall(
        name,
        null,
        DateTime.utc(2000),
        harness.pod.serverId,
        name,
      );
      final pending = (await FutureCallEntry.db.findFirstRow(
        session,
        where: (entry) => entry.identifier.equals(name),
      ))!;
      await FutureCallClaimEntry.db.insertRow(
        session,
        FutureCallClaimEntry(
          futureCallId: pending.id,
          lastHeartbeatTime: DateTime.utc(2000),
        ),
      );

      await manager.runScheduledFutureCalls();

      expect(call.invocations, 1);
      expect(await EsiCallLogRow.db.findById(session, old.id!), isNull);
      expect(await FutureCallEntry.db.findById(session, pending.id!), isNull);
      expect(
        await FutureCallClaimEntry.db.count(
          session,
          where: (claim) => claim.futureCallId.equals(pending.id),
        ),
        0,
      );
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}

final class _CountingPrune extends EsiCallLogPruneCallRunFutureCall {
  int invocations = 0;

  @override
  Future<void> invoke(Session session, SerializableModel? object) {
    invocations++;
    return super.invoke(session, object);
  }
}
