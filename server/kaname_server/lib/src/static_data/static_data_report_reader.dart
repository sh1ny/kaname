import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_static_data/kaname_static_data.dart';

import '../generated/protocol.dart';
import '../realtime/server_clock.dart';
import 'change_report_cap.dart';
import 'public_reason.dart';
import 'read_work_tokens.dart';
import 'static_data_start_hook.dart' show WithSession;

/// Reads the retained build pair and its report in one bounded snapshot.
final class StaticDataReportReader {
  /// Uses independent pooled sessions and the shared report work budget.
  StaticDataReportReader({
    required this.withSession,
    required this.tokens,
    this.clock = const SystemClock(),
  });

  /// Opens a session owned by the read, not by its caller.
  final WithSession withSession;

  /// Holds each work token through session cleanup and statement grace.
  final ReadWorkTokens tokens;

  /// Supplies the queue and owner deadlines.
  final ServerClock clock;

  final Queue<_Waiter> _waiting = Queue();
  bool _running = false;

  /// Returns a public report or a bounded failure outcome.
  Future<StaticDataChangeReport> read() {
    final waiter = _Waiter();
    if (_running) {
      if (_waiting.length == 4) return Future.value(_busy());
      _waiting.addLast(waiter);
      waiter.timer = clock.once(const Duration(seconds: 5), () {
        if (_waiting.remove(waiter)) waiter.answer.complete(_busy());
      });
    } else {
      _start(waiter);
    }
    return waiter.answer.future;
  }

  void _start(_Waiter waiter) {
    _running = true;
    final deadline = clock.now().add(const Duration(seconds: 12));
    final work = tokens.tryRun<_ReportRow>(
      ReadWorkKind.report,
      (sent) => withSession(
        (session) => session.db.transaction((tx) async {
          void before() {
            if (!clock.now().isBefore(deadline)) {
              throw TimeoutException('report read owner deadline');
            }
            sent();
          }

          before();
          await session.db.unsafeExecute(
            "SET LOCAL statement_timeout = '10s'",
            transaction: tx,
          );
          before();
          await session.db.unsafeExecute(
            'SET TRANSACTION READ ONLY',
            transaction: tx,
          );
          before();
          final rows = await session.db.unsafeQuery('''
WITH builds AS (
  SELECT max("build") FILTER (WHERE "activeMarker" IS TRUE) AS active,
         max("build") FILTER (WHERE "previousMarker" IS TRUE) AS previous
  FROM sde_build
)
SELECT builds.active, builds.previous, d."fromBuild", d."toBuild",
       d."outcome", d."failureReason", d."reportBytes",
       CASE WHEN d."outcome" = 'succeeded' AND d."reportBytes" <= 8388608
            THEN d."report"::text ELSE NULL END
FROM builds
LEFT JOIN LATERAL (
  SELECT * FROM sde_build_diff
  WHERE ("fromBuild" = builds.active AND "toBuild" = builds.previous)
     OR ("fromBuild" = builds.previous AND "toBuild" = builds.active)
  ORDER BY "createdAt" DESC, id DESC LIMIT 1
) AS d ON TRUE
''', transaction: tx);
          final row = rows.single;
          return _ReportRow(
            active: row[0] as int?,
            previous: row[1] as int?,
            from: row[2] as int?,
            to: row[3] as int?,
            outcome: row[4] as String?,
            reason: row[5] as String?,
            bytes: row[6] as int?,
            report: row[7] as String?,
          );
        }),
      ),
    );
    if (work == null) {
      waiter.answer.complete(_busy());
      _finish();
      return;
    }
    final timer = clock.once(const Duration(seconds: 12), () {
      if (!waiter.answer.isCompleted) {
        waiter.answer.complete(_busy());
        _finish();
      }
    });
    unawaited(
      work.then<void>(
        (row) {
          if (waiter.answer.isCompleted) return;
          timer.cancel();
          try {
            waiter.answer.complete(
              clock.now().isBefore(deadline) ? _project(row) : _busy(),
            );
          } catch (_) {
            waiter.answer.complete(_busy());
          }
          _finish();
        },
        onError: (Object _, StackTrace _) {
          if (waiter.answer.isCompleted) return;
          timer.cancel();
          waiter.answer.complete(_busy());
          _finish();
        },
      ),
    );
  }

  void _finish() {
    _running = false;
    if (_waiting.isNotEmpty) {
      final next = _waiting.removeFirst();
      next.timer?.cancel();
      _start(next);
    }
  }
}

final class _Waiter {
  final answer = Completer<StaticDataChangeReport>();
  Timer? timer;
}

final class _ReportRow {
  const _ReportRow({
    required this.active,
    required this.previous,
    required this.from,
    required this.to,
    required this.outcome,
    required this.reason,
    required this.bytes,
    required this.report,
  });
  final int? active;
  final int? previous;
  final int? from;
  final int? to;
  final String? outcome;
  final String? reason;
  final int? bytes;
  final String? report;
}

StaticDataChangeReport _busy() =>
    StaticDataChangeReport(outcome: StaticDataReportOutcome.reportBusy);

StaticDataChangeReport _project(_ReportRow row) {
  if (row.active == null || row.previous == null) {
    return StaticDataChangeReport(
      outcome: StaticDataReportOutcome.noPreviousBuild,
      activeBuild: row.active,
    );
  }
  if (row.outcome == null) {
    return StaticDataChangeReport(
      outcome: StaticDataReportOutcome.reportMissing,
      activeBuild: row.active,
    );
  }
  if (row.outcome == 'failed') {
    return StaticDataChangeReport(
      outcome: StaticDataReportOutcome.comparisonFailed,
      activeBuild: row.active,
      fromBuild: row.from,
      toBuild: row.to,
      reason: publicReasonOf(row.reason),
    );
  }
  if (row.outcome != 'succeeded' || row.bytes == null) {
    throw const FormatException('Invalid stored report metadata');
  }
  if (row.bytes! > 8388608) {
    return StaticDataChangeReport(
      outcome: StaticDataReportOutcome.reportTooLarge,
      activeBuild: row.active,
      fromBuild: row.from,
      toBuild: row.to,
    );
  }
  final report = BuildDiffReport.fromSdeJson(
    SdeJson.fromJson(jsonDecode(row.report!)),
  );
  return capChangeReport(report, activeBuild: row.active!);
}
