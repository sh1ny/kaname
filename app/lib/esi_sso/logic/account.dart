import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:kaname_client/kaname_client.dart';

import '../../server/data/server_address.dart';
import '../../server/logic/server_status.dart';
import '../data/account_types.dart';
import '../data/connected_account.dart';
import '../data/desktop_platform.dart';
import '../data/member_account_client.dart';

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
    this.refusal,
    this.solo = false,
  }) : super(connected);

  /// Fixed action outcome.
  final AccountNotice notice;

  /// Last skills result for the same viewer only.
  final SkillStats? skills;

  /// Last refusal for the same viewer and mode, if a scheduler declined.
  final SkillsRefusal? refusal;

  /// Whether that result came from the desktop holder.
  final bool solo;
}

/// An app action is running without concurrent credential changes.
final class AccountWorking extends AccountState {
  /// [native] allows the desktop browser attempt to be cancelled.
  const AccountWorking(
    super.connected, {
    this.native = false,
    this.membershipWrite = false,
  });

  /// A native PKCE attempt can be cancelled.
  final bool native;

  /// Connected membership views stay suspended until this mutation settles.
  final bool membershipWrite;
}

/// The previous unlink may have committed. Only exact revocation can leave
/// this state; [AccountState.connected] never exposes the former session.
final class AccountUnlinkRecovery extends AccountState {
  const AccountUnlinkRecovery._(this._former, {this.revoking = false})
    : super(null);

  final ConnectedSession _former;

  /// Prevents concurrent revocation requests for the same session.
  final bool revoking;
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

/// A read fence shared by connected roster and history, not by solo views.
final membershipReadSuspendedProvider = Provider<bool>(
  (ref) => ref.watch(
    accountProvider.select(
      (state) =>
          state is AccountWorking && state.membershipWrite ||
          state is AccountUnlinkRecovery,
    ),
  ),
);

/// Changes after a confirmed membership result without changing the bearer.
final membershipEpochProvider = NotifierProvider<MembershipEpoch, int>(
  MembershipEpoch.new,
);

/// Issues an in-memory invalidation epoch, never holding any account data.
final class MembershipEpoch extends Notifier<int> {
  @override
  int build() => 0;

  /// Fences all in-flight roster and history replies from earlier epochs.
  void advance() => state++;
}

/// One generated client for the current connected viewer and configured origin.
final memberAccountClientProvider = Provider.autoDispose<MemberAccountClient?>((
  ref,
) {
  final session = ref.watch(connectedAccountSessionProvider);
  final target = ref.watch(serverTargetProvider);
  if (session == null || target is! ConfiguredServer) return null;
  final bearer = session.bearerFor(target.uri);
  if (bearer == null) return null;
  final client = MemberAccountClient(target.uri, bearer);
  ref.onDispose(client.close);
  return client;
});

/// Owns viewer epochs across sign-out, changing servers and delayed reads.
final class AccountNotifier extends Notifier<AccountState> {
  ConnectedAccount? _api;
  ServerTarget? _target;
  int _epoch = 0;
  DateTime? _nextComplete;

