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

/// A fixed-window route-level count, without character or member fields.
abstract class EsiRouteCount
    implements _is.SerializableModel, _is.ProtocolSerialization {
  EsiRouteCount._({
    required this.operation,
    required this.total,
    required this.errors,
  });

  factory EsiRouteCount({
    required String operation,
    required int total,
    required int errors,
  }) = _EsiRouteCountImpl;

  factory EsiRouteCount.fromJson(Map<String, dynamic> jsonSerialization) {
    return EsiRouteCount(
      operation: jsonSerialization['operation'] as String,
      total: jsonSerialization['total'] as int,
      errors: jsonSerialization['errors'] as int,
    );
  }

  String operation;

  int total;

  int errors;

  /// Returns a shallow copy of this [EsiRouteCount]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  EsiRouteCount copyWith({String? operation, int? total, int? errors});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'EsiRouteCount',
      'operation': operation,
      'total': total,
      'errors': errors,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'EsiRouteCount',
      'operation': operation,
      'total': total,
      'errors': errors,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _EsiRouteCountImpl extends EsiRouteCount {
  _EsiRouteCountImpl({
    required String operation,
    required int total,
    required int errors,
  }) : super._(operation: operation, total: total, errors: errors);

  /// Returns a shallow copy of this [EsiRouteCount]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  EsiRouteCount copyWith({String? operation, int? total, int? errors}) {
    return EsiRouteCount(
      operation: operation ?? this.operation,
      total: total ?? this.total,
      errors: errors ?? this.errors,
    );
  }
}
