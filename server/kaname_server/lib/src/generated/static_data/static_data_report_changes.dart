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

/// Complete record count and a possibly cut-off prefix of stored keys.
abstract class StaticDataReportChanges
    implements _is.SerializableModel, _is.ProtocolSerialization {
  StaticDataReportChanges._({
    required this.count,
    required this.keys,
    required this.cutOff,
  });

  factory StaticDataReportChanges({
    required int count,
    required List<String> keys,
    required bool cutOff,
  }) = _StaticDataReportChangesImpl;

  factory StaticDataReportChanges.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return StaticDataReportChanges(
      count: jsonSerialization['count'] as int,
      keys: _iwxagaxh.Protocol().deserialize<List<String>>(
        jsonSerialization['keys'],
      ),
      cutOff: _is.BoolJsonExtension.fromJson(jsonSerialization['cutOff']),
    );
  }

  int count;

  List<String> keys;

  bool cutOff;

  /// Returns a shallow copy of this [StaticDataReportChanges]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StaticDataReportChanges copyWith({
    int? count,
    List<String>? keys,
    bool? cutOff,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StaticDataReportChanges',
      'count': count,
      'keys': keys.toJson(),
      'cutOff': cutOff,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StaticDataReportChanges',
      'count': count,
      'keys': keys.toJson(),
      'cutOff': cutOff,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _StaticDataReportChangesImpl extends StaticDataReportChanges {
  _StaticDataReportChangesImpl({
    required int count,
    required List<String> keys,
    required bool cutOff,
  }) : super._(count: count, keys: keys, cutOff: cutOff);

  /// Returns a shallow copy of this [StaticDataReportChanges]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StaticDataReportChanges copyWith({
    int? count,
    List<String>? keys,
    bool? cutOff,
  }) {
    return StaticDataReportChanges(
      count: count ?? this.count,
      keys: keys ?? this.keys.map((e0) => e0).toList(),
      cutOff: cutOff ?? this.cutOff,
    );
  }
}
