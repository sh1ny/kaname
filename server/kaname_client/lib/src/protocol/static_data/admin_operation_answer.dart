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
import 'package:kaname_client/src/protocol/protocol.dart' as _i7wvxdxe;
import 'package:serverpod_client/serverpod_client.dart' as _isc;

import '../static_data/admin_operation_read_state.dart' as _id65g6gs;
import '../static_data/admin_operation_view.dart' as _i8yd58de;
import '../static_data/sde_admin_operation_kind.dart' as _ipiiq2t1;

/// Public progress for one operation id (D9, D21).
abstract class AdminOperationAnswer
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AdminOperationAnswer._({required this.state, this.kind, this.operation});

  factory AdminOperationAnswer({
    required _id65g6gs.AdminOperationReadState state,
    _ipiiq2t1.SdeAdminOperationKind? kind,
    _i8yd58de.AdminOperationView? operation,
  }) = _AdminOperationAnswerImpl;

  factory AdminOperationAnswer.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return AdminOperationAnswer(
      state: _id65g6gs.AdminOperationReadState.fromJson(
        (jsonSerialization['state'] as String),
      ),
      kind: jsonSerialization['kind'] == null
          ? null
          : _ipiiq2t1.SdeAdminOperationKind.fromJson(
              (jsonSerialization['kind'] as String),
            ),
      operation: jsonSerialization['operation'] == null
          ? null
          : _i7wvxdxe.Protocol().deserialize<_i8yd58de.AdminOperationView>(
              jsonSerialization['operation'],
            ),
    );
  }

  _id65g6gs.AdminOperationReadState state;

  _ipiiq2t1.SdeAdminOperationKind? kind;

  _i8yd58de.AdminOperationView? operation;

  /// Returns a shallow copy of this [AdminOperationAnswer]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AdminOperationAnswer copyWith({
    _id65g6gs.AdminOperationReadState? state,
    _ipiiq2t1.SdeAdminOperationKind? kind,
    _i8yd58de.AdminOperationView? operation =
        const _UndefinedAdminOperationAnswer$operation(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AdminOperationAnswer',
      'state': state.toJson(),
      if (kind != null) 'kind': kind?.toJson(),
      if (operation != null) 'operation': operation?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AdminOperationAnswer',
      'state': state.toJson(),
      if (kind != null) 'kind': kind?.toJson(),
      if (operation != null) 'operation': operation?.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedAdminOperationAnswer$operation extends _isc.UndefinedSentinel
    implements _i8yd58de.AdminOperationView {
  const _UndefinedAdminOperationAnswer$operation();
}

class _AdminOperationAnswerImpl extends AdminOperationAnswer {
  _AdminOperationAnswerImpl({
    required _id65g6gs.AdminOperationReadState state,
    _ipiiq2t1.SdeAdminOperationKind? kind,
    _i8yd58de.AdminOperationView? operation,
  }) : super._(state: state, kind: kind, operation: operation);

  /// Returns a shallow copy of this [AdminOperationAnswer]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AdminOperationAnswer copyWith({
    _id65g6gs.AdminOperationReadState? state,
    Object? kind = _Undefined,
    _i8yd58de.AdminOperationView? operation =
        const _UndefinedAdminOperationAnswer$operation(),
  }) {
    return AdminOperationAnswer(
      state: state ?? this.state,
      kind: kind is _ipiiq2t1.SdeAdminOperationKind? ? kind : this.kind,
      operation: operation is _isc.UndefinedSentinel
          ? this.operation?.copyWith()
          : operation,
    );
  }
}
