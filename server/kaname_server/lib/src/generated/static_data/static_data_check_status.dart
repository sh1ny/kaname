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

import '../static_data/public_reason.dart' as _iqdx9nyu;
import '../static_data/sde_check_outcome.dart' as _ixsdo8ck;

/// A check without its private failure text (D15).
abstract class StaticDataCheckStatus
    implements _is.SerializableModel, _is.ProtocolSerialization {
  StaticDataCheckStatus._({
    required this.checkedAt,
    this.latestBuild,
    required this.outcome,
    this.reason,
  });

  factory StaticDataCheckStatus({
    required DateTime checkedAt,
    int? latestBuild,
    required _ixsdo8ck.SdeCheckOutcome outcome,
    _iqdx9nyu.PublicReason? reason,
  }) = _StaticDataCheckStatusImpl;

  factory StaticDataCheckStatus.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return StaticDataCheckStatus(
      checkedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['checkedAt'],
      ),
      latestBuild: jsonSerialization['latestBuild'] as int?,
      outcome: _ixsdo8ck.SdeCheckOutcome.fromJson(
        (jsonSerialization['outcome'] as String),
      ),
      reason: jsonSerialization['reason'] == null
          ? null
          : _iqdx9nyu.PublicReason.fromJson(
              (jsonSerialization['reason'] as String),
            ),
    );
  }

  DateTime checkedAt;

  int? latestBuild;

  _ixsdo8ck.SdeCheckOutcome outcome;

  _iqdx9nyu.PublicReason? reason;

  /// Returns a shallow copy of this [StaticDataCheckStatus]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StaticDataCheckStatus copyWith({
    DateTime? checkedAt,
    int? latestBuild,
    _ixsdo8ck.SdeCheckOutcome? outcome,
    _iqdx9nyu.PublicReason? reason,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StaticDataCheckStatus',
      'checkedAt': checkedAt.toJson(),
      if (latestBuild != null) 'latestBuild': latestBuild,
      'outcome': outcome.toJson(),
      if (reason != null) 'reason': reason?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StaticDataCheckStatus',
      'checkedAt': checkedAt.toJson(),
      if (latestBuild != null) 'latestBuild': latestBuild,
      'outcome': outcome.toJson(),
      if (reason != null) 'reason': reason?.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _StaticDataCheckStatusImpl extends StaticDataCheckStatus {
  _StaticDataCheckStatusImpl({
    required DateTime checkedAt,
    int? latestBuild,
    required _ixsdo8ck.SdeCheckOutcome outcome,
    _iqdx9nyu.PublicReason? reason,
  }) : super._(
         checkedAt: checkedAt,
         latestBuild: latestBuild,
         outcome: outcome,
         reason: reason,
       );

  /// Returns a shallow copy of this [StaticDataCheckStatus]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StaticDataCheckStatus copyWith({
    DateTime? checkedAt,
    Object? latestBuild = _Undefined,
    _ixsdo8ck.SdeCheckOutcome? outcome,
    Object? reason = _Undefined,
  }) {
    return StaticDataCheckStatus(
      checkedAt: checkedAt ?? this.checkedAt,
      latestBuild: latestBuild is int? ? latestBuild : this.latestBuild,
      outcome: outcome ?? this.outcome,
      reason: reason is _iqdx9nyu.PublicReason? ? reason : this.reason,
    );
  }
}
