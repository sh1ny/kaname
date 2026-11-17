import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaname_client/kaname_client.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../logic/server_status.dart';
import 'server_keys.dart';

/// The status bar's server indicator: a dot and the status in short form.
///
/// The text always carries the meaning; the dot's colour only repeats it.
/// Reading the status here starts the first health check at app start.
class ServerStatusIndicator extends ConsumerWidget {
  /// Creates the indicator.
  const ServerStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = EmberColors.of(context);
    final (label, dot) = switch (ref.watch(serverStatusProvider)) {
      NotConfigured() => (l10n.serverStatusNotConfigured, colors.inkTertiary),
      InvalidAddress() => (l10n.serverStatusInvalid, colors.errInk),
      Checking() => (l10n.serverStatusChecking, colors.inkTertiary),
      Unreachable() => (l10n.serverStatusUnreachable, colors.errInk),
      Connected(:final report) =>
        report.postgres == DependencyStatus.up &&
                report.redis == DependencyStatus.up
            ? (l10n.serverStatusConnected, colors.ok)
            : (l10n.serverStatusDegraded, colors.warnInk),
    };
    return Flexible(
      child: Row(
        key: ServerKeys.indicator,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              child: const SizedBox.square(dimension: 8),
            ),
          ),
          const SizedBox(width: EmberSpace.sm),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EmberType.label.copyWith(color: colors.inkSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
