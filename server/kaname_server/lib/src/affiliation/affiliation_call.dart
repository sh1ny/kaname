import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'affiliation_runtime.dart';

/// Durable Serverpod execution of a boot-scoped sweep or a first-known lookup.
class AffiliationCall extends FutureCall {
  /// Executes a sweep only if this boot still expects its logical slot.
  Future<void> sweep(Session session, AffiliationSweepArgs args) async {
    final result = await AffiliationRuntime.dispatchSweep(session, (
      boot: args.boot,
      slot: args.slot,
    ));
    _logSkip(session, result);
  }

  /// Refreshes an identity that committed before this call was registered.
  Future<void> firstKnown(
    Session session,
    AffiliationFirstKnownArgs args,
  ) async {
    final result = await AffiliationRuntime.dispatchFirstKnown(
      session,
      args.identityId,
    );
    _logSkip(session, result);
  }

  static void _logSkip(Session session, AffiliationDispatch result) {
    if (result == AffiliationDispatch.inactive) {
      session.log('affiliation: no active runtime; skipped queued work');
    } else if (result == AffiliationDispatch.stopped) {
      session.log('affiliation: shutdown interrupted queued work');
    }
  }
}
