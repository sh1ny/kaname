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

/// The terminal result of a static-data admin operation (D21).
enum SdeAdminOperationOutcome implements _is.SerializableModel {
  switched,
  upToDate,
  held,
  older,
  staged,
  failed,
  buildsChanged,
  noPrevious,
  importRunning,
  rolledBack,
  rollbackFailed;

  static SdeAdminOperationOutcome fromJson(String name) {
    switch (name) {
      case 'switched':
        return SdeAdminOperationOutcome.switched;
      case 'upToDate':
        return SdeAdminOperationOutcome.upToDate;
      case 'held':
        return SdeAdminOperationOutcome.held;
      case 'older':
        return SdeAdminOperationOutcome.older;
      case 'staged':
        return SdeAdminOperationOutcome.staged;
      case 'failed':
        return SdeAdminOperationOutcome.failed;
      case 'buildsChanged':
        return SdeAdminOperationOutcome.buildsChanged;
      case 'noPrevious':
        return SdeAdminOperationOutcome.noPrevious;
      case 'importRunning':
        return SdeAdminOperationOutcome.importRunning;
      case 'rolledBack':
        return SdeAdminOperationOutcome.rolledBack;
      case 'rollbackFailed':
        return SdeAdminOperationOutcome.rollbackFailed;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "SdeAdminOperationOutcome"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
