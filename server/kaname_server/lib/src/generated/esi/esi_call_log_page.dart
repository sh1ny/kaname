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

import '../esi/esi_call_log_cursor.dart' as _izn8x666;
import '../esi/esi_call_log_item.dart' as _i4yu6llt;

/// One bounded page from the viewer's own history.
abstract class EsiCallLogPage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  EsiCallLogPage._({required this.status, required this.rows, this.next});

  factory EsiCallLogPage({
    required String status,
    required List<_i4yu6llt.EsiCallLogReceipt> rows,
    _izn8x666.EsiCallLogCursor? next,
  }) = _EsiCallLogPageImpl;

  factory EsiCallLogPage.fromJson(Map<String, dynamic> jsonSerialization) {
    return EsiCallLogPage(
      status: jsonSerialization['status'] as String,
      rows: _iwxagaxh.Protocol().deserialize<List<_i4yu6llt.EsiCallLogReceipt>>(
        jsonSerialization['rows'],
      ),
      next: jsonSerialization['next'] == null
          ? null
          : _iwxagaxh.Protocol().deserialize<_izn8x666.EsiCallLogCursor>(
              jsonSerialization['next'],
            ),
    );
  }

  String status;

  List<_i4yu6llt.EsiCallLogReceipt> rows;

  _izn8x666.EsiCallLogCursor? next;

  /// Returns a shallow copy of this [EsiCallLogPage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  EsiCallLogPage copyWith({
    String? status,
    List<_i4yu6llt.EsiCallLogReceipt>? rows,
    _izn8x666.EsiCallLogCursor? next = const _UndefinedEsiCallLogPage$next(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'EsiCallLogPage',
      'status': status,
      'rows': rows.toJson(valueToJson: (v) => v.toJson()),
      if (next != null) 'next': next?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'EsiCallLogPage',
      'status': status,
      'rows': rows.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      if (next != null) 'next': next?.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _UndefinedEsiCallLogPage$next extends _is.UndefinedSentinel
    implements _izn8x666.EsiCallLogCursor {
  const _UndefinedEsiCallLogPage$next();
}

class _EsiCallLogPageImpl extends EsiCallLogPage {
  _EsiCallLogPageImpl({
    required String status,
    required List<_i4yu6llt.EsiCallLogReceipt> rows,
    _izn8x666.EsiCallLogCursor? next,
  }) : super._(status: status, rows: rows, next: next);

  /// Returns a shallow copy of this [EsiCallLogPage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  EsiCallLogPage copyWith({
    String? status,
    List<_i4yu6llt.EsiCallLogReceipt>? rows,
    _izn8x666.EsiCallLogCursor? next = const _UndefinedEsiCallLogPage$next(),
  }) {
    return EsiCallLogPage(
      status: status ?? this.status,
      rows: rows ?? this.rows.map((e0) => e0.copyWith()).toList(),
      next: next is _is.UndefinedSentinel ? this.next?.copyWith() : next,
    );
  }
}
