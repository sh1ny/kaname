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

/// Keyset cursor; it never changes the authenticated viewer.
abstract class EsiCallLogCursor
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  EsiCallLogCursor._({required this.id, required this.recordedAt});

  factory EsiCallLogCursor({required String id, required DateTime recordedAt}) =
      _EsiCallLogCursorImpl;

  factory EsiCallLogCursor.fromJson(Map<String, dynamic> jsonSerialization) {
    return EsiCallLogCursor(
      id: jsonSerialization['id'] as String,
      recordedAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['recordedAt'],
      ),
    );
  }

  DateTime recordedAt;

  String id;

  /// Returns a shallow copy of this [EsiCallLogCursor]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  EsiCallLogCursor copyWith({String? id, DateTime? recordedAt});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'EsiCallLogCursor',
      'id': id,
      'recordedAt': recordedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'EsiCallLogCursor',
      'id': id,
      'recordedAt': recordedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _EsiCallLogCursorImpl extends EsiCallLogCursor {
  _EsiCallLogCursorImpl({required String id, required DateTime recordedAt})
    : super._(id: id, recordedAt: recordedAt);

  /// Returns a shallow copy of this [EsiCallLogCursor]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  EsiCallLogCursor copyWith({String? id, DateTime? recordedAt}) {
    return EsiCallLogCursor(
      id: id ?? this.id,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }
}
