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
import '../static_data/sde_switch_kind.dart' as _ilj53nom;
import '../static_data/sde_switch_outcome.dart' as _iiykv4y8;

/// A switch or rollback without private failure text (D15).
abstract class StaticDataSwitchStatus
    implements _is.SerializableModel, _is.ProtocolSerialization {
  StaticDataSwitchStatus._({
    required this.kind,
    this.fromBuild,
    required this.toBuild,
    required this.at,
    required this.outcome,
    this.reason,
  });

  factory StaticDataSwitchStatus({
    required _ilj53nom.SdeSwitchKind kind,
    int? fromBuild,
    required int toBuild,
    required DateTime at,
    required _iiykv4y8.SdeSwitchOutcome outcome,
    _iqdx9nyu.PublicReason? reason,
  }) = _StaticDataSwitchStatusImpl;

  factory StaticDataSwitchStatus.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return StaticDataSwitchStatus(
      kind: _ilj53nom.SdeSwitchKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      fromBuild: jsonSerialization['fromBuild'] as int?,
      toBuild: jsonSerialization['toBuild'] as int,
      at: _is.DateTimeJsonExtension.fromJson(jsonSerialization['at']),
      outcome: _iiykv4y8.SdeSwitchOutcome.fromJson(
        (jsonSerialization['outcome'] as String),
      ),
      reason: jsonSerialization['reason'] == null
          ? null
          : _iqdx9nyu.PublicReason.fromJson(
              (jsonSerialization['reason'] as String),
            ),
    );
  }

  _ilj53nom.SdeSwitchKind kind;

  int? fromBuild;

  int toBuild;

  DateTime at;

  _iiykv4y8.SdeSwitchOutcome outcome;

  _iqdx9nyu.PublicReason? reason;

  /// Returns a shallow copy of this [StaticDataSwitchStatus]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StaticDataSwitchStatus copyWith({
    _ilj53nom.SdeSwitchKind? kind,
    int? fromBuild,
    int? toBuild,
    DateTime? at,
    _iiykv4y8.SdeSwitchOutcome? outcome,
    _iqdx9nyu.PublicReason? reason,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StaticDataSwitchStatus',
      'kind': kind.toJson(),
      if (fromBuild != null) 'fromBuild': fromBuild,
      'toBuild': toBuild,
      'at': at.toJson(),
      'outcome': outcome.toJson(),
      if (reason != null) 'reason': reason?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StaticDataSwitchStatus',
      'kind': kind.toJson(),
      if (fromBuild != null) 'fromBuild': fromBuild,
      'toBuild': toBuild,
      'at': at.toJson(),
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

class _StaticDataSwitchStatusImpl extends StaticDataSwitchStatus {
  _StaticDataSwitchStatusImpl({
    required _ilj53nom.SdeSwitchKind kind,
    int? fromBuild,
    required int toBuild,
    required DateTime at,
    required _iiykv4y8.SdeSwitchOutcome outcome,
    _iqdx9nyu.PublicReason? reason,
  }) : super._(
         kind: kind,
         fromBuild: fromBuild,
         toBuild: toBuild,
         at: at,
         outcome: outcome,
         reason: reason,
       );

  /// Returns a shallow copy of this [StaticDataSwitchStatus]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StaticDataSwitchStatus copyWith({
    _ilj53nom.SdeSwitchKind? kind,
    Object? fromBuild = _Undefined,
    int? toBuild,
    DateTime? at,
    _iiykv4y8.SdeSwitchOutcome? outcome,
    Object? reason = _Undefined,
  }) {
    return StaticDataSwitchStatus(
      kind: kind ?? this.kind,
      fromBuild: fromBuild is int? ? fromBuild : this.fromBuild,
      toBuild: toBuild ?? this.toBuild,
      at: at ?? this.at,
      outcome: outcome ?? this.outcome,
      reason: reason is _iqdx9nyu.PublicReason? ? reason : this.reason,
    );
  }
}
