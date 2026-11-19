/// The future call that runs the daily build check.
library;

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
/// worker through [staticDataRuntime]. It awaits the supervisor's `ready`,
/// asks it to run the check and returns once the job has answered. A server
/// whose start hook did not run (any role or run mode without one) has no
/// supervisor: the call logs that and returns. A worker that is down or
/// refuses the request is logged too; the next cron run is already scheduled
/// (Serverpod schedules it when it claims this one), so nothing is retried
/// here.
class StaticDataCheckCall extends FutureCall {
  /// Runs the check.
  Future<void> run(Session session) async {
    final supervisor = staticDataRuntime.supervisor;
    if (supervisor == null) {
      session.log(
        'static data: daily check skipped, no compute worker runs here',
        level: LogLevel.info,
      );
      return;
    }
    await supervisor.ready;
    final reply = await supervisor.runBuildCheck(const CcpLatestSource());
    session.log(
      'static data: daily check answered: $reply',
      level: switch (reply) {
        BuildCheckFinished(result: BuildCheckFailed() || BuildStaged()) =>
          LogLevel.warning,
        BuildCheckFinished() => LogLevel.info,
        _ => LogLevel.warning,
      },
    );
  }
}
