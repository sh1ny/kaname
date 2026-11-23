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

import '../static_data/public_reason.dart' as _iqdx9nyu;
import '../static_data/sde_build_diff_outcome.dart' as _i122pkx3;

/// The newest stored comparison of the active and previous builds (D2).
abstract class StaticDataDiffStatus
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  StaticDataDiffStatus._({
    required this.fromBuild,
    required this.toBuild,
    required this.outcome,
    this.reason,
    this.reportBytes,
  });

  factory StaticDataDiffStatus({
    required int fromBuild,
    required int toBuild,
    required _i122pkx3.SdeBuildDiffOutcome outcome,
    _iqdx9nyu.PublicReason? reason,
    int? reportBytes,
  }) = _StaticDataDiffStatusImpl;

  factory StaticDataDiffStatus.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return StaticDataDiffStatus(
      fromBuild: jsonSerialization['fromBuild'] as int,
      toBuild: jsonSerialization['toBuild'] as int,
      outcome: _i122pkx3.SdeBuildDiffOutcome.fromJson(
        (jsonSerialization['outcome'] as String),
      ),
      reason: jsonSerialization['reason'] == null
          ? null
          : _iqdx9nyu.PublicReason.fromJson(
              (jsonSerialization['reason'] as String),
            ),
      reportBytes: jsonSerialization['reportBytes'] as int?,
    );
  }

  int fromBuild;

  int toBuild;

  _i122pkx3.SdeBuildDiffOutcome outcome;

  _iqdx9nyu.PublicReason? reason;

  int? reportBytes;

  /// Returns a shallow copy of this [StaticDataDiffStatus]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  StaticDataDiffStatus copyWith({
    int? fromBuild,
    int? toBuild,
    _i122pkx3.SdeBuildDiffOutcome? outcome,
    _iqdx9nyu.PublicReason? reason,
    int? reportBytes,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StaticDataDiffStatus',
      'fromBuild': fromBuild,
      'toBuild': toBuild,
      'outcome': outcome.toJson(),
      if (reason != null) 'reason': reason?.toJson(),
      if (reportBytes != null) 'reportBytes': reportBytes,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StaticDataDiffStatus',
      'fromBuild': fromBuild,
      'toBuild': toBuild,
      'outcome': outcome.toJson(),
      if (reason != null) 'reason': reason?.toJson(),
      if (reportBytes != null) 'reportBytes': reportBytes,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _StaticDataDiffStatusImpl extends StaticDataDiffStatus {
  _StaticDataDiffStatusImpl({
    required int fromBuild,
    required int toBuild,
    required _i122pkx3.SdeBuildDiffOutcome outcome,
    _iqdx9nyu.PublicReason? reason,
    int? reportBytes,
  }) : super._(
         fromBuild: fromBuild,
         toBuild: toBuild,
         outcome: outcome,
         reason: reason,
         reportBytes: reportBytes,
       );

  /// Returns a shallow copy of this [StaticDataDiffStatus]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  StaticDataDiffStatus copyWith({
    int? fromBuild,
    int? toBuild,
    _i122pkx3.SdeBuildDiffOutcome? outcome,
    Object? reason = _Undefined,
    Object? reportBytes = _Undefined,
  }) {
    return StaticDataDiffStatus(
      fromBuild: fromBuild ?? this.fromBuild,
      toBuild: toBuild ?? this.toBuild,
      outcome: outcome ?? this.outcome,
      reason: reason is _iqdx9nyu.PublicReason? ? reason : this.reason,
      reportBytes: reportBytes is int? ? reportBytes : this.reportBytes,
    );
  }
}
