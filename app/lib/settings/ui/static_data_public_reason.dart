import 'package:kaname_client/kaname_client.dart';

import '../../l10n/generated/app_localizations.dart';

/// Localizes only the server's typed public failure reasons (design D15).
String staticDataPublicReason(AppLocalizations l10n, PublicReason reason) =>
    switch (reason) {
      PublicReason.ccpUnreachable => l10n.sdReasonCcp,
      PublicReason.postgresUnreachable => l10n.sdReasonPostgres,
      PublicReason.timedOut => l10n.sdReasonTimeout,
      PublicReason.importAlreadyRunning => l10n.sdReasonImportRunning,
      PublicReason.missingFile => l10n.sdReasonFile,
      PublicReason.comparisonFailed => l10n.sdReasonComparison,
      PublicReason.switchFailed => l10n.sdSwitchFailed,
      PublicReason.workerStopped => l10n.sdReasonWorkerStopped,
      PublicReason.workerNotRunning => l10n.sdReasonWorkerNotRunning,
      PublicReason.serverRestarted => l10n.sdReasonRestart,
      PublicReason.outcomeUnknown => l10n.sdReasonUnknown,
      PublicReason.connectionLost => l10n.sdReasonConnection,
      PublicReason.other => l10n.sdReasonOther,
    };
