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

/// Static-data status could not be read. No database detail is returned (D2, C2).
abstract class StaticDataStatusUnavailable
    implements
        _is.SerializableException,
        _is.SerializableModel,
        _is.ProtocolSerialization {
  StaticDataStatusUnavailable._();

  factory StaticDataStatusUnavailable() = _StaticDataStatusUnavailableImpl;

  factory StaticDataStatusUnavailable.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return StaticDataStatusUnavailable();
  }

  /// Returns a shallow copy of this [StaticDataStatusUnavailable]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StaticDataStatusUnavailable copyWith();
  @override
  Map<String, dynamic> toJson() {
    return {'__className__': 'StaticDataStatusUnavailable'};
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {'__className__': 'StaticDataStatusUnavailable'};
  }

  @override
  String toString() {
    return 'StaticDataStatusUnavailable';
  }
}

class _StaticDataStatusUnavailableImpl extends StaticDataStatusUnavailable {
  _StaticDataStatusUnavailableImpl() : super._();

  /// Returns a shallow copy of this [StaticDataStatusUnavailable]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StaticDataStatusUnavailable copyWith() {
    return StaticDataStatusUnavailable();
  }
}