  @override
  AccountState build() {
    _epoch++;
    _api = null;
    _nextComplete = null;
    final target = _target = ref.watch(serverTargetProvider);
    if (target case ConfiguredServer(:final uri)) {
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
  Future<void> start({bool scoped = false}) =>
      _start(scoped: scoped, link: false);

  /// Starts a separate identity-only browser attempt for an alt.
  Future<void> linkCharacter() => _start(scoped: false, link: true);

  Future<void> _start({required bool scoped, required bool link}) async {
    if (state is! AccountIdle) return;
    final connected = state.connected;
    final api = _api;
    if (api == null || !api.secure || (scoped || link) && connected == null) {
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
      session: scoped || link ? connected : null,
      link: link,
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
    if (notice == AccountNotice.memberLinked) {
      ref.read(membershipEpochProvider.notifier).advance();
    }
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

  /// Changes the designated main without changing the connected bearer.
  Future<void> makeMain(String character) =>
      _changeMember(character, unlink: false);

  /// Invalidates membership-scoped views before sending and on completion.
  Future<void> unlink(String character) =>
      _changeMember(character, unlink: true);

  Future<void> _changeMember(String character, {required bool unlink}) async {
    final before = state;
    final session = before.connected;
    final target = _target;
    if (before is! AccountIdle ||
        session == null ||
        target is! ConfiguredServer) {
      return;
    }
    final bearer = session.bearerFor(target.uri);
    if (bearer == null) return;
    final epoch = ++_epoch;
    state = AccountWorking(session, membershipWrite: true);
    final source = MemberAccountClient(target.uri, bearer);
    final MemberAccountStatus result;
    try {
      result = await (unlink
          ? source.unlink(character)
          : source.makeMain(character));
    } finally {
      source.close();
    }
    if (!_current(epoch)) return;
    ref.read(membershipEpochProvider.notifier).advance();
    state = switch (result) {
      MemberAccountStatus.mainChanged ||
      MemberAccountStatus.unlinked => AccountIdle(connected: session),
      MemberAccountStatus.selfUnlinked || MemberAccountStatus.denied =>
        const AccountIdle(notice: AccountNotice.signedOut),
      MemberAccountStatus.mainRequired => AccountIdle(
        connected: session,
        notice: AccountNotice.memberMainRequired,
      ),
      MemberAccountStatus.refused => AccountIdle(
        connected: session,
        notice: AccountNotice.memberRefused,
      ),
      MemberAccountStatus.unavailable when unlink => AccountUnlinkRecovery._(
        session,
      ),
      MemberAccountStatus.unavailable => AccountIdle(
        connected: session,
        notice: AccountNotice.unavailable,
      ),
    };
  }

  /// Uses the original bearer only for definitive revocation, never to read
  /// the roster or history, and does not resend the unlink.
  Future<void> recoverUnlink() async {
    final before = state;
    if (before is! AccountUnlinkRecovery || before.revoking) return;
    final epoch = ++_epoch;
    state = AccountUnlinkRecovery._(before._former, revoking: true);
    final revoked = await before._former.revoke();
    if (!_current(epoch)) return;
    state = revoked
        ? const AccountIdle(notice: AccountNotice.signedOut)
        : before;
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
    if (state
        case AccountUnlinkRecovery() || AccountWorking(membershipWrite: true)) {
      return;
    }
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
    final (notice, stats, refusal) = solo
        ? await ref.read(desktopAccountProvider).value?.skills() ??
              (AccountNotice.unavailable, null, null)
        : await connected?.skills() ?? (AccountNotice.signedOut, null, null);
    if (!_current(epoch)) return;
    state = AccountIdle(
      connected: notice == AccountNotice.signedOut ? null : connected,
      notice: stats == null && refusal == null && notice == AccountNotice.none
          ? AccountNotice.unavailable
          : notice,
      skills: stats,
      refusal: refusal,
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
    if (!refresh || connected == null) {
      state = AccountIdle(connected: connected, notice: notice);
      return;
    }
    final updated = await connected.refresh();
    if (!_current(epoch)) return;
    final handoffNotice = notice == AccountNotice.signedOut
        ? AccountNotice.unavailable
        : notice;
    state = switch (updated) {
      ViewerRefreshUpdated(:final session) => AccountIdle(
        connected: session,
        notice: handoffNotice,
      ),
      ViewerRefreshInvalid() => const AccountIdle(
        notice: AccountNotice.signedOut,
      ),
      ViewerRefreshUnavailable() => AccountIdle(
        connected: connected,
        notice: handoffNotice,
      ),
    };
  }

  bool _current(int epoch) =>
      ref.mounted &&
      epoch == _epoch &&
      identical(_target, ref.read(serverTargetProvider));
}
