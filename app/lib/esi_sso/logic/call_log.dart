import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaname_client/kaname_client.dart';

import '../../server/data/server_address.dart';
import '../../server/logic/server_status.dart';
import '../data/call_log_client.dart';
import 'account.dart';

/// One client for the verified viewer at the current configured server only.
final callLogAccessProvider = Provider<CallLogAccess?>((ref) {
  final session = ref.watch(connectedAccountSessionProvider);
  final server = ref.watch(serverTargetProvider);
  if (session == null || server is! ConfiguredServer) return null;
  final token = session.bearerFor(server.uri);
  if (token == null) return null;
  final client = ClientCallLog(server.uri, token, admin: session.pilot.admin);
  ref.onDispose(client.close);
  return client;
});

/// Current page only; no retained history across sessions or server changes.
sealed class CallLogState {
  const CallLogState();
}

/// No connected viewer.
final class CallLogHidden extends CallLogState {
  const CallLogHidden();
}

/// The viewer has not asked for a page yet.
final class CallLogIdle extends CallLogState {
  const CallLogIdle();
}

/// One currently pending page read.
final class CallLogLoading extends CallLogState {
  const CallLogLoading();
}

/// The private page this viewer asked to see.
final class CallLogOwn extends CallLogState {
  /// Wraps just the displayed page and its next cursor.
  const CallLogOwn(this.page);

  /// Current viewer's page.
  final EsiCallLogPage page;
}

/// A route-only aggregate page for current admins.
final class CallLogTotals extends CallLogState {
  /// Wraps the released window result.
  const CallLogTotals(this.page);

  /// No character or member identifiers.
  final EsiRouteCountPage page;
}

/// A fixed status, with no diagnostic or request data.
final class CallLogFailed extends CallLogState {
  /// [busy] can be retried by the same viewer.
  const CallLogFailed({this.busy = false});

  /// Whether this was an admission refusal.
  final bool busy;
}

/// Controls the current bounded view of the server call log.
final callLogProvider = NotifierProvider<CallLogNotifier, CallLogState>(
  CallLogNotifier.new,
);

/// Discards any response whose source is no longer the connected viewer.
final class CallLogNotifier extends Notifier<CallLogState> {
  CallLogAccess? _source;
  int _epoch = 0;

  @override
  CallLogState build() {
    _epoch++;
    ref.watch(membershipEpochProvider);
    final suspended = ref.watch(membershipReadSuspendedProvider);
    final source = ref.watch(callLogAccessProvider);
    _source = suspended ? null : source;
    return _source == null ? const CallLogHidden() : const CallLogIdle();
  }

  /// Loads the latest or next older page, never both at the same time.
  Future<void> own({bool older = false}) async {
    final source = _source;
    final before = state;
    if (source == null ||
        before is CallLogLoading ||
        ref.read(membershipReadSuspendedProvider)) {
      return;
    }
    final after = older && before is CallLogOwn ? before.page.next : null;
    if (older && after == null) return;
    await _load(source, () async {
      final answer = await source.own(after);
      return answer.status == 'ok'
          ? CallLogOwn(answer)
          : CallLogFailed(busy: answer.status == 'busy');
    });
  }

  /// Requests the fixed-window admin comparison without caller filters.
  Future<void> totals() async {
    final source = _source;
    if (source == null ||
        !source.admin ||
        state is CallLogLoading ||
        ref.read(membershipReadSuspendedProvider)) {
      return;
    }
    await _load(source, () async {
      final answer = await source.totals();
      return answer.status == 'ok'
          ? CallLogTotals(answer)
          : CallLogFailed(busy: answer.status == 'busy');
    });
  }

  Future<void> _load(
    CallLogAccess source,
    Future<CallLogState> Function() load,
  ) async {
    final epoch = ++_epoch;
    final revision = ref.read(membershipEpochProvider);
    state = const CallLogLoading();
    CallLogState result;
    try {
      result = await load();
    } on Object {
      result = const CallLogFailed();
    }
    if (!ref.mounted ||
        epoch != _epoch ||
        revision != ref.read(membershipEpochProvider) ||
        ref.read(membershipReadSuspendedProvider) ||
        !identical(ref.read(callLogAccessProvider), source)) {
      return;
    }
    state = result;
  }
}
