import 'package:serverpod/serverpod.dart';

import 'esi_call_log_store.dart';

/// Deletes expired receipts in bounded batches, independently of ESI calls.
class EsiCallLogPruneCall extends FutureCall {
  /// Sweeps old rows without overlapping another local sweep.
  Future<void> run(Session session) async {
    if (_pruning) return;
    _pruning = true;
    try {
      final store = EsiCallLogStore();
      for (var batch = 0; batch < 20; batch++) {
        if (await store.prune(session) < 1000) break;
      }
    } on EsiCallLogUnavailable {
      session.log('esi-call-log: prune failed', level: LogLevel.warning);
    } finally {
      _pruning = false;
    }
  }
}

bool _pruning = false;
