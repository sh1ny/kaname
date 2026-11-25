import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../server/data/server_address.dart';
import '../../server/logic/server_status.dart';
import '../data/account_types.dart';
import '../data/connected_account.dart';
import '../data/desktop_platform.dart';

/// Sign-in and active action states. Secrets remain in the data boundary.
sealed class AccountState {
  const AccountState(this.connected);

  /// The current connected session for this configured server only.
  final ConnectedSession? connected;
}

/// Nothing running; contains the last fixed notice and optional skills result.
final class AccountIdle extends AccountState {
  /// Creates a displayable account state.
  const AccountIdle({
    ConnectedSession? connected,
    this.notice = AccountNotice.none,
    this.skills,
    this.solo = false,
  }) : super(connected);

  /// Fixed action outcome.
  final AccountNotice notice;

  /// Last skills result for the same viewer only.
  final SkillStats? skills;

  /// Whether that result came from the desktop holder.
  final bool solo;
}

/// An app action is running without concurrent credential changes.
final class AccountWorking extends AccountState {
  /// [native] allows the desktop browser attempt to be cancelled.
  const AccountWorking(super.connected, {this.native = false});

  /// A native PKCE attempt can be cancelled.
  final bool native;
}

/// The current app must complete the same CCP attempt with the browser proof.
final class AccountBrowser extends AccountState {
  /// Stores the attempt for this app only.
  const AccountBrowser(
    super.connected,
    this.attempt, {
    this.notice = AccountNotice.none,
  });

  /// Read-only URL and private proof kept by the data boundary.
  final ConnectedAttempt attempt;

  /// Fixed outcome from attempting to complete early.
  final AccountNotice notice;
}

/// One in-memory session and sign-in flow per app instance.
final accountProvider = NotifierProvider<AccountNotifier, AccountState>(
  AccountNotifier.new,
);

/// One credential runtime per desktop process, independent of server target.
final desktopAccountProvider = FutureProvider<DesktopAccount?>((ref) async {
  final desktop = await openDesktopHolder();
  if (!ref.mounted) {
    await desktop?.close();
    return null;
  }
  if (desktop != null) ref.onDispose(() => unawaited(desktop.close()));
  return desktop;
});

/// Localized Settings and scoped views use the same verified session instance.
final connectedAccountSessionProvider = Provider<ConnectedSession?>(
  (ref) => ref.watch(accountProvider.select((state) => state.connected)),
);

/// Owns viewer epochs across sign-out, changing servers and delayed reads.
final class AccountNotifier extends Notifier<AccountState> {
  ConnectedAccount? _api;
  int _epoch = 0;
  DateTime? _nextComplete;

  @override
  AccountState build() {
    _epoch++;
    _api = null;
    _nextComplete = null;
    if (ref.watch(serverTargetProvider) case ConfiguredServer(:final uri)) {
      if (!kIsWeb || Uri.base.origin == uri.origin) {
        final client = http.Client();
        ref.onDispose(client.close);
        _api = ConnectedAccount(uri, client, native: !kIsWeb);
      }
    }
    return const AccountIdle();
  }

  /// Whether connected auth may send credentials to the configured origin.
  bool get canConnect => _api?.secure ?? false;

  /// Starts identity sign-in or requests the scopes for the existing viewer.
  Future<void> start({bool scoped = false}) async {
    if (state is AccountWorking || state is AccountBrowser) return;
    final connected = state.connected;
    final api = _api;
    if (api == null || !api.secure || scoped && connected == null) {
      state = AccountIdle(
        connected: connected,
        notice: AccountNotice.unavailable,
      );
      return;
    }
    if (scoped &&
        connected != null &&
        hasDesktopHolder &&
        !(ref
                .read(desktopAccountProvider)
                .value
                ?.permitsServerGrant(connected.pilot.characterId) ??
            false)) {
      state = AccountIdle(connected: connected, notice: AccountNotice.blocked);
      return;
    }
    final epoch = ++_epoch;
    state = AccountWorking(connected);
    final (notice, attempt) = await api.start(
      session: scoped ? connected : null,
    );
    if (!_current(epoch)) return;
    _nextComplete = null;
    state = attempt == null
        ? AccountIdle(connected: connected, notice: notice)
        : AccountBrowser(connected, attempt);
  }

  /// Completes the active browser attempt. Early requests never start a poll loop.
  Future<void> complete({String? code}) async {
    final before = state;
    final api = _api;
    if (before is! AccountBrowser || api == null) return;
    final next = _nextComplete;
    if (next != null && DateTime.now().isBefore(next)) return;
    final epoch = ++_epoch;
    state = AccountWorking(before.connected);
    final (notice, updated) = await api.complete(
      before.attempt,
      code: code,
      session: before.connected,
    );
    if (!_current(epoch)) return;
    _nextComplete = DateTime.now().add(const Duration(seconds: 2));
    state = switch (notice) {
      AccountNotice.pending => AccountBrowser(
        before.connected,
        before.attempt,
        notice: notice,
      ),
      AccountNotice.signedOut => const AccountIdle(
        notice: AccountNotice.signedOut,
      ),
      _ => AccountIdle(connected: updated ?? before.connected, notice: notice),
    };
  }

