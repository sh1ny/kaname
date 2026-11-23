import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/public_reason.dart';
import 'package:test/test.dart';

void main() {
  test('a public reason drops URLs, socket addresses, paths and exception '
      'text', () {
    const inputs = {
      'CCP unreachable: https://test.invalid/download at 10.0.0.1:8443':
          PublicReason.ccpUnreachable,
      'Postgres unreachable: SocketException for localhost:5432':
          PublicReason.postgresUnreachable,
      'missing required files: /srv/cache/private/foo.jsonl':
          PublicReason.missingFile,
      'comparison failed: FileSystemException, /srv/cache/private':
          PublicReason.comparisonFailed,
      'switch failed: unique constraint on test relation':
          PublicReason.switchFailed,
      'FileSystemException: /srv/cache/private, connection lost':
          PublicReason.other,
      'CCP unreachableElsewhere: detail that is not the fixed label':
          PublicReason.other,
    };
    for (final MapEntry(key: stored, value: reason) in inputs.entries) {
      expect(publicReasonOf(stored), reason);
    }
  });

  test('settlement and import outcomes retain their public distinctions', () {
    const inputs = {
      'timed out': PublicReason.timedOut,
      'import already running': PublicReason.importAlreadyRunning,
      'worker stopped': PublicReason.workerStopped,
      'worker crashed': PublicReason.workerStopped,
      'worker not running': PublicReason.workerNotRunning,
      'server restarted': PublicReason.serverRestarted,
      'switch outcome unknown': PublicReason.outcomeUnknown,
      'import outcome unknown': PublicReason.outcomeUnknown,
      'outcome unknown': PublicReason.outcomeUnknown,
      'connection lost': PublicReason.connectionLost,
    };
    for (final MapEntry(key: stored, value: reason) in inputs.entries) {
      expect(publicReasonOf(stored), reason);
    }
    expect(publicReasonOf(null), isNull);
  });
}
