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

/// The newest check that learned CCP's latest build (D2).
abstract class StaticDataCcpLatest
    implements _is.SerializableModel, _is.ProtocolSerialization {
  StaticDataCcpLatest._({required this.build, required this.checkedAt});

  factory StaticDataCcpLatest({
    required int build,
    required DateTime checkedAt,
  }) = _StaticDataCcpLatestImpl;

  factory StaticDataCcpLatest.fromJson(Map<String, dynamic> jsonSerialization) {
    return StaticDataCcpLatest(
      build: jsonSerialization['build'] as int,
      checkedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['checkedAt'],
      ),
    );
  }

  int build;

  DateTime checkedAt;

  /// Returns a shallow copy of this [StaticDataCcpLatest]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StaticDataCcpLatest copyWith({int? build, DateTime? checkedAt});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StaticDataCcpLatest',
      'build': build,
      'checkedAt': checkedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StaticDataCcpLatest',
      'build': build,
      'checkedAt': checkedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _StaticDataCcpLatestImpl extends StaticDataCcpLatest {
  _StaticDataCcpLatestImpl({required int build, required DateTime checkedAt})
    : super._(build: build, checkedAt: checkedAt);

  /// Returns a shallow copy of this [StaticDataCcpLatest]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StaticDataCcpLatest copyWith({int? build, DateTime? checkedAt}) {
    return StaticDataCcpLatest(
      build: build ?? this.build,
      checkedAt: checkedAt ?? this.checkedAt,
    );
  }
}
