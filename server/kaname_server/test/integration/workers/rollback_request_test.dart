import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/workers/worker_messages.dart';
import 'package:kaname_static_data/kaname_static_data.dart'
    show RollbackOutcome;
import 'package:test/test.dart';

import '../support/announcer_support.dart';
import '../support/migrated_database.dart';
import '../support/worker_harness.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Typed rollback', (sessions, _) {
    test(
      'a rollback request through the worker answers the job\'s outcome',
      () async {
        final session = sessions.build();
        await seedBuild(session, 51, SdeBuildState.previous);
        await seedBuild(session, 52, SdeBuildState.active);
        await SdeBuildRevision.db.insertRow(
          session,
          SdeBuildRevision(id: 1, revision: 4),
        );
        const operationId = '04933112-52ba-4a85-b60f-2896ce06d5bf';
        await session.db.unsafeExecute(
          'INSERT INTO sde_admin_operation '
          '("operationId", kind, "expectedRevision", state, "createdAt") '
          "VALUES ('$operationId', 'rollback', 4, 'waiting', now())",
        );
        final worker = await WorkerHarness.start(
          postgres: await migratedDatabaseSettings(session),
        );
        addTearDown(worker.close);
        worker.sendMessage(
          const RunRollback(
            requestId: 9,
            operationId: operationId,
            expectedRevision: 4,
          ),
        );
        final reply = await worker.waitFor<RollbackFinished>(
          (r) => r.requestId == 9,
        );
        expect(reply.outcome, RollbackOutcome.rolledBack);
        expect(reply.activeBuild, 51);
        final operation = (await SdeAdminOperation.db.find(session)).single;
        expect(operation.state, SdeAdminOperationState.ended);
        expect(operation.outcome, SdeAdminOperationOutcome.rolledBack);
        expect(operation.changedBuilds, isTrue);
        expect((await SdeBuildRevision.db.find(session)).single.revision, 5);
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}
