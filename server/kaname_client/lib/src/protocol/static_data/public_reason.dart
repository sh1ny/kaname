/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _isc;

/// Allowlisted static-data failure reasons. Raw stored text stays on the server (D15).
enum PublicReason implements _isc.SerializableModel {
  ccpUnreachable,
  postgresUnreachable,
  timedOut,
  importAlreadyRunning,
  missingFile,
  comparisonFailed,
  switchFailed,
  workerStopped,
  workerNotRunning,
  serverRestarted,
  outcomeUnknown,
  connectionLost,
  other;

  static PublicReason fromJson(String name) {
    switch (name) {
      case 'ccpUnreachable':
        return PublicReason.ccpUnreachable;
      case 'postgresUnreachable':
        return PublicReason.postgresUnreachable;
      case 'timedOut':
        return PublicReason.timedOut;
      case 'importAlreadyRunning':
        return PublicReason.importAlreadyRunning;
      case 'missingFile':
        return PublicReason.missingFile;
      case 'comparisonFailed':
        return PublicReason.comparisonFailed;
      case 'switchFailed':
        return PublicReason.switchFailed;
      case 'workerStopped':
        return PublicReason.workerStopped;
      case 'workerNotRunning':
        return PublicReason.workerNotRunning;
      case 'serverRestarted':
        return PublicReason.serverRestarted;
      case 'outcomeUnknown':
        return PublicReason.outcomeUnknown;
      case 'connectionLost':
        return PublicReason.connectionLost;
      case 'other':
        return PublicReason.other;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "PublicReason"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
