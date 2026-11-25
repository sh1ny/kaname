import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaname_client/kaname_client.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../static_data/logic/admin_session_notifier.dart';
import '../../static_data/logic/admin_session_state.dart';
import 'static_data_public_reason.dart';

/// Session-only administration of the server's static data.
class StaticDataAdminControls extends ConsumerStatefulWidget {
  /// Creates controls for the currently displayed status snapshot.
  const StaticDataAdminControls({required this.status, super.key});

  /// The displayed server snapshot, or `null` when none is available.
  final StaticDataStatus? status;

  @override
  ConsumerState<StaticDataAdminControls> createState() =>
      _StaticDataAdminControlsState();
}

class _StaticDataAdminControlsState
    extends ConsumerState<StaticDataAdminControls> {
  Future<void> _confirmRollback(int active, int previous, int revision) async {
    final authority = ref.read(adminSessionProvider).view.authority;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sdAdminRollbackTitle),
        content: Text(l10n.sdAdminRollbackQuestion(previous, active)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.sdAdminCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.sdAdminRollback),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        mounted &&
        authority != null &&
        ref.read(adminSessionProvider).view.authority == authority) {
      ref.read(adminSessionProvider.notifier).rollBack(revision);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(adminSessionProvider);
    final view = state.view;
    final controller = ref.read(adminSessionProvider.notifier);
    final status = widget.status;
    final setting = view.setting;
    final children = <Widget>[];
    if (view.message case final message?) {
      children.add(
        Semantics(liveRegion: true, child: Text(_message(l10n, message))),
      );
    }
    if (view.job case final job?) {
      children.add(Text(l10n.sdAdminWaiting));
      if (job.noRecord) children.add(Text(l10n.sdAdminNoRecord));
      if (job.canRetry && job.following && !job.sending) {
        children.add(
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: controller.retryJob,
              child: Text(l10n.sdAdminRetryJob),
            ),
          ),
        );
      }
    }
    if (setting != null && state is! Admin) {
      if (setting.saving) children.add(Text(l10n.sdAdminSaving));
      if (setting.notConfirmed) {
        children.add(Text(l10n.sdAdminSettingUnconfirmed));
      }
      if (setting.notice case final notice?) {
        children.add(Text(_answer(l10n, notice)));
      }
    }
    if (!view.secure) {
      children.add(Text(l10n.sdAdminSecureRequired));
    } else if (view.configured == false) {
      children.add(Text(l10n.sdAdminNotConfigured));
    } else if (view.configured == true && state is! Admin) {
      children.add(Text(l10n.sdAdminSignIn));
    } else if (state is Admin) {
      if (setting != null) {
        children.add(
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.sdAdminAutoUpdate),
              value: setting.value,
              onChanged: setting.saving || setting.notConfirmed
                  ? null
                  : controller.setAutoUpdate,
            ),
          ),
        );
        if (setting.saving) children.add(Text(l10n.sdAdminSaving));
        if (setting.notConfirmed) {
          children.add(Text(l10n.sdAdminSettingUnconfirmed));
        }
        if (setting.notice case final notice?) {
          children.add(Text(_answer(l10n, notice)));
        }
        if (setting.canRetry) {
          children.add(
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: controller.retryAutoUpdate,
                child: Text(l10n.sdAdminRetrySetting),
              ),
            ),
          );
        }
      }
      if (view.job == null && !view.serverBusy && status != null) {
        children.add(
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: controller.updateNow,
              child: Text(l10n.sdAdminUpdate),
            ),
          ),
        );
        if (status case StaticDataStatus(
          activeBuild: final active?,
          previousBuild: final previous?,
          :final buildRevision,
        )) {
          children.add(
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () =>
                    _confirmRollback(active, previous, buildRevision),
                child: Text(l10n.sdAdminRollback),
              ),
            ),
          );
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: EmberSpace.sm,
      children: children,
    );
  }
}

String _message(AppLocalizations l10n, AdminJobMessage message) {
  switch (message) {
    case AdminJobSending():
      return l10n.sdAdminSending;
    case AdminJobUnknown():
      return l10n.sdAdminUnknown;
    case AdminJobAnswered(:final answer):
      final text = _answer(l10n, answer.outcome);
      return answer.reason == null
          ? text
          : '$text ${staticDataPublicReason(l10n, answer.reason!)}';
    case AdminJobEnded(:final operation):
      final text = switch (operation.outcome) {
        SdeAdminOperationOutcome.switched => l10n.sdAdminSwitched,
        SdeAdminOperationOutcome.upToDate => l10n.sdAdminUpToDate,
        SdeAdminOperationOutcome.held => l10n.sdAdminHeld,
        SdeAdminOperationOutcome.older => l10n.sdAdminOlder,
        SdeAdminOperationOutcome.staged => l10n.sdAdminStaged,
        SdeAdminOperationOutcome.failed => l10n.sdAdminUpdateFailed,
        SdeAdminOperationOutcome.buildsChanged => l10n.sdAdminBuildsChanged,
        SdeAdminOperationOutcome.noPrevious => l10n.sdAdminNoPrevious,
        SdeAdminOperationOutcome.importRunning => l10n.sdAdminImportRunning,
        SdeAdminOperationOutcome.rolledBack => l10n.sdAdminRolledBack,
        SdeAdminOperationOutcome.rollbackFailed => l10n.sdAdminRollbackFailed,
      };
      return operation.reason == null
          ? text
          : '$text ${staticDataPublicReason(l10n, operation.reason!)}';
  }
}

String _answer(AppLocalizations l10n, AdminAnswerOutcome outcome) =>
    switch (outcome) {
      AdminAnswerOutcome.notAuthorized => l10n.sdAdminSignIn,
      AdminAnswerOutcome.started => l10n.sdAdminStarted,
      AdminAnswerOutcome.noAnswerYet => l10n.sdAdminWatching,
      AdminAnswerOutcome.outcomeUnknown => l10n.sdAdminOutcomeUnknownWatching,
      AdminAnswerOutcome.ended => l10n.sdAdminEnded,
      AdminAnswerOutcome.importRunning => l10n.sdAdminImportRunning,
      AdminAnswerOutcome.workerNotRunning => l10n.sdAdminWorkerDown,
      AdminAnswerOutcome.updateFailed => l10n.sdAdminUpdateFailed,
      AdminAnswerOutcome.rollbackFailed => l10n.sdAdminRollbackFailed,
      AdminAnswerOutcome.buildsChanged => l10n.sdAdminBuildsChanged,
      AdminAnswerOutcome.noPrevious => l10n.sdAdminNoPrevious,
      AdminAnswerOutcome.rolledBack => l10n.sdAdminRolledBack,
      AdminAnswerOutcome.adminBusy => l10n.sdAdminBusy,
      AdminAnswerOutcome.malformed => l10n.sdAdminMalformed,
      AdminAnswerOutcome.settingConfirmed => l10n.sdAdminSettingConfirmed,
      AdminAnswerOutcome.settingChanged => l10n.sdAdminSettingChanged,
      AdminAnswerOutcome.settingNotSaved => l10n.sdAdminSettingNotSaved,
      AdminAnswerOutcome.settingNotConfirmed => l10n.sdAdminSettingUnconfirmed,
    };
