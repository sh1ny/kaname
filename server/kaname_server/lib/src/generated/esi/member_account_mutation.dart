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

import '../esi/member_account_status.dart' as _ier7pb9s;

/// Result of changing the linked character roster or its main.
abstract class MemberAccountMutation
    implements _is.SerializableModel, _is.ProtocolSerialization {
  MemberAccountMutation._({required this.status});

  factory MemberAccountMutation({
    required _ier7pb9s.MemberAccountStatus status,
  }) = _MemberAccountMutationImpl;

  factory MemberAccountMutation.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return MemberAccountMutation(
      status: _ier7pb9s.MemberAccountStatus.fromJson(
        (jsonSerialization['status'] as String),
      ),
    );
  }

  _ier7pb9s.MemberAccountStatus status;

  /// Returns a shallow copy of this [MemberAccountMutation]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  MemberAccountMutation copyWith({_ier7pb9s.MemberAccountStatus? status});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MemberAccountMutation',
      'status': status.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'MemberAccountMutation',
      'status': status.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _MemberAccountMutationImpl extends MemberAccountMutation {
  _MemberAccountMutationImpl({required _ier7pb9s.MemberAccountStatus status})
    : super._(status: status);

  /// Returns a shallow copy of this [MemberAccountMutation]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  MemberAccountMutation copyWith({_ier7pb9s.MemberAccountStatus? status}) {
    return MemberAccountMutation(status: status ?? this.status);
  }
}
