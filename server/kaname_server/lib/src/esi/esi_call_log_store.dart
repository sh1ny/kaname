import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

// Shared by appends and the admin release barrier. This is a different
// namespace from static-data locks; Postgres releases it with the transaction.
const _releaseLock = 682997614;
const _retention = Duration(days: 7);
const _aggregateGrace = Duration(minutes: 1);
const _aggregateRange = Duration(days: 5);

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
  /// Uses the database UTC clock for release and pruning. Tests can supply
  /// [now] and request an immediate non-queuing lock attempt.
  ///
  /// [minimumMembers] can raise, never lower, the ADR 0006 privacy floor.
  EsiCallLogStore({
    DateTime Function()? now,
    int minimumMembers = 5,
    bool waitForReleaseLock = true,
  }) : _now = now,
       _minimumMembers = minimumMembers < 5 ? 5 : minimumMembers,
       _waitForReleaseLock = waitForReleaseLock;

  final DateTime Function()? _now;
  final bool _waitForReleaseLock;
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
          WHERE COALESCE(@clock::timestamp, clock_timestamp() AT TIME ZONE 'UTC')
                  < @recorded::timestamp + interval '10 seconds'
            AND NOT EXISTS (
              SELECT 1 FROM esi_call_log_seal
              WHERE id = 1 AND "windowEnd" > @recorded::timestamp
            )
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
            'clock': _now?.call().toUtc(),
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
    final cutoff = (_now?.call() ?? DateTime.now()).toUtc().subtract(
      _retention,
    );
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

  /// Returns the latest already committed seal without proposing a window.
  Future<DateTime?> currentSeal(
    Session session, {
    Transaction? transaction,
  }) async {
    final rows = await session.db.unsafeQuery(
      'SELECT "windowEnd" FROM esi_call_log_seal WHERE id = 1',
      transaction: transaction,
    );
    return rows.isEmpty ? null : (rows.single.single as DateTime).toUtc();
  }

  /// Returns a committed seal, first advancing it if another window is eligible.
  Future<DateTime> sealWindow(Session session) async {
    try {
      final preview = await _clockAndSeal(session);
      final end = preview.end;
      if (end != null && !_eligibleEnd(preview.utc).isAfter(end)) return end;
      return await session.db.transaction((tx) async {
        await _lockRelease(session, tx);
        final sample = await _clockAndSeal(session, transaction: tx);
        final candidate = _eligibleEnd(sample.utc);
        final current = sample.end;
        if (current != null && !candidate.isAfter(current)) return current;
        await _writeSeal(session, tx, candidate);
        return candidate;
      });
    } on Exception {
      throw const EsiCallLogUnavailable._();
    }
  }

  /// Records a first exclusion inside the membership transaction. A retired
  /// account's evidence stays in this table; the caller holds its account lock
  /// or has just inserted it in this transaction.
  Future<void> excludeAccount(
    Session session,
    Transaction tx,
    int account,
  ) async {
    final existing = await session.db.unsafeQuery(
      'SELECT 1 FROM esi_call_log_exclusion WHERE id = @id::bigint',
      parameters: QueryParameters.named({'id': account}),
      transaction: tx,
    );
    if (existing.isNotEmpty) return;
    await session.db.unsafeExecute(
      "SET LOCAL lock_timeout = '1s'",
      transaction: tx,
    );
    await session.db.unsafeQuery(
      'SELECT pg_advisory_xact_lock_shared($_releaseLock)',
      transaction: tx,
    );
    await session.db.unsafeExecute(
      '''
      INSERT INTO esi_call_log_exclusion (id, "excludedAt")
      VALUES (@id::bigint, GREATEST(
        COALESCE(@clock::timestamp, clock_timestamp() AT TIME ZONE 'UTC'),
        (SELECT "windowEnd" + interval '1 minute' FROM esi_call_log_seal WHERE id = 1)
      )) ON CONFLICT (id) DO NOTHING
      ''',
      parameters: QueryParameters.named({
        'id': account,
        'clock': _now?.call().toUtc(),
      }),
      transaction: tx,
    );
  }

  static DateTime _eligibleEnd(DateTime utc) {
    final releasedAt = utc.subtract(_aggregateGrace);
    return DateTime.utc(releasedAt.year, releasedAt.month, releasedAt.day);
  }

  Future<({DateTime utc, DateTime? end})> _clockAndSeal(
    Session session, {
    Transaction? transaction,
  }) async {
    final rows = await session.db.unsafeQuery(
      '''
      SELECT COALESCE(@clock::timestamp, clock_timestamp() AT TIME ZONE 'UTC'),
             (SELECT "windowEnd" FROM esi_call_log_seal WHERE id = 1)
      ''',
      parameters: QueryParameters.named({'clock': _now?.call().toUtc()}),
      transaction: transaction,
    );
    final row = rows.single;
    return (
      utc: (row[0] as DateTime).toUtc(),
      end: (row[1] as DateTime?)?.toUtc(),
    );
  }

  Future<void> _lockRelease(Session session, Transaction tx) async {
    await session.db.unsafeExecute(
      "SET LOCAL statement_timeout = '10s'",
      transaction: tx,
    );
    if (!_waitForReleaseLock) {
      final rows = await session.db.unsafeQuery(
        'SELECT pg_try_advisory_xact_lock($_releaseLock)',
        transaction: tx,
      );
      if (rows.single.single != true) throw const EsiCallLogUnavailable._();
      return;
    }
    await session.db.unsafeExecute(
      "SET LOCAL lock_timeout = '1s'",
      transaction: tx,
    );
    await session.db.unsafeQuery(
      'SELECT pg_advisory_xact_lock($_releaseLock)',
      transaction: tx,
    );
  }

  static Future<void> _writeSeal(
    Session session,
    Transaction tx,
    DateTime end,
  ) async {
    await session.db.unsafeExecute(
      '''
      INSERT INTO esi_call_log_seal (id, "windowEnd") VALUES (1, @end::timestamp)
      ON CONFLICT (id) DO UPDATE SET "windowEnd" = excluded."windowEnd"
      ''',
      parameters: QueryParameters.named({'end': end}),
      transaction: tx,
    );
  }

  /// Returns route counts from one fixed window, to a trusted admin only.
  ///
  /// No subject or period filter is accepted. Unattributed private calls
  /// cannot contribute even if a route passes the distinct-member threshold.
  Future<List<EsiCallLogRouteCount>> routeCounts(
    Session session,
    EsiCallLogViewer? viewer,
  ) async => (await routeCountsWithWindow(session, viewer)).rows;

  /// Selects a seal and reads its rows from a matching database snapshot.
  Future<({DateTime window, List<EsiCallLogRouteCount> rows})>
  routeCountsWithWindow(Session session, EsiCallLogViewer? viewer) async {
    _requireAdmin(viewer);
    final end = await sealWindow(session);
    final rows = await countsForSeal(session, viewer, end);
    if (await currentSeal(session) != end)
      throw const EsiCallLogUnavailable._();
    return (window: end, rows: rows);
  }

  static void _requireAdmin(EsiCallLogViewer? viewer) {
    if (viewer == null || viewer.member <= 0 || !viewer.admin) {
      throw const EsiCallLogDenied._();
    }
  }

  /// Computes the selected window only if that seal is present in the same
  /// database snapshot as its inputs. The caller fences response admission.
  Future<List<EsiCallLogRouteCount>> countsForSeal(
    Session session,
    EsiCallLogViewer? viewer,
    DateTime end,
  ) async {
    _requireAdmin(viewer);
    final start = end.subtract(_aggregateRange);
    try {
      final rows = await session.db.transaction(
        (tx) async {
          await session.db.unsafeExecute(
            "SET LOCAL statement_timeout = '10s'",
            transaction: tx,
          );
          if (await currentSeal(session, transaction: tx) != end) {
            throw const EsiCallLogUnavailable._();
          }
          return session.db.unsafeQuery(
            '''
            WITH receipts AS MATERIALIZED (
              SELECT operation, outcome, "memberId", "characterId", "accountExcluded"
              FROM esi_call_log_entry
              WHERE "recordedAt" >= @start::timestamp AND "recordedAt" < @end::timestamp
            ), shared_characters AS (
              SELECT "characterId" FROM receipts
              WHERE "characterId" IS NOT NULL AND "memberId" IS NOT NULL
              GROUP BY "characterId" HAVING count(DISTINCT "memberId") > 1
            ), ineligible AS (
              SELECT DISTINCT "memberId" FROM receipts
              WHERE "memberId" IS NOT NULL AND (
                "accountExcluded" IS TRUE
                OR "characterId" IN (SELECT "characterId" FROM shared_characters)
              )
            )
            SELECT r.operation, count(*), count(*) FILTER (WHERE r.outcome = 'error'),
              count(DISTINCT r."memberId") FILTER (WHERE x."memberId" IS NULL AND e.id IS NULL),
              count(r."memberId"), count(r."memberId") FILTER (WHERE r.outcome = 'error')
            FROM receipts AS r
            LEFT JOIN ineligible AS x ON x."memberId" = r."memberId"
            LEFT JOIN esi_call_log_exclusion AS e ON e.id = r."memberId"
              AND e."excludedAt" < @cutoff::timestamp
            GROUP BY r.operation ORDER BY r.operation
            ''',
            parameters: QueryParameters.named({
              'start': start,
              'end': end,
              'cutoff': end.add(_aggregateGrace),
            }),
            transaction: tx,
          );
        },
        settings: const TransactionSettings(
          isolationLevel: IsolationLevel.repeatableRead,
        ),
      );
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
        await _lockRelease(session, tx);
        final sample = await _clockAndSeal(session, transaction: tx);
        final cutoff = sample.utc.subtract(_retention);
        final end = sample.end;
        if (end != null && !cutoff.isBefore(end.subtract(_aggregateRange))) {
          final candidate = _eligibleEnd(sample.utc);
          if (!candidate.isAfter(end)) throw const EsiCallLogUnavailable._();
          await _writeSeal(session, tx, candidate);
        }
        final removed = await session.db.unsafeExecute(
          '''
          DELETE FROM esi_call_log_entry WHERE id IN (
            SELECT id FROM esi_call_log_entry
            WHERE "recordedAt" <= @cutoff::timestamp
            ORDER BY "recordedAt", id LIMIT 1000 FOR UPDATE SKIP LOCKED
          )
        ''',
          parameters: QueryParameters.named({'cutoff': cutoff}),
          transaction: tx,
        );
        // The first non-empty prune also establishes a floor: a later clock
        // step must not release an unsealed window whose inputs we just removed.
        if (end == null && removed != 0) {
          await _writeSeal(session, tx, _eligibleEnd(sample.utc));
        }
        return removed;
      });
    } on Exception {
      throw const EsiCallLogUnavailable._();
    }
  }
}
