import '../generated/static_data/public_reason.dart';

/// Maps stored failure text to the closed public vocabulary (D15, C2).
///
/// Matches a fixed label or its colon-delimited details, never arbitrary
/// substrings. The original text remains in the record and server log.
PublicReason? publicReasonOf(String? stored) {
  if (stored == null) return null;
  final details = stored.indexOf(':');
  final label = details < 0 ? stored : stored.substring(0, details);
  return switch (label) {
    'CCP unreachable' => PublicReason.ccpUnreachable,
    'Postgres unreachable' => PublicReason.postgresUnreachable,
    'timed out' => PublicReason.timedOut,
    'import running' ||
    'import already running' => PublicReason.importAlreadyRunning,
    'missing file' ||
    'missing required file' ||
    'missing required files' => PublicReason.missingFile,
    'comparison failed' => PublicReason.comparisonFailed,
    'switch failed' => PublicReason.switchFailed,
    'worker stopped' || 'worker crashed' => PublicReason.workerStopped,
    'worker not running' => PublicReason.workerNotRunning,
    'server restarted' => PublicReason.serverRestarted,
    'outcome unknown' ||
    'switch outcome unknown' ||
    'import outcome unknown' => PublicReason.outcomeUnknown,
    'connection lost' => PublicReason.connectionLost,
    _ => PublicReason.other,
  };
}
