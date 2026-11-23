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
import 'package:serverpod/serverpod.dart' as _is;

/// Public admin command outcomes; never contains the submitted key (D9).
enum AdminAnswerOutcome implements _is.SerializableModel {
  keyAccepted,
  notConfigured,
  keyRejected,
  tooManyAttempts,
  started,
  noAnswerYet,
  outcomeUnknown,
  ended,
  importRunning,
  workerNotRunning,
  updateFailed,
  rollbackFailed,
  buildsChanged,
  noPrevious,
  rolledBack,
  adminBusy,
  malformed,
  settingConfirmed,
  settingChanged,
  settingNotSaved,
  settingNotConfirmed;

  static AdminAnswerOutcome fromJson(String name) {
    switch (name) {
      case 'keyAccepted':
        return AdminAnswerOutcome.keyAccepted;
      case 'notConfigured':
        return AdminAnswerOutcome.notConfigured;
      case 'keyRejected':
        return AdminAnswerOutcome.keyRejected;
      case 'tooManyAttempts':
        return AdminAnswerOutcome.tooManyAttempts;
      case 'started':
        return AdminAnswerOutcome.started;
      case 'noAnswerYet':
        return AdminAnswerOutcome.noAnswerYet;
      case 'outcomeUnknown':
        return AdminAnswerOutcome.outcomeUnknown;
      case 'ended':
        return AdminAnswerOutcome.ended;
      case 'importRunning':
        return AdminAnswerOutcome.importRunning;
      case 'workerNotRunning':
        return AdminAnswerOutcome.workerNotRunning;
      case 'updateFailed':
        return AdminAnswerOutcome.updateFailed;
      case 'rollbackFailed':
        return AdminAnswerOutcome.rollbackFailed;
      case 'buildsChanged':
        return AdminAnswerOutcome.buildsChanged;
      case 'noPrevious':
        return AdminAnswerOutcome.noPrevious;
      case 'rolledBack':
        return AdminAnswerOutcome.rolledBack;
      case 'adminBusy':
        return AdminAnswerOutcome.adminBusy;
      case 'malformed':
        return AdminAnswerOutcome.malformed;
      case 'settingConfirmed':
        return AdminAnswerOutcome.settingConfirmed;
      case 'settingChanged':
        return AdminAnswerOutcome.settingChanged;
      case 'settingNotSaved':
        return AdminAnswerOutcome.settingNotSaved;
      case 'settingNotConfirmed':
        return AdminAnswerOutcome.settingNotConfirmed;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "AdminAnswerOutcome"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
