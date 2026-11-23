import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kaname_client/kaname_client.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../server/data/server_address.dart';
import '../../server/logic/server_status.dart';
import '../../shell/logic/router.dart';
import '../../static_data/logic/server_static_data_status_notifier.dart';
import '../../static_data/logic/static_data_notifier.dart';
import '../../static_data/logic/static_data_state.dart' as local;
import 'settings_keys.dart';
import 'settings_row.dart';
import 'settings_section.dart';
import 'static_data_admin_controls.dart';
import 'static_data_public_reason.dart';

/// Bundle, server status, report link and session controls (design D11).
final class StaticDataSection extends ConsumerWidget {
  /// Creates the Static data panel inside Settings.
  const StaticDataSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final configured = ref.watch(serverTargetProvider) is ConfiguredServer;
    final bundle = ref.watch(staticDataProvider);
    final status = configured
        ? ref.watch(serverStaticDataStatusProvider)
        : null;
    final snapshot = switch (status) {
      StatusShown(:final status) => status,
      _ => null,
    };
    final copy = _StatusCopy(l10n);
    return SettingsSection(
      key: SettingsKeys.staticData,
      title: l10n.sdTitle,
      children: [
        _Group(
          title: l10n.sdAppBundle,
          children: [
            SettingsRow(
              label: l10n.sdInUse,
              value: copy.build(switch (bundle) {
                local.BundleReady(:final identity) => identity.build,
                local.NoBundle() => null,
              }),
            ),
            SettingsRow(
              label: l10n.sdAnnounced,
              value: configured
                  ? copy.build(bundle.announced?.build)
                  : l10n.sdNoServer,
            ),
            if (configured)
              SettingsRow(
                label: l10n.sdConnection,
                value: copy.connection(bundle.connection),
              ),
            SettingsRow(
              label: l10n.sdDownload,
              value: copy.download(bundle.download),
            ),
            SettingsRow(
              label: l10n.sdLastDownload,
              value: copy.last(bundle.lastDownload),
            ),
            if (bundle.download is local.WaitingToRetry)
              _Action(
                label: l10n.sdDownloadNow,
                run: ref.read(staticDataProvider.notifier).downloadNow,
              ),
          ],
        ),
        const Divider(height: 1),
        _Group(
          title: l10n.sdServer,
          children: [
            ...switch (status) {
              null => [Text(l10n.sdNoServer)],
              StatusLoading() => [Text(l10n.sdStatusLoading)],
              StatusUnavailable() => [Text(l10n.sdStatusUnavailable)],
              StatusShown(:final status) => copy.serverRows(status),
            },
            if (configured)
              Wrap(
                spacing: EmberSpace.sm,
                runSpacing: EmberSpace.xs,
                children: [
                  OutlinedButton(
                    onPressed: ref
                        .read(serverStaticDataStatusProvider.notifier)
                        .refresh,
                    child: Text(l10n.sdRefresh),
                  ),
                  TextButton(
                    onPressed: () => context.push(staticDataReportPath),
                    child: Text(l10n.sdOpenReport),
                  ),
                ],
              ),
          ],
        ),
        if (configured) StaticDataAdminControls(status: snapshot),
      ],
    );
  }
}

final class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          style: EmberType.uiHeading.copyWith(
            color: EmberColors.of(context).ink,
          ),
        ),
      ),
      const SizedBox(height: EmberSpace.xs),
      ...children,
    ],
  );
}

final class _Action extends StatelessWidget {
  const _Action({required this.label, required this.run});
  final String label;
  final VoidCallback run;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: OutlinedButton(onPressed: run, child: Text(label)),
  );
}

final class _StatusCopy {
  _StatusCopy(this.l10n);
  final AppLocalizations l10n;

  late final _preciseTime = DateFormat.Hms(l10n.localeName);
  late final _shortTime = DateFormat.Hm(l10n.localeName);
  late final _dateTime = DateFormat.yMMMd(l10n.localeName).add_Hms();

  String build(int? value) => value == null ? l10n.sdNone : l10n.sdBuild(value);
  String at(DateTime value) => _dateTime.format(value.toLocal());

  String connection(local.ConnectionState value) => switch (value) {
    local.AwaitingAnnouncement() => l10n.sdAwaitingServer,
    local.Connected() => l10n.sdConnected,
    local.StreamDown(:final nextReconnect) => l10n.sdStreamDown(
      _preciseTime.format(nextReconnect.toLocal()),
    ),
    local.Reconnecting() => l10n.sdReconnecting,
  };

  String download(local.DownloadState value) => switch (value) {
    local.WaitingForFirstBundle() => l10n.sdAwaitingBundle,
    local.UpToDate() => l10n.sdUpToDate,
    local.DownloadInProgress() => l10n.sdDownloading,
    local.WaitingToRetry(:final nextTry, :final reason) => l10n.sdDownloadWait(
      _preciseTime.format(nextTry.toLocal()),
      failure(reason),
    ),
    local.Stopped(:final reason) => switch (reason) {
      local.DownloadStopReason.noServer => l10n.sdNoServer,
      local.DownloadStopReason.noBundle => l10n.sdServerNoBundle,
      local.DownloadStopReason.appUpdateNeeded => l10n.sdAppUpdate,
    },
  };

