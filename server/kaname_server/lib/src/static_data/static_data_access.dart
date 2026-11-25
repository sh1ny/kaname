import 'package:meta/meta.dart';
import 'package:serverpod/serverpod.dart';

import '../esi/server_sso.dart';
import '../generated/protocol.dart';
import '../realtime/server_clock.dart';
import 'admin_admission.dart';
import 'read_work_tokens.dart';
import 'static_data_report_reader.dart';
import 'static_data_runtime.dart';
import 'static_data_start_hook.dart' show WithSession;
import 'static_data_status_cache.dart';
import 'static_data_status_reader.dart';

/// Owns pooled work for one main-isolate Serverpod.
final class StaticDataAccess {
  /// Binds independent pooled sessions to public and admin work.
  StaticDataAccess({
    required this.withSession,
    this.adminConfigured = false,
    this.clock = const SystemClock(),
    StaticDataRuntime? runtime,
  }) : runtime = runtime ?? staticDataRuntime,
       tokens = ReadWorkTokens(clock: clock);

  static final _byPod = Expando<StaticDataAccess>();

  /// Gets the install's shared work, independent of RPC sessions.
  static StaticDataAccess forPod(Serverpod pod) =>
      _byPod[pod] ??= StaticDataAccess(
        withSession: pod.withSession,
        adminConfigured: ServerSso.of(pod)?.sessions.adminConfigured ?? false,
      );

  /// Installs isolated test dependencies before sending any RPC to [pod].
  @visibleForTesting
  static void installForTest(Serverpod pod, StaticDataAccess access) {
    _byPod[pod] = access;
  }

  /// Opens an owner session that stays alive until the work cleans up.
  final WithSession withSession;

  /// Whether the operator configured a running SSO admin allowlist.
  final bool adminConfigured;

  /// Supplies request and snapshot deadlines.
  final ServerClock clock;

  /// Owns the worker, admission recovery and settlement.
  final StaticDataRuntime runtime;

  /// Separate work budgets for public snapshots and admin work (D28).
  final ReadWorkTokens tokens;

  /// Admits one job while preserving idempotent replays across RPC sessions.
  late final admission = AdminAdmission(
    runtime: runtime,
    withSession: withSession,
    tokens: tokens,
    clock: clock,
  );

  /// Shares one admitted report reader across the web route (D23).
  late final report = StaticDataReportReader(
    withSession: withSession,
    tokens: tokens,
    clock: clock,
  );

  /// Shares the status snapshot and its generation across requests (D2, D3).
  late final status = StaticDataStatusCache<StaticDataStatus>(
    tokens: tokens,
    clock: clock,
    read: (beforeStatement) => withSession(
      (session) => const StaticDataStatusReader().read(
        session,
        beforeStatement: beforeStatement,
        adminConfigured: adminConfigured,
        workerStuck:
            (runtime.supervisor?.workerStuck ?? false) ||
            (runtime.settler?.workerStuck ?? false),
        settlementStuck: runtime.settler?.settlementStuck ?? false,
        recoveryStuck: runtime.recovery?.recoveryStuck ?? false,
        startupStuck: runtime.startupStuck,
      ),
    ),
  );
}
