import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

// Shared by appends and the admin release barrier. This is a different
// namespace from static-data locks; Postgres releases it with the transaction.
const _releaseLock = 682997614;
const _retention = Duration(days: 7);
const _aggregateGrace = Duration(minutes: 1);

/// Viewer resolved by trusted server code, never populated from RPC arguments.
final class EsiCallLogViewer {
  /// Binds the current member, currently owned characters and admin grant.
  const EsiCallLogViewer({
    required this.member,
    required this.characters,
    this.admin = false,
  });

  /// Trusted member identity also recorded on that member's calls.
  final int member;

  /// Character IDs the viewer currently owns.
  final Set<int> characters;

  /// Whether this viewer may request route-level aggregates.
  final bool admin;
}

/// A stable denial without caller or character details (ADR 0006).
final class EsiCallLogDenied implements Exception {
  const EsiCallLogDenied._();
}

/// A log operation could not complete; raw database details are not exposed.
final class EsiCallLogUnavailable implements Exception {
  const EsiCallLogUnavailable._();
}

/// A position in the newest-first private history of the current viewer.
typedef EsiCallLogCursor = ({DateTime recordedAt, int id});

/// The current viewer's private history projection (ADR 0006).
typedef EsiCallLogItem = ({
  EsiCallLogCursor cursor,
  DateTime recordedAt,
  int character,
  String operation,
  String? bucket,
  EsiCallLogOutcome outcome,
  int? status,
  int? cost,
  Duration latency,
});

/// A fixed-window admin projection with no member or character information.
typedef EsiCallLogRouteCount = ({String operation, int total, int errors});

/// Persists allowlisted receipts and enforces access before returning history.
final class EsiCallLogStore {
  /// Uses UTC wall time for retention and release windows.
  ///
  /// [minimumMembers] can raise, never lower, the ADR 0006 privacy floor.
  EsiCallLogStore({DateTime Function()? now, int minimumMembers = 5})
    : _now = now ?? DateTime.now,
      _minimumMembers = minimumMembers < 5 ? 5 : minimumMembers;

  final DateTime Function() _now;
  final int _minimumMembers;

  /// Appends exactly the receipt fields in a short, independent transaction.
  ///
  /// Stale receipts fail instead of modifying an already released period.
  Future<void> append(Session session, EsiCallLogEntry receipt) async {
    try {
      final written = await session.db.transaction((tx) async {
        await session.db.unsafeExecute(
          "SET LOCAL statement_timeout = '10s'",
          transaction: tx,
        );
        await session.db.unsafeQuery(
          'SELECT pg_advisory_xact_lock_shared($_releaseLock)',
          transaction: tx,
        );
        return session.db.unsafeExecute(
          '''
          INSERT INTO esi_call_log_entry
            ("recordedAt", operation, outcome, status, cost, "latencyMicros",
             bucket, "memberId", "characterId")
          SELECT @recorded::timestamp, @operation::text, @outcome::text,
            @status::bigint, @cost::bigint, @latency::bigint, @bucket::text,
            @member::bigint, @character::bigint
          WHERE (clock_timestamp() AT TIME ZONE 'UTC') <
                @recorded::timestamp + interval '10 seconds'
        ''',
          parameters: QueryParameters.named({
            'recorded': receipt.recordedAt,
            'operation': receipt.route.operationId,
            'outcome': receipt.outcome.name,
            'status': receipt.status,
            'cost': receipt.cost,
            'latency': receipt.latency.inMicroseconds,
            'bucket': receipt.bucket,
            'member': receipt.member,
            'character': receipt.character,
          }),
          transaction: tx,
        );
      });
      if (written == 1) return;
    } on Exception {
      // Never send a raw database or caller error to a diagnostic logger.
    }
    throw const EsiCallLogUnavailable._();
  }

