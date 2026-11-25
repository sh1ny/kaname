import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../settings/ui/settings_section.dart';
import '../logic/call_log.dart';

/// Displays one page of private receipts or the released admin totals.
final class CallLogPanel extends ConsumerWidget {
  /// Hidden without a verified viewer for the current server.
  const CallLogPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(callLogProvider);
    if (state is CallLogHidden) return const SizedBox.shrink();
    final admin = ref.watch(callLogAccessProvider)?.admin ?? false;
    final actions = ref.read(callLogProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final loading = state is CallLogLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: l10n.esiCallLogTitle,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: loading ? null : () => actions.own(),
                  child: Text(l10n.esiCallLogOwn),
                ),
                if (admin)
                  OutlinedButton(
                    onPressed: loading ? null : actions.totals,
                    child: Text(l10n.esiCallLogTotals),
                  ),
              ],
            ),
            ...switch (state) {
              CallLogHidden() || CallLogIdle() => const <Widget>[],
              CallLogLoading() => const [LinearProgressIndicator()],
              CallLogFailed(:final busy) => [
                Text(busy ? l10n.esiCallLogBusy : l10n.esiCallLogUnavailable),
              ],
              CallLogOwn(:final page) => [
                if (page.rows.isEmpty) Text(l10n.esiCallLogEmpty),
                for (final row in page.rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(row.operation),
                    subtitle: Text(
                      l10n.esiCallLogReceipt(
                        row.recordedAt.toUtc().toIso8601String(),
                        row.outcome,
                      ),
                    ),
                  ),
                if (page.next != null)
                  OutlinedButton(
                    onPressed: () => actions.own(older: true),
                    child: Text(l10n.esiCallLogOlder),
                  ),
              ],
              CallLogTotals(:final page) => [
                if (page.rows.isEmpty) Text(l10n.esiCallLogEmpty),
                for (final row in page.rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(row.operation),
                    subtitle: Text(
                      l10n.esiCallLogRouteCounts(row.total, row.errors),
                    ),
                  ),
              ],
            },
          ],
        ),
        const SizedBox(height: EmberSpace.xl),
      ],
    );
  }
}
