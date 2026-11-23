import 'dart:async';

import '../generated/protocol.dart';
import 'admin_operation_store.dart';
import 'read_work_tokens.dart';
import 'static_data_access.dart';

/// Reads one operation on an independent session within its D9 deadline.
Future<AdminOperationAnswer> readPublicAdminOperation(
  StaticDataAccess access,
  String rawId,
) async {
  final clock = access.clock;
  final deadline = clock.now().add(const Duration(seconds: 2));
  final id = adminRequestId(rawId);
  if (id == null) {
    return AdminOperationAnswer(
      state: AdminOperationReadState.unknownOperation,
    );
  }

  final work = access.tokens.tryRun<SdeAdminOperation?>(
    ReadWorkKind.operation,
    (sent) => access.withSession(
      (session) => session.db.transaction((tx) async {
        void before() {
          if (!clock.now().isBefore(deadline)) {
            throw TimeoutException('operation read owner deadline');
          }
          sent();
        }

        before();
        await session.db.unsafeExecute(
          "SET LOCAL statement_timeout = '1s'",
          transaction: tx,
        );
        before();
        return readAdminOperation(session, id, transaction: tx);
      }),
    ),
  );
  if (work == null) return _busy();

  final result = Completer<AdminOperationAnswer>();
  final timer = clock.once(deadline.difference(clock.now()), () {
    if (!result.isCompleted) result.complete(_busy());
  });
  unawaited(
    work.then<void>(
      (row) {
        if (result.isCompleted) return;
        result.complete(
          clock.now().isBefore(deadline) ? _project(row) : _busy(),
        );
      },
      onError: (Object _, StackTrace _) {
        if (!result.isCompleted) result.complete(_busy());
      },
    ),
  );
  try {
    return await result.future;
  } finally {
    timer.cancel();
  }
}

AdminOperationAnswer _busy() =>
    AdminOperationAnswer(state: AdminOperationReadState.operationReadBusy);

AdminOperationAnswer _project(SdeAdminOperation? row) => switch (row) {
  null => AdminOperationAnswer(state: AdminOperationReadState.unknownOperation),
  SdeAdminOperation(:final kind, state: SdeAdminOperationState.waiting) =>
    AdminOperationAnswer(state: AdminOperationReadState.waiting, kind: kind),
  SdeAdminOperation(:final kind, state: SdeAdminOperationState.running) =>
    AdminOperationAnswer(state: AdminOperationReadState.running, kind: kind),
  SdeAdminOperation(:final kind, state: SdeAdminOperationState.ended) =>
    AdminOperationAnswer(
      state: AdminOperationReadState.ended,
      kind: kind,
      operation: adminOperationView(row),
    ),
};
