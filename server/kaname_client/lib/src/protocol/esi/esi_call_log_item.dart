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

import '../esi/esi_call_log_cursor.dart' as _izn8x666;

/// One private receipt projected for its current owner.
abstract class EsiCallLogReceipt
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  EsiCallLogReceipt._({
    required this.cursor,
    required this.recordedAt,
    required this.characterId,
    required this.operation,
    this.bucket,
    required this.outcome,
    this.status,
    this.cost,
    required this.latencyMicros,
  });

  factory EsiCallLogReceipt({
    required _izn8x666.EsiCallLogCursor cursor,
    required DateTime recordedAt,
    required String characterId,
    required String operation,
    String? bucket,
    required String outcome,
    int? status,
    int? cost,
    required int latencyMicros,
  }) = _EsiCallLogReceiptImpl;

  factory EsiCallLogReceipt.fromJson(Map<String, dynamic> jsonSerialization) {
    return EsiCallLogReceipt(
      cursor: _i7wvxdxe.Protocol().deserialize<_izn8x666.EsiCallLogCursor>(
        jsonSerialization['cursor'],
      ),
      recordedAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['recordedAt'],
      ),
      characterId: jsonSerialization['characterId'] as String,
      operation: jsonSerialization['operation'] as String,
      bucket: jsonSerialization['bucket'] as String?,
      outcome: jsonSerialization['outcome'] as String,
      status: jsonSerialization['status'] as int?,
      cost: jsonSerialization['cost'] as int?,
      latencyMicros: jsonSerialization['latencyMicros'] as int,
    );
  }

  _izn8x666.EsiCallLogCursor cursor;

  DateTime recordedAt;

  String characterId;

  String operation;

  String? bucket;

  String outcome;

  int? status;

  int? cost;

  int latencyMicros;

  /// Returns a shallow copy of this [EsiCallLogReceipt]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  EsiCallLogReceipt copyWith({
    _izn8x666.EsiCallLogCursor? cursor,
    DateTime? recordedAt,
    String? characterId,
    String? operation,
    String? bucket,
    String? outcome,
    int? status,
    int? cost,
    int? latencyMicros,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'EsiCallLogReceipt',
      'cursor': cursor.toJson(),
      'recordedAt': recordedAt.toJson(),
      'characterId': characterId,
      'operation': operation,
      if (bucket != null) 'bucket': bucket,
      'outcome': outcome,
      if (status != null) 'status': status,
      if (cost != null) 'cost': cost,
      'latencyMicros': latencyMicros,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'EsiCallLogReceipt',
      'cursor': cursor.toJsonForProtocol(),
      'recordedAt': recordedAt.toJson(),
      'characterId': characterId,
      'operation': operation,
      if (bucket != null) 'bucket': bucket,
      'outcome': outcome,
      if (status != null) 'status': status,
      if (cost != null) 'cost': cost,
      'latencyMicros': latencyMicros,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _EsiCallLogReceiptImpl extends EsiCallLogReceipt {
  _EsiCallLogReceiptImpl({
    required _izn8x666.EsiCallLogCursor cursor,
    required DateTime recordedAt,
    required String characterId,
    required String operation,
    String? bucket,
    required String outcome,
    int? status,
    int? cost,
    required int latencyMicros,
  }) : super._(
         cursor: cursor,
         recordedAt: recordedAt,
         characterId: characterId,
         operation: operation,
         bucket: bucket,
         outcome: outcome,
         status: status,
         cost: cost,
         latencyMicros: latencyMicros,
       );

  /// Returns a shallow copy of this [EsiCallLogReceipt]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  EsiCallLogReceipt copyWith({
    _izn8x666.EsiCallLogCursor? cursor,
    DateTime? recordedAt,
    String? characterId,
    String? operation,
    Object? bucket = _Undefined,
    String? outcome,
    Object? status = _Undefined,
    Object? cost = _Undefined,
    int? latencyMicros,
  }) {
    return EsiCallLogReceipt(
      cursor: cursor ?? this.cursor.copyWith(),
      recordedAt: recordedAt ?? this.recordedAt,
      characterId: characterId ?? this.characterId,
      operation: operation ?? this.operation,
      bucket: bucket is String? ? bucket : this.bucket,
      outcome: outcome ?? this.outcome,
      status: status is int? ? status : this.status,
      cost: cost is int? ? cost : this.cost,
      latencyMicros: latencyMicros ?? this.latencyMicros,
    );
  }
}
