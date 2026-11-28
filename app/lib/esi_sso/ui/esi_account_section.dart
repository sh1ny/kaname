import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kaname_esi/kaname_esi.dart' show EsiRefusalReason;
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../settings/ui/settings_section.dart';
import '../data/account_types.dart';
import '../data/desktop_platform.dart';
import '../logic/account.dart';
import 'member_roster_panel.dart';

/// Connected and solo account actions, with separate dispatch buttons.
final class EsiAccountSection extends ConsumerStatefulWidget {
  /// Adds EVE sign-in and holder controls to Settings.
  const EsiAccountSection({super.key, this.now = DateTime.now});

  /// Supplies the current time when formatting a scheduler deadline.
  final DateTime Function() now;

  @override
  ConsumerState<EsiAccountSection> createState() => _EsiAccountSectionState();
}

final class _EsiAccountSectionState extends ConsumerState<EsiAccountSection> {
  final _clientId = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _clientId.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(accountProvider);
    final account = ref.read(accountProvider.notifier);
    final desktopState = hasDesktopHolder
        ? ref.watch(desktopAccountProvider)
        : null;
    final desktop = desktopState?.value;
    final connection = state.connected;
    final connected = connection?.pilot;
    final local = desktop?.pilot;
    final nativeReady = desktop?.clientId != null;
    final idle = state is AccountIdle;
    final action = state is AccountUnlinkRecovery ? state.desktopAction : state;
    final canUseDesktop = action is AccountIdle;
    final mayReturn =
        local != null &&
        connection != null &&
        connected?.characterId == local.characterId &&
        (const {
              'taking',
              'deviceReserved',
              'solo',
              'returning',
              'joining',
            }.contains(local.holder) ||
            local.holder == 'blocked' &&
                desktop?.ownsReservationFor(
                      connection.origin,
                      local.characterId,
                    ) ==
                    true);
    final serverHolder = switch (connected?.holder) {
      'serverHeld' => l10n.esiServerHolder,
      'deviceReserved' => l10n.esiOriginalHolder,
      'toDevice' => l10n.esiHolderPending,
      'serverReserved' => l10n.esiHolderReserved,
      _ => null,
    };
    final nativeHolder = switch (local?.holder) {
      'solo' => l10n.esiDeviceHolder,
      'taking' || 'returning' || 'joining' => l10n.esiHolderPending,
      'deviceReserved' => l10n.esiHolderReserved,
      _ => null,
    };
    final notice = switch (action) {
      AccountIdle(:final notice) => notice,
      AccountBrowser(:final notice) => notice,
      AccountWorking() || AccountUnlinkRecovery() => AccountNotice.none,
    };
    ref.listen(accountProvider, (before, after) {
      if (after is AccountIdle) _code.clear();
    });
    return SettingsSection(
      title: l10n.esiAccountTitle,
      children: [
        if (connected != null) ...[
          Text(l10n.esiServerPilot(connected.name)),
          if (serverHolder != null) Text(serverHolder),
        ],
        if (state case AccountBrowser(:final attempt)) ...[
          Text(
            attempt.linking
                ? l10n.esiRosterLinkInstruction
                : l10n.esiBrowserInstruction,
          ),
          _buttons([
            FilledButton(
              onPressed: () => _open(attempt.url),
              child: Text(l10n.esiOpenBrowser),
            ),
            TextButton(onPressed: account.cancel, child: Text(l10n.esiCancel)),
          ]),
          if (!kIsWeb)
            TextField(
              controller: _code,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(labelText: l10n.esiCompletionCode),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: () =>
                  account.complete(code: kIsWeb ? null : _code.text.trim()),
              child: Text(
                attempt.linking
                    ? l10n.esiRosterFinishLink
                    : attempt.scoped
                    ? l10n.esiFinishAuthorization
                    : l10n.esiFinishSignIn,
              ),
            ),
          ),
        ] else if (idle && connected == null) ...[
          if (account.canConnect)
            _buttons([
              FilledButton(
                onPressed: account.start,
                child: Text(l10n.esiSignIn),
              ),
            ])
          else
            Text(l10n.esiSecureConnection),
        ] else if (idle && connected != null) ...[
          _buttons([
            FilledButton.tonal(
              onPressed: account.linkCharacter,
              child: Text(l10n.esiRosterLink),
            ),
            FilledButton.tonal(
              onPressed: () => account.start(scoped: true),
              child: Text(l10n.esiAuthorizeServer),
            ),
            OutlinedButton(
              onPressed: () => account.readSkills(solo: false),
              child: Text(l10n.esiReadServerSkills),
            ),
            TextButton(
              onPressed: account.signOut,
              child: Text(l10n.esiSignOut),
            ),
          ]),
          _buttons([
            TextButton(
              onPressed: () => account.optIn(true),
              child: Text(l10n.esiAllowOptional),
            ),
            TextButton(
              onPressed: () => account.optIn(false),
              child: Text(l10n.esiRemoveOptional),
            ),
            if (nativeReady &&
                const {
                  'serverHeld',
                  'toDevice',
                  'deviceReserved',
                }.contains(connected.holder))
              OutlinedButton(
                onPressed: account.takeDesktop,
                child: Text(l10n.esiTakeHolder),
              ),
            if (mayReturn)
              OutlinedButton(
                onPressed: account.returnDesktop,
                child: Text(l10n.esiReturnHolder),
              ),
          ]),
        ],
        if (state case AccountUnlinkRecovery(:final revoking)) ...[
          Semantics(liveRegion: true, child: Text(l10n.esiRosterRecovery)),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: revoking ? null : account.recoverUnlink,
              child: Text(
                revoking ? l10n.esiRosterRevoking : l10n.esiRosterRevoke,
              ),
            ),
          ),
        ],
        if (connected != null) MemberRosterPanel(canEdit: idle),
        if (action case AccountWorking(:final native)) ...[
          const LinearProgressIndicator(),
          if (native)
            _buttons([
              TextButton(
                onPressed: account.cancel,
                child: Text(l10n.esiCancel),
              ),
            ]),
        ],
        if (desktop != null) ...[
          if (local != null) ...[
            Text(l10n.esiNativePilot(local.name)),
            if (nativeHolder != null) Text(nativeHolder),
          ],
          TextField(
            controller: _clientId,
            enabled: canUseDesktop,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.esiNativeRegistration,
              hintText: desktop.clientId,
            ),
          ),
          _buttons([
            OutlinedButton(
              onPressed: canUseDesktop
                  ? () => account.configureDesktop(_clientId.text)
                  : null,
              child: Text(l10n.esiSaveRegistration),
            ),
            if (nativeReady)
              OutlinedButton(
                onPressed: canUseDesktop ? account.identifyDesktop : null,
                child: Text(l10n.esiNativeIdentify),
              ),
            if (nativeReady && local != null) ...[
              FilledButton.tonal(
                onPressed: canUseDesktop ? account.authorizeDesktop : null,
                child: Text(l10n.esiNativeAuthorize),
              ),
              OutlinedButton(
                onPressed: canUseDesktop && local.holder == 'solo'
                    ? () => account.readSkills(solo: true)
                    : null,
                child: Text(l10n.esiReadNativeSkills),
              ),
              if (local.holder == 'solo')
                TextButton(
                  onPressed: canUseDesktop
                      ? account.disableDesktopSkills
                      : null,
                  child: Text(l10n.esiNativeDisable),
                ),
            ],
          ]),
        ] else if (desktopState is AsyncData<DesktopAccount?>)
          Text(l10n.esiNativeUnavailable),
        if (notice != AccountNotice.none)
          Semantics(
            liveRegion: true,
            child: Text(switch (notice) {
              AccountNotice.none => '',
              AccountNotice.unavailable => l10n.esiUnavailable,
              AccountNotice.busy => l10n.esiSkillsBusy,
              AccountNotice.cancelled => l10n.esiCancelled,
              AccountNotice.pending =>
                state is AccountBrowser
                    ? l10n.esiBrowserInstruction
                    : l10n.esiHolderPending,
              AccountNotice.blocked => l10n.esiBlocked,
              AccountNotice.signedOut => l10n.esiSignedOut,
              AccountNotice.reauthorize => l10n.esiReauthorize,
              AccountNotice.takeNotAccepted => l10n.esiTakeNotAccepted,
              AccountNotice.takeUnconfirmed => l10n.esiTakeUnconfirmed,
              AccountNotice.memberLinked => l10n.esiRosterLinked,
              AccountNotice.memberMainRequired => l10n.esiRosterMainRequired,
              AccountNotice.memberRefused => l10n.esiRosterRefused,
            }),
          ),
        if (action case AccountIdle(refusal: final refusal?))
          Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(switch (refusal.reason) {
                  EsiRefusalReason.budget => l10n.esiRefusedBudget,
                  EsiRefusalReason.stopped => l10n.esiRefusedStopped,
                  EsiRefusalReason.queueFull => l10n.esiRefusedQueueFull,
                  EsiRefusalReason.waitExpired => l10n.esiRefusedWaitExpired,
                  EsiRefusalReason.negativeCached =>
                    l10n.esiRefusedNegativeCached,
                  EsiRefusalReason.notDue => l10n.esiRefusedNotDue,
                  EsiRefusalReason.outage => l10n.esiRefusedOutage,
                  EsiRefusalReason.stateUnavailable =>
                    l10n.esiRefusedStateUnavailable,
                  EsiRefusalReason.corpBusy => l10n.esiRefusedCorpBusy,
                  EsiRefusalReason.scopeCapacity =>
                    l10n.esiRefusedScopeCapacity,
                  EsiRefusalReason.routeConflict =>
                    l10n.esiRefusedRouteConflict,
                  EsiRefusalReason.invalidContext =>
                    l10n.esiRefusedInvalidContext,
                  EsiRefusalReason.stateRecovering =>
                    l10n.esiRefusedStateRecovering,
                }),
                if (refusal.retryAt case final retry?)
                  Text(_retryText(context, l10n, retry)),
              ],
            ),
          ),
        if (action case AccountIdle(skills: (:final count, :final totalSp)))
          Semantics(
            liveRegion: true,
            child: Text(l10n.esiSkillsResult(count, totalSp)),
          ),
      ],
    );
  }

  String _retryText(
    BuildContext context,
    AppLocalizations l10n,
    DateTime retry,
  ) {
    if (!retry.isAfter(widget.now())) return l10n.esiRetryNow;
    final local = retry.toLocal();
    final format = MaterialLocalizations.of(context);
    return l10n.esiRetryAfter(
      format.formatShortDate(local),
      (MediaQuery.alwaysUse24HourFormatOf(context)
              ? DateFormat.Hms(l10n.localeName)
              : DateFormat.jms(l10n.localeName))
          .format(local),
    );
  }

  Wrap _buttons(List<Widget> buttons) =>
      Wrap(spacing: 8, runSpacing: 8, children: buttons);

  Future<void> _open(Uri uri) async {
    var opened = false;
    try {
      opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } on Object {
      // Open a fixed notice rather than showing the authorization URL or error.
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).esiUnavailable)),
      );
    }
  }
}
