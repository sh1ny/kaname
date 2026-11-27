import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaname_client/kaname_client.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../logic/account.dart';
import '../logic/member_roster.dart';

/// Roster controls for the connected ESI Settings section.
final class MemberRosterPanel extends ConsumerWidget {
  /// [canEdit] is false while another account action owns the UI.
  const MemberRosterPanel({required this.canEdit, super.key});

  /// Enables the membership actions, not the read-only roles.
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(memberRosterProvider);
    if (state is MemberRosterHidden) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final page = switch (state) {
      MemberRosterReady(:final page) => page,
      MemberRosterLoading(:final previous) => previous,
      MemberRosterHidden() || MemberRosterFailed() => null,
    };
    final loading = state is MemberRosterLoading;
    final roster = ref.read(memberRosterProvider.notifier);
    final member = ref.read(accountProvider.notifier);
    return Column(
      spacing: EmberSpace.sm,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.esiRosterTitle, style: EmberType.uiHeading),
        ),
        if (page?.main case final main?) ...[
          Text(l10n.esiRosterMain(main.name)),
          Text(l10n.esiRosterMainRequired),
        ],
        if (page?.signing case final signing?)
          Text(l10n.esiRosterSigner(signing.name)),
        if (state case MemberRosterFailed(:final status))
          Semantics(
            liveRegion: true,
            child: Text(switch (status) {
              MemberRosterStatus.denied => l10n.esiSignedOut,
              MemberRosterStatus.busy => l10n.esiRosterBusy,
              MemberRosterStatus.unavailable ||
              MemberRosterStatus.ok => l10n.esiRosterUnavailable,
            }),
          ),
        if (loading) const LinearProgressIndicator(),
        if (page != null)
          for (final character in page.characters)
            _CharacterRow(
              character: character,
              isMain: character.characterId == page.main?.characterId,
              onMain: canEdit && !character.blocked
                  ? () => member.makeMain(character.characterId)
                  : null,
              onUnlink: canEdit
                  ? () => member.unlink(character.characterId)
                  : null,
            ),
        Wrap(
          spacing: EmberSpace.sm,
          runSpacing: EmberSpace.sm,
          children: [
            OutlinedButton(
              onPressed: loading ? null : roster.refresh,
              child: Text(l10n.esiRosterRefresh),
            ),
            if (page?.next != null)
              OutlinedButton(
                onPressed: loading ? null : roster.next,
                child: Text(l10n.esiRosterNext),
              ),
          ],
        ),
      ],
    );
  }
}

final class _CharacterRow extends StatelessWidget {
  const _CharacterRow({
    required this.character,
    required this.isMain,
    required this.onMain,
    required this.onUnlink,
  });

  final MemberCharacter character;
  final bool isMain;
  final VoidCallback? onMain;
  final VoidCallback? onUnlink;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          character.blocked
              ? l10n.esiRosterBlocked(character.name)
              : character.name,
        ),
        if (!isMain)
          Wrap(
            spacing: EmberSpace.sm,
            runSpacing: EmberSpace.sm,
            children: [
              TextButton(
                onPressed: onMain,
                child: Text(l10n.esiRosterMakeMain),
              ),
              TextButton(
                onPressed: onUnlink,
                child: Text(l10n.esiRosterUnlink),
              ),
            ],
          ),
      ],
    );
  }
}