  /// Releases this app's browser attempt or asks the native listener to stop.
  void cancel() {
    if (state is AccountBrowser) {
      _epoch++;
      state = AccountIdle(
        connected: state.connected,
        notice: AccountNotice.cancelled,
      );
    } else if (state case AccountWorking(native: true)) {
      ref.read(desktopAccountProvider).value?.cancel();
    }
  }

  /// Drops authority immediately, then attempts to revoke the old server session.
  Future<void> signOut() async {
    _epoch++;
    final former = state.connected;
    ref.read(desktopAccountProvider).value?.cancel();
    state = const AccountIdle();
    await former?.signOut();
  }

  /// Removes only the session that actually failed, not a newer viewer.
  void rejectConnected(ConnectedSession captured) {
    if (identical(state.connected, captured)) {
      _epoch++;
      state = const AccountIdle(notice: AccountNotice.signedOut);
    }
  }

  /// Records explicit optional consent for this verified connected viewer.
  Future<void> optIn(bool enabled) async {
    final session = state.connected;
    if (session == null || state is! AccountIdle) return;
    final epoch = ++_epoch;
    state = AccountWorking(session);
    final notice = await session.optIn(enabled);
    if (!_current(epoch)) return;
    state = AccountIdle(
      connected: notice == AccountNotice.signedOut ? null : session,
      notice: notice,
    );
  }

  /// Reads skills from the mode the user explicitly selected.
  Future<void> readSkills({required bool solo}) async {
    if (state is! AccountIdle) return;
    final connected = state.connected;
    final epoch = ++_epoch;
    state = AccountWorking(connected);
    final (notice, stats) = solo
        ? await ref.read(desktopAccountProvider).value?.skills() ??
              (AccountNotice.unavailable, null)
        : await connected?.skills() ?? (AccountNotice.signedOut, null);
    if (!_current(epoch)) return;
    state = AccountIdle(
      connected: notice == AccountNotice.signedOut ? null : connected,
      notice: stats == null && notice == AccountNotice.none
          ? AccountNotice.unavailable
          : notice,
      skills: stats,
      solo: solo,
    );
  }

  /// Configures the public desktop client without contacting a server.
  void configureDesktop(String value) {
    if (state is! AccountIdle) return;
    final desktop = ref.read(desktopAccountProvider).value;
    final notice =
        desktop?.configure(value.trim()) ?? AccountNotice.unavailable;
    state = AccountIdle(connected: state.connected, notice: notice);
  }

  /// Identifies a desktop character without requesting skills scope.
  Future<void> identifyDesktop() =>
      _desktop((account, _) => account.identify());

  /// Records native consent, then runs a separate PKCE authorization.
  Future<void> authorizeDesktop() => _desktop((account, session) async {
    final pilot = account.pilot;
    if (pilot != null &&
        session != null &&
        pilot.characterId == session.pilot.characterId &&
        session.pilot.holder != null &&
        !account.ownsReservationFor(session.origin, pilot.characterId)) {
      return AccountNotice.blocked;
    }
    return account.authorizeSkills();
  });

  /// Revokes local scope without handing a linked character to another holder.
  Future<void> disableDesktopSkills() =>
      _desktop((account, _) => account.disableSkills());

  /// Reserves the current connected viewer to the original desktop.
  Future<void> takeDesktop() => _desktop(
    (account, session) => session == null
        ? Future.value(AccountNotice.signedOut)
        : account.take(session),
    refresh: true,
  );

  /// Parks the desktop and requests a return to the current connected server.
  Future<void> returnDesktop() => _desktop(
    (account, session) => session == null
        ? Future.value(AccountNotice.signedOut)
        : account.returnTo(session),
    refresh: true,
  );

  Future<void> _desktop(
    Future<AccountNotice> Function(DesktopAccount, ConnectedSession?) action, {
    bool refresh = false,
  }) async {
    if (state is! AccountIdle) return;
    final connected = state.connected;
    final desktop = ref.read(desktopAccountProvider).value;
    if (desktop == null) {
      state = AccountIdle(
        connected: connected,
        notice: AccountNotice.unavailable,
      );
      return;
    }
    final epoch = ++_epoch;
    state = AccountWorking(connected, native: true);
    final notice = await action(desktop, connected);
    if (!_current(epoch)) return;
    final updated = refresh ? await connected?.refresh() : connected;
    if (!_current(epoch)) return;
    state = AccountIdle(connected: updated, notice: notice);
  }

  bool _current(int epoch) => ref.mounted && epoch == _epoch;
}
