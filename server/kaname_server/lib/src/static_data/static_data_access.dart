import 'package:meta/meta.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../realtime/server_clock.dart';
import 'admin_admission.dart';
import 'admin_gate.dart';
import 'read_work_tokens.dart';
import 'static_data_runtime.dart';
import 'static_data_start.dart';
import 'static_data_start_hook.dart' show WithSession;
import 'static_data_status_cache.dart';
import 'static_data_status_reader.dart';

/// Owns the main-isolate gate and pooled work for one Serverpod.
final class StaticDataAccess {
  /// Binds independent pooled sessions and the install gate to RPC work.
  StaticDataAccess({
    required this.withSession,
    required this.gate,
    this.clock = const SystemClock(),
    StaticDataRuntime? runtime,
  }) : runtime = runtime ?? staticDataRuntime,
       tokens = ReadWorkTokens(clock: clock);

  static final _byPod = Expando<StaticDataAccess>();

  /// Gets the install's gate and shared work, independent of RPC sessions.
  static StaticDataAccess forPod(Serverpod pod) =>
      _byPod[pod] ??= StaticDataAccess(
        withSession: pod.withSession,
        gate: AdminGate(
          key: pod.getPassword('adminKey'),
          log: (level, message) => logStaticData(pod, level, message),
        ),
      );

  /// Installs isolated test dependencies before sending any RPC to [pod].
  @visibleForTesting
  static void installForTest(Serverpod pod, StaticDataAccess access) {
    _byPod[pod] = access;
  }

  /// Opens an owner session that stays alive until the work cleans up.
  final WithSession withSession;

  /// The shared install-wide key and wrong-key window.
  final AdminGate gate;

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

  /// Shares the status snapshot and its generation across requests (D2, D3).
  late final status = StaticDataStatusCache<StaticDataStatus>(
    tokens: tokens,
    clock: clock,
    read: (beforeStatement) => withSession(
      (session) => const StaticDataStatusReader().read(
        session,
        beforeStatement: beforeStatement,
        adminConfigured: gate.configured,
        workerStuck: runtime.settler?.workerStuck ?? false,
        settlementStuck: runtime.settler?.settlementStuck ?? false,
        recoveryStuck: runtime.recovery?.recoveryStuck ?? false,
        startupStuck: false,
      ),
    ),
  );
}
