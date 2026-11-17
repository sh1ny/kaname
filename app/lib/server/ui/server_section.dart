import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaname_client/kaname_client.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../settings/ui/settings_keys.dart';
import '../../settings/ui/settings_row.dart';
import '../../settings/ui/settings_section.dart';
import '../logic/server_status.dart';
import 'server_keys.dart';

/// The Settings → Server section: the full health answer and "Check again".
///
/// Every [ServerStatus] has its own text; none shows exception text, hosts or
/// ports (constraint C7). While a check runs, the previous answer stays on
/// screen and the control shows that it is busy.
class ServerSection extends ConsumerWidget {
  /// Creates the section.
  const ServerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(serverStatusProvider);
    final body = switch (status) {
      NotConfigured() => [_Message(l10n.serverStatusNotConfigured)],
      InvalidAddress() => [_Message(l10n.serverInvalidBody)],
      Connected(:final report) => [
        ..._answer(context, report),
        _checkAgain(ref, l10n, busy: false),
      ],
      Checking(:final previous) => [
        if (previous != null) ..._answer(context, previous.report),
        _checkAgain(ref, l10n, busy: true),
      ],
      Unreachable() => [
        _Message(l10n.serverUnreachableBody),
        _checkAgain(ref, l10n, busy: false),
      ],
    };
    return SettingsSection(
      key: SettingsKeys.server,
      title: l10n.settingsServer,
      children: body,
    );
  }

  List<Widget> _answer(BuildContext context, HealthReport report) {
    final l10n = AppLocalizations.of(context);
    return [
      SettingsRow(
        key: ServerKeys.version,
        label: l10n.serverVersionLabel,
        value: report.version,
      ),
      _dependency(
        context,
        ServerKeys.postgres,
        l10n.serverPostgresLabel,
        report.postgres,
      ),
      _dependency(
        context,
        ServerKeys.redis,
        l10n.serverRedisLabel,
        report.redis,
      ),
    ];
  }

  Widget _dependency(
    BuildContext context,
    Key key,
    String label,
    DependencyStatus status,
  ) {
    final l10n = AppLocalizations.of(context);
    return switch (status) {
      DependencyStatus.up => SettingsRow(
        key: key,
        label: label,
        value: l10n.serverDependencyUp,
      ),
      // Down is text and the theme's error colour, never colour alone.
      DependencyStatus.down => SettingsRow(
        key: key,
        label: label,
        value: l10n.serverDependencyDown,
        valueColor: Theme.of(context).colorScheme.error,
      ),
    };
  }

  Widget _checkAgain(
    WidgetRef ref,
    AppLocalizations l10n, {
    required bool busy,
  }) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: OutlinedButton(
      key: ServerKeys.checkAgain,
      onPressed: busy
          ? null
          : () => unawaited(ref.read(serverStatusProvider.notifier).check()),
      child: Text(busy ? l10n.serverChecking : l10n.serverCheckAgain),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: EmberType.body.copyWith(color: EmberColors.of(context).inkSecondary),
  );
}
