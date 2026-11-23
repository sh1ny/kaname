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
import '../static_data/sde_admin_operation_outcome.dart' as _i3ecqvv4;

/// The durable terminal evidence of an admin operation (D21, C2).
abstract class AdminOperationView
    implements _is.SerializableModel, _is.ProtocolSerialization {
  AdminOperationView._({
    required this.outcome,
    this.reason,
    this.activeBuild,
    required this.changedBuilds,
  });

  factory AdminOperationView({
    required _i3ecqvv4.SdeAdminOperationOutcome outcome,
    _iqdx9nyu.PublicReason? reason,
    int? activeBuild,
    required bool changedBuilds,
  }) = _AdminOperationViewImpl;

  factory AdminOperationView.fromJson(Map<String, dynamic> jsonSerialization) {
    return AdminOperationView(
      outcome: _i3ecqvv4.SdeAdminOperationOutcome.fromJson(
        (jsonSerialization['outcome'] as String),
      ),
      reason: jsonSerialization['reason'] == null
          ? null
          : _iqdx9nyu.PublicReason.fromJson(
              (jsonSerialization['reason'] as String),
            ),
      activeBuild: jsonSerialization['activeBuild'] as int?,
      changedBuilds: _is.BoolJsonExtension.fromJson(
        jsonSerialization['changedBuilds'],
      ),
    );
  }

  _i3ecqvv4.SdeAdminOperationOutcome outcome;

  _iqdx9nyu.PublicReason? reason;

  int? activeBuild;

  bool changedBuilds;

  /// Returns a shallow copy of this [AdminOperationView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AdminOperationView copyWith({
    _i3ecqvv4.SdeAdminOperationOutcome? outcome,
    _iqdx9nyu.PublicReason? reason,
    int? activeBuild,
    bool? changedBuilds,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AdminOperationView',
      'outcome': outcome.toJson(),
      if (reason != null) 'reason': reason?.toJson(),
      if (activeBuild != null) 'activeBuild': activeBuild,
      'changedBuilds': changedBuilds,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AdminOperationView',
      'outcome': outcome.toJson(),
      if (reason != null) 'reason': reason?.toJson(),
      if (activeBuild != null) 'activeBuild': activeBuild,
      'changedBuilds': changedBuilds,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AdminOperationViewImpl extends AdminOperationView {
  _AdminOperationViewImpl({
    required _i3ecqvv4.SdeAdminOperationOutcome outcome,
    _iqdx9nyu.PublicReason? reason,
    int? activeBuild,
    required bool changedBuilds,
  }) : super._(
         outcome: outcome,
         reason: reason,
         activeBuild: activeBuild,
         changedBuilds: changedBuilds,
       );

  /// Returns a shallow copy of this [AdminOperationView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AdminOperationView copyWith({
    _i3ecqvv4.SdeAdminOperationOutcome? outcome,
    Object? reason = _Undefined,
    Object? activeBuild = _Undefined,
    bool? changedBuilds,
  }) {
    return AdminOperationView(
      outcome: outcome ?? this.outcome,
      reason: reason is _iqdx9nyu.PublicReason? ? reason : this.reason,
      activeBuild: activeBuild is int? ? activeBuild : this.activeBuild,
      changedBuilds: changedBuilds ?? this.changedBuilds,
    );
  }
}
