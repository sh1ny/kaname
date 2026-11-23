import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'public_reason.dart';
import 'static_data_lock.dart';

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Canonicalizes a UUID v4 identifying exactly one app press or setting write.
String? adminRequestId(String raw) =>
    _uuidV4.hasMatch(raw) ? raw.toLowerCase() : null;

/// The id, action and revision bound to one operation (D21, C15).
typedef AdminOperationKey = ({
  String id,
  SdeAdminOperationKind kind,
  int? revision,
});

/// Reads one current operation by its unique id, including open older jobs.
Future<SdeAdminOperation?> readAdminOperation(
  Session session,
  String id, {
  Transaction? transaction,
}) async {
  final row = await SdeAdminOperation.db.findFirstRow(
    session,
    where: (t) => t.operationId.equals(UuidValue.fromString(id)),
    transaction: transaction,
  );
  if (row case SdeAdminOperation(
    state: SdeAdminOperationState.ended,
    endedAt: final endedAt?,
  )) {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 30));
    if (endedAt.isBefore(cutoff)) return null;
  }
  return row;
}

/// D21: holds a shared admission lock through the expired-row cleanup and
/// insert, so a startup recovery from another process orders after the store.
/// Returns false if the id is already durably in use; does not modify it.
Future<bool> insertAdminOperation(Session session, AdminOperationKey key) =>
    session.db.transaction((tx) async {
      await session.db.unsafeQuery(
        'SELECT pg_advisory_xact_lock_shared($staticDataAdmissionLockKey)',
        transaction: tx,
      );
      await session.db.unsafeExecute('''
        DELETE FROM sde_admin_operation WHERE state = 'ended'
          AND "endedAt" < (clock_timestamp() AT TIME ZONE 'UTC')
            - interval '30 days'
      ''', transaction: tx);
      final inserted = await session.db.unsafeQuery(
        '''
        INSERT INTO sde_admin_operation
          ("operationId", kind, "expectedRevision", state, "createdAt")
        VALUES (@id::text::uuid, @kind::text, @revision::bigint, 'waiting',
          clock_timestamp() AT TIME ZONE 'UTC')
        ON CONFLICT ("operationId") DO NOTHING RETURNING id
      ''',
        parameters: QueryParameters.named({
          'id': key.id,
          'kind': key.kind.name,
          'revision': key.revision,
        }),
        transaction: tx,
      );
      return inserted.isNotEmpty;
    });

/// Projects the authoritative end into the public RPC surface (D15, D21).
AdminOperationView adminOperationView(SdeAdminOperation row) =>
    AdminOperationView(
      outcome: row.outcome!,
      reason: publicReasonOf(row.failureReason),
      activeBuild: row.activeBuild,
      changedBuilds: row.changedBuilds,
    );
