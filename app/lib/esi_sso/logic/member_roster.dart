import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaname_client/kaname_client.dart';

import '../data/connected_account.dart';
import '../data/member_account_client.dart';
import 'account.dart';

/// The current connected roster page, never retained across viewer changes.
sealed class MemberRosterState {
  const MemberRosterState();
}

/// No view can be read under the present account state.
final class MemberRosterHidden extends MemberRosterState {
  /// Clears displayed characters and paging controls.
  const MemberRosterHidden();
}

/// One RPC is pending; the previous page stays visible only during paging.
final class MemberRosterLoading extends MemberRosterState {
  /// [previous] is the same viewer's last page, not a stale membership result.
  const MemberRosterLoading(this.previous);

  /// The last page while a next-page read settles.
  final MemberRosterPage? previous;
}

/// The current viewer's bounded page.
final class MemberRosterReady extends MemberRosterState {
  /// [page] holds the main and signer outside the result rows.
  const MemberRosterReady(this.page);

  /// The only page held in memory.
  final MemberRosterPage page;
}

/// A fixed failure allowing a new first-page read.
final class MemberRosterFailed extends MemberRosterState {
  /// [status] contains no server or character details.
  const MemberRosterFailed(this.status);

  /// The reason this page could not load.
  final MemberRosterStatus status;
}

/// Owns the page while connected Settings is visible.
final memberRosterProvider =
    NotifierProvider.autoDispose<MemberRosterNotifier, MemberRosterState>(
      MemberRosterNotifier.new,
    );

/// Fences by membership revision, configured server, and viewer client.
final class MemberRosterNotifier extends Notifier<MemberRosterState> {
  int _revision = 0;
  MemberAccountClient? _client;
  int _epoch = 0;

  @override
  MemberRosterState build() {
    final epoch = ++_epoch;
    final revision = _revision = ref.watch(membershipEpochProvider);
    final suspended = ref.watch(membershipReadSuspendedProvider);
    final client = ref.watch(memberAccountClientProvider);
    _client = suspended ? null : client;
    if (suspended || client == null) return const MemberRosterHidden();
    unawaited(
      Future<void>.microtask(() async {
        if (_current(epoch, revision, client)) {
          await _read(client, epoch, revision, null);
        }
      }),
    );
    return const MemberRosterLoading(null);
  }

  /// Starts again from page one, including after a retryable failure.
  Future<void> refresh() async {
    final client = _client;
    if (client == null || state is MemberRosterLoading) return;
    state = const MemberRosterLoading(null);
    await _read(client, ++_epoch, _revision, null);
  }

  /// Reads the next page without retaining the earlier page after it settles.
  Future<void> next() async {
    final client = _client;
    if (client == null) return;
    if (state case MemberRosterReady(:final page) when page.next != null) {
      state = MemberRosterLoading(page);
      await _read(client, ++_epoch, _revision, page.next);
    }
  }

  Future<void> _read(
    MemberAccountClient client,
    int epoch,
    int revision,
    String? after,
  ) async {
    final result = await client.page(after);
    if (!_current(epoch, revision, client)) return;
    if (result.status == MemberRosterStatus.denied) {
      // Serverpod can deny before the roster runs, including on a temporary
      // bearer lookup failure. Only the viewer route confirms invalidity.
      final viewer = ref.read(connectedAccountSessionProvider);
      if (viewer != null) {
        final check = await viewer.refresh();
        if (!_current(epoch, revision, client)) return;
        if (check is ViewerRefreshInvalid) {
          ref.read(accountProvider.notifier).rejectConnected(viewer);
          return;
        }
      }
      state = const MemberRosterFailed(MemberRosterStatus.unavailable);
      return;
    }
    state = result.status == MemberRosterStatus.ok
        ? MemberRosterReady(result)
        : MemberRosterFailed(result.status);
  }

  bool _current(int epoch, int revision, MemberAccountClient client) =>
      ref.mounted &&
      epoch == _epoch &&
      revision == ref.read(membershipEpochProvider) &&
      identical(ref.read(memberAccountClientProvider), client) &&
      !ref.read(membershipReadSuspendedProvider);
}
