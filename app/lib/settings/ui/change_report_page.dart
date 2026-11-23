import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kaname_client/kaname_client.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../static_data/data/report_client.dart';
import '../logic/change_report_source.dart';
import 'settings_row.dart';
import 'settings_section.dart';
import 'static_data_public_reason.dart';

/// Displays the server's bounded comparison of its active and previous builds.
class ChangeReportPage extends ConsumerStatefulWidget {
  /// Creates the change report page.
  const ChangeReportPage({super.key});

  @override
  ConsumerState<ChangeReportPage> createState() => _ChangeReportPageState();
}

class _ChangeReportPageState extends ConsumerState<ChangeReportPage> {
  ReportRead? _result;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    setState(() => _result = null);
    final client = ref.read(changeReportClientProvider);
    ReportRead result;
    try {
      result = client == null ? const ReportUnavailable() : await client.read();
    } on Object {
      result = const ReportUnavailable();
    }
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = EmberColors.of(context);
    final result = _result;
    final report = result is ReportReceived ? result.report : null;
    final unavailable =
        result is ReportUnavailable ||
        report?.outcome == StaticDataReportOutcome.reportBusy ||
        (report?.outcome == StaticDataReportOutcome.reportReady &&
            (report?.fromBuild == null ||
                report?.toBuild == null ||
                report?.files == null));
    final files = report?.files;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth < 600
            ? EmberSpace.lg
            : EmberSpace.xxl;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, 44, side, EmberSpace.xxl),
              sliver: SliverConstrainedCrossAxis(
                maxExtent: 640,
                sliver: SliverList.list(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/settings');
                          }
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: Text(l10n.sdReportBack),
                      ),
                    ),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.sdReportTitle,
                        style: EmberType.headline.copyWith(color: colors.ink),
                      ),
                    ),
                    const SizedBox(height: EmberSpace.xl),
                    if (result == null)
                      Text(l10n.sdReportLoading)
                    else if (unavailable)
                      SettingsSection(
                        title: l10n.sdReportUnavailable,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _read,
                              child: Text(l10n.sdReportRetry),
                            ),
                          ),
                        ],
                      )
                    else if (report != null &&
                        report.outcome != StaticDataReportOutcome.reportReady)
                      SettingsSection(
                        title: l10n.sdReportTitle,
                        children: [
                          Text(switch (report.outcome) {
                            StaticDataReportOutcome.noPreviousBuild =>
                              l10n.sdReportNoPrevious,
                            StaticDataReportOutcome.reportMissing =>
                              l10n.sdReportMissing,
                            StaticDataReportOutcome.comparisonFailed =>
                              l10n.sdReportComparisonFailed,
                            StaticDataReportOutcome.reportTooLarge =>
                              l10n.sdReportTooLarge,
                            StaticDataReportOutcome.reportReady ||
                            StaticDataReportOutcome.reportBusy =>
                              l10n.sdReportUnavailable,
                          }),
                          if (report.outcome ==
                                  StaticDataReportOutcome.comparisonFailed &&
                              report.reason != null)
                            Text(staticDataPublicReason(l10n, report.reason!)),
                        ],
                      )
                    else if (report != null) ...[
                      SettingsSection(
                        title: l10n.sdReportBuilds,
                        children: [
                          SettingsRow(
                            label: l10n.sdReportFromBuild,
                            value: '${report.fromBuild}',
                          ),
                          SettingsRow(
                            label: l10n.sdReportToBuild,
                            value: '${report.toBuild}',
                          ),
                        ],
                      ),
                      if (files != null && files.isEmpty) ...[
                        const SizedBox(height: EmberSpace.xl),
                        Text(l10n.sdReportNoFiles),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            if (!unavailable &&
                report?.outcome == StaticDataReportOutcome.reportReady &&
                files != null)
              for (final file in files) ..._fileSlivers(context, file, side),
          ],
        );
      },
    );
  }

  List<Widget> _fileSlivers(
    BuildContext context,
    StaticDataReportFile file,
    double side,
  ) {
    final l10n = AppLocalizations.of(context);
    final colors = EmberColors.of(context);
    Widget wrap(Widget sliver) => SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: side),
      sliver: SliverConstrainedCrossAxis(maxExtent: 640, sliver: sliver),
    );
    final fields = file.changedFields.entries.toList(growable: false);
    return [
      wrap(
        SliverList.list(
          children: [
            SettingsSection(
              title: file.file,
              children: [
                SettingsRow(
                  label: l10n.sdReportFileType,
                  value: switch (file.status) {
                    StaticDataReportFileStatus.both => l10n.sdReportFileBoth,
                    StaticDataReportFileStatus.newFile => l10n.sdReportFileNew,
                    StaticDataReportFileStatus.removedFile =>
                      l10n.sdReportFileRemoved,
                  },
                ),
                SettingsRow(
                  label: l10n.sdReportAdded,
                  value: '${file.added.count}',
                ),
                SettingsRow(
                  label: l10n.sdReportRemoved,
                  value: '${file.removed.count}',
                ),
                SettingsRow(
                  label: l10n.sdReportChanged,
                  value: '${file.changed.count}',
                ),
                SettingsRow(
                  label: l10n.sdReportFields,
                  value: '${file.changedFieldCount}',
                ),
                if (file.changedFieldsCutOff) Text(l10n.sdReportCutOff),
              ],
            ),
            if (fields.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: EmberSpace.lg),
                child: Text(
                  l10n.sdReportFields,
                  style: EmberType.uiHeading.copyWith(color: colors.ink),
                ),
              ),
          ],
        ),
      ),
      if (fields.isNotEmpty)
        wrap(
          SliverList.builder(
            itemCount: fields.length,
            itemBuilder: (context, index) {
              final field = fields[index];
              return SettingsRow(label: field.key, value: '${field.value}');
            },
          ),
        ),
      for (final (title, changes) in [
        (l10n.sdReportAdded, file.added),
        (l10n.sdReportRemoved, file.removed),
        (l10n.sdReportChanged, file.changed),
      ]) ...[
        wrap(
          SliverList.list(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: EmberSpace.lg),
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.sdReportKeys(title, changes.count),
                    style: EmberType.uiHeading.copyWith(color: colors.ink),
                  ),
                ),
              ),
              if (changes.cutOff) Text(l10n.sdReportCutOff),
              if (changes.keys.isEmpty) Text(l10n.sdReportNoKeys),
            ],
          ),
        ),
        if (changes.keys.isNotEmpty)
          wrap(
            SliverList.builder(
              itemCount: changes.keys.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: EmberSpace.xs),
                child: Text(
                  changes.keys[index],
                  style: EmberType.body.copyWith(color: colors.ink),
                ),
              ),
            ),
          ),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: EmberSpace.xxl)),
    ];
  }
}
