import 'dart:async';

import 'affiliation/affiliation_runtime.dart';
import 'affiliation/org_tree_config.dart';
import 'generated/serverpod.dart';

/// Adds the install tree and affiliation lifecycle to the generated Serverpod.
final class KanameServerpod extends Serverpod {
  /// Parses the operator's tree before Serverpod configures any listeners.
  KanameServerpod(
    super.args, {
    required Map<String, String> environment,
    super.authenticationHandler,
    super.configOverride,
  }) : orgTree = readOrgTree(environment);

  /// The server-only tree declaration, including an explicit unconfigured state.
  final OrgTree orgTree;
  Future<void>? _shutdown;

  @override
  Future<void> start({bool runInGuardedZone = true}) async {
    await super.start(runInGuardedZone: runInGuardedZone);
    unawaited(AffiliationRuntime.of(this)?.start());
  }

  @override
  Future<void> shutdown({bool exitProcess = true, int? signalNumber}) {
    AffiliationRuntime.of(this)?.stop();
    return _shutdown ??= super.shutdown(
      exitProcess: exitProcess,
      signalNumber: signalNumber,
    );
  }
}
