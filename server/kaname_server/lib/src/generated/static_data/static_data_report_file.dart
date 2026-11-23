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

import '../static_data/static_data_report_changes.dart' as _ijj24ojj;
import '../static_data/static_data_report_file_status.dart' as _i6cpjomc;

/// A file comparison with complete counts and bounded details (D16).
abstract class StaticDataReportFile
    implements _is.SerializableModel, _is.ProtocolSerialization {
  StaticDataReportFile._({
    required this.file,
    required this.status,
    required this.added,
    required this.removed,
    required this.changed,
    required this.changedFields,
    required this.changedFieldCount,
    required this.changedFieldsCutOff,
  });

  factory StaticDataReportFile({
    required String file,
    required _i6cpjomc.StaticDataReportFileStatus status,
    required _ijj24ojj.StaticDataReportChanges added,
    required _ijj24ojj.StaticDataReportChanges removed,
    required _ijj24ojj.StaticDataReportChanges changed,
    required Map<String, int> changedFields,
    required int changedFieldCount,
    required bool changedFieldsCutOff,
  }) = _StaticDataReportFileImpl;

  factory StaticDataReportFile.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return StaticDataReportFile(
      file: jsonSerialization['file'] as String,
      status: _i6cpjomc.StaticDataReportFileStatus.fromJson(
        (jsonSerialization['status'] as String),
      ),
      added: _iwxagaxh.Protocol()
          .deserialize<_ijj24ojj.StaticDataReportChanges>(
            jsonSerialization['added'],
          ),
      removed: _iwxagaxh.Protocol()
          .deserialize<_ijj24ojj.StaticDataReportChanges>(
            jsonSerialization['removed'],
          ),
      changed: _iwxagaxh.Protocol()
          .deserialize<_ijj24ojj.StaticDataReportChanges>(
            jsonSerialization['changed'],
          ),
      changedFields: _iwxagaxh.Protocol().deserialize<Map<String, int>>(
        jsonSerialization['changedFields'],
      ),
      changedFieldCount: jsonSerialization['changedFieldCount'] as int,
      changedFieldsCutOff: _is.BoolJsonExtension.fromJson(
        jsonSerialization['changedFieldsCutOff'],
      ),
    );
  }

  String file;

  _i6cpjomc.StaticDataReportFileStatus status;

  _ijj24ojj.StaticDataReportChanges added;

  _ijj24ojj.StaticDataReportChanges removed;

  _ijj24ojj.StaticDataReportChanges changed;

  Map<String, int> changedFields;

  int changedFieldCount;

  bool changedFieldsCutOff;

  /// Returns a shallow copy of this [StaticDataReportFile]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StaticDataReportFile copyWith({
    String? file,
    _i6cpjomc.StaticDataReportFileStatus? status,
    _ijj24ojj.StaticDataReportChanges? added,
    _ijj24ojj.StaticDataReportChanges? removed,
    _ijj24ojj.StaticDataReportChanges? changed,
    Map<String, int>? changedFields,
    int? changedFieldCount,
    bool? changedFieldsCutOff,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StaticDataReportFile',
      'file': file,
      'status': status.toJson(),
      'added': added.toJson(),
      'removed': removed.toJson(),
      'changed': changed.toJson(),
      'changedFields': changedFields.toJson(),
      'changedFieldCount': changedFieldCount,
      'changedFieldsCutOff': changedFieldsCutOff,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StaticDataReportFile',
      'file': file,
      'status': status.toJson(),
      'added': added.toJsonForProtocol(),
      'removed': removed.toJsonForProtocol(),
      'changed': changed.toJsonForProtocol(),
      'changedFields': changedFields.toJson(),
      'changedFieldCount': changedFieldCount,
      'changedFieldsCutOff': changedFieldsCutOff,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _StaticDataReportFileImpl extends StaticDataReportFile {
  _StaticDataReportFileImpl({
    required String file,
    required _i6cpjomc.StaticDataReportFileStatus status,
    required _ijj24ojj.StaticDataReportChanges added,
    required _ijj24ojj.StaticDataReportChanges removed,
    required _ijj24ojj.StaticDataReportChanges changed,
    required Map<String, int> changedFields,
    required int changedFieldCount,
    required bool changedFieldsCutOff,
  }) : super._(
         file: file,
         status: status,
         added: added,
         removed: removed,
         changed: changed,
         changedFields: changedFields,
         changedFieldCount: changedFieldCount,
         changedFieldsCutOff: changedFieldsCutOff,
       );

  /// Returns a shallow copy of this [StaticDataReportFile]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StaticDataReportFile copyWith({
    String? file,
    _i6cpjomc.StaticDataReportFileStatus? status,
    _ijj24ojj.StaticDataReportChanges? added,
    _ijj24ojj.StaticDataReportChanges? removed,
    _ijj24ojj.StaticDataReportChanges? changed,
    Map<String, int>? changedFields,
    int? changedFieldCount,
    bool? changedFieldsCutOff,
  }) {
    return StaticDataReportFile(
      file: file ?? this.file,
      status: status ?? this.status,
      added: added ?? this.added.copyWith(),
      removed: removed ?? this.removed.copyWith(),
      changed: changed ?? this.changed.copyWith(),
      changedFields:
          changedFields ??
          this.changedFields.map((key0, value0) => MapEntry(key0, value0)),
      changedFieldCount: changedFieldCount ?? this.changedFieldCount,
      changedFieldsCutOff: changedFieldsCutOff ?? this.changedFieldsCutOff,
    );
  }
}