  /// Returns up to 100 visible calls for [viewer], newest first.
  ///
  /// Repeat with the last row's cursor for older rows. A cursor does not
  /// replace the viewer predicate. Ownership and age are checked each time.
  Future<List<EsiCallLogItem>> ownRows(
    Session session,
    EsiCallLogViewer? viewer, {
    EsiCallLogCursor? after,
  }) async {
    if (viewer == null || viewer.member <= 0) throw const EsiCallLogDenied._();
    if (viewer.characters.isEmpty) return const [];
    final cutoff = _now().toUtc().subtract(_retention);
    try {
      final rows = await session.db.transaction((tx) async {
        await session.db.unsafeExecute(
          "SET LOCAL statement_timeout = '10s'",
          transaction: tx,
        );
        return EsiCallLogRow.db.find(
          session,
          where: (t) {
            final own =
                t.memberId.equals(viewer.member) &
                t.characterId.inSet(viewer.characters) &
                (t.recordedAt > cutoff);
            if (after == null) return own;
            return own &
                ((t.recordedAt < after.recordedAt) |
                    (t.recordedAt.equals(after.recordedAt) &
                        (t.id < after.id)));
          },
          orderByList: (t) => [t.recordedAt.desc(), t.id.desc()],
          limit: 100,
          transaction: tx,
        );
      });
      return [
        for (final row in rows)
          (
            cursor: (recordedAt: row.recordedAt.toUtc(), id: row.id!),
            recordedAt: row.recordedAt.toUtc(),
            character: row.characterId!,
            operation: row.operation,
            bucket: row.bucket,
            outcome: EsiCallLogOutcome.values.byName(row.outcome),
            status: row.status,
            cost: row.cost,
            latency: Duration(microseconds: row.latencyMicros),
          ),
      ];
    } on Exception {
      throw const EsiCallLogUnavailable._();
    }
  }

  /// Returns route counts from one fixed window, to a trusted admin only.
  ///
  /// No subject or period filter is accepted. Unattributed private calls
  /// cannot contribute even if a route passes the distinct-member threshold.
  Future<List<EsiCallLogRouteCount>> routeCounts(
    Session session,
    EsiCallLogViewer? viewer,
  ) async {
    if (viewer == null || viewer.member <= 0 || !viewer.admin) {
      throw const EsiCallLogDenied._();
    }
    final releasedAt = _now().toUtc().subtract(_aggregateGrace);
    final end = DateTime.utc(releasedAt.year, releasedAt.month, releasedAt.day);
    final start = end.subtract(const Duration(days: 5));
    try {
      await session.db.transaction((tx) async {
        await session.db.unsafeExecute(
          "SET LOCAL lock_timeout = '1s'",
          transaction: tx,
        );
        await session.db.unsafeQuery(
          'SELECT pg_advisory_xact_lock($_releaseLock)',
          transaction: tx,
        );
      });
      final rows = await session.db.transaction((tx) async {
        await session.db.unsafeExecute(
          "SET LOCAL statement_timeout = '10s'",
          transaction: tx,
        );
        return session.db.unsafeQuery(
          '''
          SELECT operation, count(*), count(*) FILTER (WHERE outcome = 'error'),
            count(DISTINCT "memberId"), count("memberId"),
            count("memberId") FILTER (WHERE outcome = 'error')
          FROM esi_call_log_entry
          WHERE "recordedAt" >= @start::timestamp
            AND "recordedAt" < @end::timestamp
          GROUP BY operation ORDER BY operation
        ''',
          parameters: QueryParameters.named({'start': start, 'end': end}),
          transaction: tx,
        );
      });
      final counts = <EsiCallLogRouteCount>[];
      for (final row in rows) {
        final operation = row[0]! as String;
        final route = esiCatalogue[operation];
        if (route == null) continue;
        if (route.requiresAuthentication) {
          if ((row[3]! as int) < _minimumMembers) continue;
          counts.add((
            operation: operation,
            total: row[4]! as int,
            errors: row[5]! as int,
          ));
        } else {
          counts.add((
            operation: operation,
            total: row[1]! as int,
            errors: row[2]! as int,
          ));
        }
      }
      return counts;
    } on Exception {
      throw const EsiCallLogUnavailable._();
    }
  }

  /// Deletes a bounded batch at the seven-day UTC cutoff, inclusive.
  Future<int> prune(Session session) async {
    try {
      return await session.db.transaction((tx) async {
        await session.db.unsafeExecute(
          "SET LOCAL statement_timeout = '10s'",
          transaction: tx,
        );
        return session.db.unsafeExecute(
          '''
          DELETE FROM esi_call_log_entry WHERE id IN (
            SELECT id FROM esi_call_log_entry
            WHERE "recordedAt" <= @cutoff::timestamp
            ORDER BY "recordedAt", id LIMIT 1000 FOR UPDATE SKIP LOCKED
          )
        ''',
          parameters: QueryParameters.named({
            'cutoff': _now().toUtc().subtract(_retention),
          }),
          transaction: tx,
        );
      });
    } on Exception {
      throw const EsiCallLogUnavailable._();
    }
  }
}