  String failure(local.DownloadFailure reason) => switch (reason) {
    local.DownloadFailure.network => l10n.sdNetworkError,
    local.DownloadFailure.server => l10n.sdServerError,
    local.DownloadFailure.refused => l10n.sdRefusedBundle,
  };

  String last(local.LastDownload value) => switch (value) {
    local.NoDownloadYet() => l10n.sdNoneYet,
    local.DownloadSaving(:final build) => l10n.sdSaving(build),
    local.DownloadSucceeded(:final build, :final at) => l10n.sdStored(
      build,
      _shortTime.format(at.toLocal()),
    ),
    local.DownloadNotSaved(:final build) => l10n.sdNotSaved(build),
    local.DownloadFailed(:final build, :final at, :final reason) =>
      l10n.sdDownloadFailed(
        build,
        _shortTime.format(at.toLocal()),
        failure(reason),
      ),
  };

  String reasonText(String text, PublicReason? reason) => reason == null
      ? text
      : l10n.sdWithReason(text, staticDataPublicReason(l10n, reason));

  String check(StaticDataCheckStatus? value) {
    if (value == null) return l10n.sdNoneYet;
    final outcome = switch (value.outcome) {
      SdeCheckOutcome.upToDate => l10n.sdUpToDate,
      SdeCheckOutcome.switched => l10n.sdSwitched,
      SdeCheckOutcome.held => l10n.sdHeld,
      SdeCheckOutcome.older => l10n.sdOlder,
      SdeCheckOutcome.staged => l10n.sdStaged,
      SdeCheckOutcome.failed => l10n.sdFailed,
    };
    return l10n.sdAt(reasonText(outcome, value.reason), at(value.checkedAt));
  }

  String imported(StaticDataImportStatus? value) {
    if (value == null) return l10n.sdNoneYet;
    final outcome = switch (value.outcome) {
      SdeImportOutcome.running => l10n.sdRunning,
      SdeImportOutcome.succeeded => l10n.sdSucceeded,
      SdeImportOutcome.failed => l10n.sdFailed,
      SdeImportOutcome.skipped => l10n.sdSkipped,
    };
    return l10n.sdAt(
      reasonText(outcome, value.reason),
      at(value.finishedAt ?? value.startedAt),
    );
  }

  String switched(StaticDataSwitchStatus? value) {
    if (value == null) return l10n.sdNoneYet;
    final outcome = switch ((value.kind, value.outcome)) {
      (SdeSwitchKind.forward, SdeSwitchOutcome.succeeded) => l10n.sdSwitched,
      (SdeSwitchKind.forward, SdeSwitchOutcome.failed) => l10n.sdSwitchFailed,
      (SdeSwitchKind.rollback, SdeSwitchOutcome.succeeded) => l10n.sdRolledBack,
      (SdeSwitchKind.rollback, SdeSwitchOutcome.failed) =>
        l10n.sdRollbackFailed,
    };
    return l10n.sdAt(
      reasonText(
        l10n.sdTransition(
          outcome,
          build(value.fromBuild),
          build(value.toBuild),
        ),
        value.reason,
      ),
      at(value.at),
    );
  }

  List<Widget> serverRows(StaticDataStatus value) => [
    if (value.workerStuck) Text(l10n.sdWorkerStuck),
    if (value.recoveryStuck) Text(l10n.sdRecoveryStuck),
    if (value.startupStuck) Text(l10n.sdStartupStuck),
    if (value.settlementStuck) Text(l10n.sdSettlementStuck),
    SettingsRow(
      label: l10n.sdWork,
      value: value.busy ? l10n.sdRunning : l10n.sdIdle,
    ),
    SettingsRow(label: l10n.sdActive, value: build(value.activeBuild)),
    SettingsRow(label: l10n.sdPrevious, value: build(value.previousBuild)),
    SettingsRow(
      label: l10n.sdStaged,
      value: switch (value.stagedBuild) {
        final int staged => l10n.sdWaitingToSwitch(staged),
        null => l10n.sdNone,
      },
    ),
    SettingsRow(label: l10n.sdHeld, value: build(value.heldBuild)),
    SettingsRow(
      label: l10n.sdAutoUpdate,
      value: value.autoUpdate ? l10n.sdOn : l10n.sdOff,
    ),
    SettingsRow(
      label: l10n.sdCcpLatest,
      value: switch (value.ccpLatest) {
        StaticDataCcpLatest(build: final latest, :final checkedAt) => l10n.sdAt(
          build(latest),
          at(checkedAt),
        ),
        null => l10n.sdNoneYet,
      },
    ),
    SettingsRow(label: l10n.sdLastCheck, value: check(value.latestCheck)),
    SettingsRow(label: l10n.sdLastImport, value: imported(value.latestImport)),
    if (value.latestImport case StaticDataImportStatus(
      :final fileCounts,
      :final fileCount,
      :final fileCountsCutOff,
    )) ...[
      if (fileCounts != null)
        for (final entry in fileCounts.entries)
          SettingsRow(
            label: entry.key,
            value: NumberFormat.decimalPattern(l10n.localeName)
                .format(entry.value),
          ),
      if (fileCountsCutOff) Text(l10n.sdImportCountsCutOff(fileCount)),
    ],
    SettingsRow(label: l10n.sdLastSwitch, value: switched(value.latestSwitch)),
  ];
}
