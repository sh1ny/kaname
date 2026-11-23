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
import 'package:kaname_server/src/generated/protocol.dart' as _iwxagaxh;
import 'package:serverpod/serverpod.dart' as _is;

import '../static_data/admin_answer_outcome.dart' as _iddm064r;
import '../static_data/admin_operation_view.dart' as _i8yd58de;
import '../static_data/public_reason.dart' as _iqdx9nyu;
import '../static_data/setting_revision.dart' as _il5o3xgp;

/// Closed result of a static-data admin command (D4, D5, D9).
abstract class AdminAnswer
    implements _is.SerializableModel, _is.ProtocolSerialization {
  AdminAnswer._({
    required this.outcome,
    this.reason,
    this.activeBuild,
    this.operation,
    this.pausedUntil,
    this.autoUpdate,
    this.settingRevision,
  });

  factory AdminAnswer({
    required _iddm064r.AdminAnswerOutcome outcome,
    _iqdx9nyu.PublicReason? reason,
    int? activeBuild,
    _i8yd58de.AdminOperationView? operation,
    DateTime? pausedUntil,
    bool? autoUpdate,
    _il5o3xgp.SettingRevision? settingRevision,
  }) = _AdminAnswerImpl;

  factory AdminAnswer.fromJson(Map<String, dynamic> jsonSerialization) {
    return AdminAnswer(
      outcome: _iddm064r.AdminAnswerOutcome.fromJson(
        (jsonSerialization['outcome'] as String),
      ),
      reason: jsonSerialization['reason'] == null
          ? null
          : _iqdx9nyu.PublicReason.fromJson(
              (jsonSerialization['reason'] as String),
            ),
      activeBuild: jsonSerialization['activeBuild'] as int?,
      operation: jsonSerialization['operation'] == null
          ? null
          : _iwxagaxh.Protocol().deserialize<_i8yd58de.AdminOperationView>(
              jsonSerialization['operation'],
            ),
      pausedUntil: jsonSerialization['pausedUntil'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['pausedUntil'],
            ),
      autoUpdate: jsonSerialization['autoUpdate'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['autoUpdate']),
      settingRevision: jsonSerialization['settingRevision'] == null
          ? null
          : _iwxagaxh.Protocol().deserialize<_il5o3xgp.SettingRevision>(
              jsonSerialization['settingRevision'],
            ),
    );
  }

  _iddm064r.AdminAnswerOutcome outcome;

  _iqdx9nyu.PublicReason? reason;

  int? activeBuild;

  _i8yd58de.AdminOperationView? operation;

  DateTime? pausedUntil;

  bool? autoUpdate;

  _il5o3xgp.SettingRevision? settingRevision;

  /// Returns a shallow copy of this [AdminAnswer]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AdminAnswer copyWith({
    _iddm064r.AdminAnswerOutcome? outcome,
    _iqdx9nyu.PublicReason? reason,
    int? activeBuild,
    _i8yd58de.AdminOperationView? operation =
        const _UndefinedAdminAnswer$operation(),
    DateTime? pausedUntil = const _is.$UndefinedDateTime(),
    bool? autoUpdate,
    _il5o3xgp.SettingRevision? settingRevision,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AdminAnswer',
      'outcome': outcome.toJson(),
      if (reason != null) 'reason': reason?.toJson(),
      if (activeBuild != null) 'activeBuild': activeBuild,
      if (operation != null) 'operation': operation?.toJson(),
      if (pausedUntil != null) 'pausedUntil': pausedUntil?.toJson(),
      if (autoUpdate != null) 'autoUpdate': autoUpdate,
      if (settingRevision != null) 'settingRevision': settingRevision?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AdminAnswer',
      'outcome': outcome.toJson(),
      if (reason != null) 'reason': reason?.toJson(),
      if (activeBuild != null) 'activeBuild': activeBuild,
      if (operation != null) 'operation': operation?.toJsonForProtocol(),
      if (pausedUntil != null) 'pausedUntil': pausedUntil?.toJson(),
      if (autoUpdate != null) 'autoUpdate': autoUpdate,
      if (settingRevision != null)
        'settingRevision': settingRevision?.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedAdminAnswer$operation extends _is.UndefinedSentinel
    implements _i8yd58de.AdminOperationView {
  const _UndefinedAdminAnswer$operation();
}

class _AdminAnswerImpl extends AdminAnswer {
  _AdminAnswerImpl({
    required _iddm064r.AdminAnswerOutcome outcome,
    _iqdx9nyu.PublicReason? reason,
    int? activeBuild,
    _i8yd58de.AdminOperationView? operation,
    DateTime? pausedUntil,
    bool? autoUpdate,
    _il5o3xgp.SettingRevision? settingRevision,
  }) : super._(
         outcome: outcome,
         reason: reason,
         activeBuild: activeBuild,
         operation: operation,
         pausedUntil: pausedUntil,
         autoUpdate: autoUpdate,
         settingRevision: settingRevision,
       );

  /// Returns a shallow copy of this [AdminAnswer]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AdminAnswer copyWith({
    _iddm064r.AdminAnswerOutcome? outcome,
    Object? reason = _Undefined,
    Object? activeBuild = _Undefined,
    _i8yd58de.AdminOperationView? operation =
        const _UndefinedAdminAnswer$operation(),
    DateTime? pausedUntil = const _is.$UndefinedDateTime(),
    Object? autoUpdate = _Undefined,
    Object? settingRevision = _Undefined,
  }) {
    return AdminAnswer(
      outcome: outcome ?? this.outcome,
      reason: reason is _iqdx9nyu.PublicReason? ? reason : this.reason,
      activeBuild: activeBuild is int? ? activeBuild : this.activeBuild,
      operation: operation is _is.UndefinedSentinel
          ? this.operation?.copyWith()
          : operation,
      pausedUntil: pausedUntil is _is.UndefinedSentinel
          ? this.pausedUntil
          : pausedUntil,
      autoUpdate: autoUpdate is bool? ? autoUpdate : this.autoUpdate,
      settingRevision: settingRevision is _il5o3xgp.SettingRevision?
          ? settingRevision
          : this.settingRevision?.copyWith(),
    );
  }
}
