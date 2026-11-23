/// The future call that runs the daily build check.
library;

import 'dart:async';

import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/future_calls.dart';
import '../workers/worker_messages.dart';
import 'static_data_runtime.dart';

/// The identifier of the daily check's future-call row.
///
/// The start hook cancels it before it schedules the check, and tests read
/// the row by it.
const String dailyCheckIdentifier = 'kaname-sde-daily-check';

/// Schedules the daily check on [pod]: cancels every row with
/// [dailyCheckIdentifier] and then schedules one recurring call at
/// [DailyBuildCheckSchedule.cron].
Future<void> scheduleDailyCheck(Serverpod pod) async {
  final futureCalls = pod.futureCalls;
  await futureCalls.cancel(dailyCheckIdentifier);
  await futureCalls
      .callRecurring(identifier: dailyCheckIdentifier)
      .cron(DailyBuildCheckSchedule.cron)
      .staticDataCheckCall
      .run();
}

/// Runs the daily build check on the compute worker.
///
/// Serverpod's generated code creates the instance, so the call reaches the
/// worker through [staticDataRuntime]. It returns at once whether it sends a
/// check or skips a still-pending one. Replies are logged after the RPC
/// returns. The supervisor answers "worker not running" immediately and
/// answers "worker stopped"; both are logged as warnings. A server whose
/// start hook did not run (any role or run mode without one) has no
/// supervisor: the call logs that and returns. Nothing is retried here: the
/// next cron run is already scheduled (Serverpod schedules it when it claims
/// this one), and the start-up catch-up covers a missed day.
///
/// ## Carried constraints
///
/// - **C9:** The call never awaits `supervisor.ready` or a job's answer.
///   Serverpod drains running future calls before it runs the shutdown task
///   that stops the worker, so a waiting call would hold the server's
///   shutdown for a whole import, or for ever while the worker fails to
///   start. Later future calls that drive worker jobs follow the same rule.
class StaticDataCheckCall extends FutureCall {
  /// Sends the check to the worker and returns without waiting for it.
  Future<void> run(Session session) async {
    final supervisor = staticDataRuntime.supervisor;
    if (supervisor == null) {
      session.log(
        'static data: daily check skipped, no compute worker runs here',
        level: LogLevel.info,
      );
      return;
    }
    final log = staticDataRuntime.log;
    final announcer = staticDataRuntime.announcer;
    final check = staticDataRuntime.tryCheck(CheckTrigger.daily);
    if (check == null) {
      log(
        WorkerLogLevel.warning,
        'static data: daily check skipped, previous check is still pending',
      );
      return;
    }
    unawaited(
      check.then<void>(
        (reply) {
          if (announcer != null) unawaited(announcer.workerReplied(reply));
          log(switch (reply) {
            BuildCheckFinished(
              result: BuildCheckFailed() ||
                  BuildStaged() ||
                  SwitchUnconfirmed(),
            ) =>
              WorkerLogLevel.warning,
            BuildCheckFinished() => WorkerLogLevel.info,
            _ => WorkerLogLevel.warning,
          }, 'static data: daily check answered: $reply');
        },
        onError: (Object error) {
          log(WorkerLogLevel.error, 'static data: daily check failed: $error');
        },
      ),
    );
  }
}
