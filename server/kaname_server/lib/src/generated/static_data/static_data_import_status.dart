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

import '../static_data/public_reason.dart' as _iqdx9nyu;
import '../static_data/sde_import_outcome.dart' as _irhmnpec;

/// A bounded import summary without private diagnostics (D2, D15).
abstract class StaticDataImportStatus
    implements _is.SerializableModel, _is.ProtocolSerialization {
  StaticDataImportStatus._({
    this.build,
    required this.startedAt,
    this.finishedAt,
    required this.outcome,
    this.reason,
    this.fileCounts,
    required this.fileCount,
    required this.fileCountsCutOff,
  });

  factory StaticDataImportStatus({
    int? build,
    required DateTime startedAt,
    DateTime? finishedAt,
    required _irhmnpec.SdeImportOutcome outcome,
    _iqdx9nyu.PublicReason? reason,
    Map<String, int>? fileCounts,
    required int fileCount,
    required bool fileCountsCutOff,
  }) = _StaticDataImportStatusImpl;

  factory StaticDataImportStatus.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return StaticDataImportStatus(
      build: jsonSerialization['build'] as int?,
      startedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['startedAt'],
      ),
      finishedAt: jsonSerialization['finishedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['finishedAt']),
      outcome: _irhmnpec.SdeImportOutcome.fromJson(
        (jsonSerialization['outcome'] as String),
      ),
      reason: jsonSerialization['reason'] == null
          ? null
          : _iqdx9nyu.PublicReason.fromJson(
              (jsonSerialization['reason'] as String),
            ),
      fileCounts: jsonSerialization['fileCounts'] == null
          ? null
          : _iwxagaxh.Protocol().deserialize<Map<String, int>>(
              jsonSerialization['fileCounts'],
            ),
      fileCount: jsonSerialization['fileCount'] as int,
      fileCountsCutOff: _is.BoolJsonExtension.fromJson(
        jsonSerialization['fileCountsCutOff'],
      ),
    );
  }

  int? build;

  DateTime startedAt;

  DateTime? finishedAt;

  _irhmnpec.SdeImportOutcome outcome;

  _iqdx9nyu.PublicReason? reason;

  Map<String, int>? fileCounts;

  int fileCount;

  bool fileCountsCutOff;

  /// Returns a shallow copy of this [StaticDataImportStatus]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StaticDataImportStatus copyWith({
    int? build,
    DateTime? startedAt,
    DateTime? finishedAt = const _is.$UndefinedDateTime(),
    _irhmnpec.SdeImportOutcome? outcome,
    _iqdx9nyu.PublicReason? reason,
    Map<String, int>? fileCounts = const _is.$UndefinedMap<String, int>(),
    int? fileCount,
    bool? fileCountsCutOff,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StaticDataImportStatus',
      if (build != null) 'build': build,
      'startedAt': startedAt.toJson(),
      if (finishedAt != null) 'finishedAt': finishedAt?.toJson(),
      'outcome': outcome.toJson(),
      if (reason != null) 'reason': reason?.toJson(),
      if (fileCounts != null) 'fileCounts': fileCounts?.toJson(),
      'fileCount': fileCount,
      'fileCountsCutOff': fileCountsCutOff,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StaticDataImportStatus',
      if (build != null) 'build': build,
      'startedAt': startedAt.toJson(),
      if (finishedAt != null) 'finishedAt': finishedAt?.toJson(),
      'outcome': outcome.toJson(),
      if (reason != null) 'reason': reason?.toJson(),
      if (fileCounts != null) 'fileCounts': fileCounts?.toJson(),
      'fileCount': fileCount,
      'fileCountsCutOff': fileCountsCutOff,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _StaticDataImportStatusImpl extends StaticDataImportStatus {
  _StaticDataImportStatusImpl({
    int? build,
    required DateTime startedAt,
    DateTime? finishedAt,
    required _irhmnpec.SdeImportOutcome outcome,
    _iqdx9nyu.PublicReason? reason,
    Map<String, int>? fileCounts,
    required int fileCount,
    required bool fileCountsCutOff,
  }) : super._(
         build: build,
         startedAt: startedAt,
         finishedAt: finishedAt,
         outcome: outcome,
         reason: reason,
         fileCounts: fileCounts,
         fileCount: fileCount,
         fileCountsCutOff: fileCountsCutOff,
       );

  /// Returns a shallow copy of this [StaticDataImportStatus]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StaticDataImportStatus copyWith({
    Object? build = _Undefined,
    DateTime? startedAt,
    DateTime? finishedAt = const _is.$UndefinedDateTime(),
    _irhmnpec.SdeImportOutcome? outcome,
    Object? reason = _Undefined,
    Map<String, int>? fileCounts = const _is.$UndefinedMap<String, int>(),
    int? fileCount,
    bool? fileCountsCutOff,
  }) {
    return StaticDataImportStatus(
      build: build is int? ? build : this.build,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt is _is.UndefinedSentinel
          ? this.finishedAt
          : finishedAt,
      outcome: outcome ?? this.outcome,
      reason: reason is _iqdx9nyu.PublicReason? ? reason : this.reason,
      fileCounts: fileCounts is _is.UndefinedSentinel
          ? this.fileCounts?.map((key0, value0) => MapEntry(key0, value0))
          : fileCounts,
      fileCount: fileCount ?? this.fileCount,
      fileCountsCutOff: fileCountsCutOff ?? this.fileCountsCutOff,
    );
  }
}
