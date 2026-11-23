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

import '../static_data/public_reason.dart' as _iqdx9nyu;
import '../static_data/static_data_report_file.dart' as _ik25vhmk;
import '../static_data/static_data_report_outcome.dart' as _i86spcr4;

/// Public change-report answer; failure reasons never contain stored text (D15).
abstract class StaticDataChangeReport
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  StaticDataChangeReport._({
    required this.outcome,
    this.activeBuild,
    this.fromBuild,
    this.toBuild,
    this.reason,
    this.files,
  });

  factory StaticDataChangeReport({
    required _i86spcr4.StaticDataReportOutcome outcome,
    int? activeBuild,
    int? fromBuild,
    int? toBuild,
    _iqdx9nyu.PublicReason? reason,
    List<_ik25vhmk.StaticDataReportFile>? files,
  }) = _StaticDataChangeReportImpl;

  factory StaticDataChangeReport.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return StaticDataChangeReport(
      outcome: _i86spcr4.StaticDataReportOutcome.fromJson(
        (jsonSerialization['outcome'] as String),
      ),
      activeBuild: jsonSerialization['activeBuild'] as int?,
      fromBuild: jsonSerialization['fromBuild'] as int?,
      toBuild: jsonSerialization['toBuild'] as int?,
      reason: jsonSerialization['reason'] == null
          ? null
          : _iqdx9nyu.PublicReason.fromJson(
              (jsonSerialization['reason'] as String),
            ),
      files: jsonSerialization['files'] == null
          ? null
          : _i7wvxdxe.Protocol()
                .deserialize<List<_ik25vhmk.StaticDataReportFile>>(
                  jsonSerialization['files'],
                ),
    );
  }

  _i86spcr4.StaticDataReportOutcome outcome;

  int? activeBuild;

  int? fromBuild;

  int? toBuild;

  _iqdx9nyu.PublicReason? reason;

  List<_ik25vhmk.StaticDataReportFile>? files;

  /// Returns a shallow copy of this [StaticDataChangeReport]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  StaticDataChangeReport copyWith({
    _i86spcr4.StaticDataReportOutcome? outcome,
    int? activeBuild,
    int? fromBuild,
    int? toBuild,
    _iqdx9nyu.PublicReason? reason,
    List<_ik25vhmk.StaticDataReportFile>? files =
        const _isc.$UndefinedList<_ik25vhmk.StaticDataReportFile>(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StaticDataChangeReport',
      'outcome': outcome.toJson(),
      if (activeBuild != null) 'activeBuild': activeBuild,
      if (fromBuild != null) 'fromBuild': fromBuild,
      if (toBuild != null) 'toBuild': toBuild,
      if (reason != null) 'reason': reason?.toJson(),
      if (files != null) 'files': files?.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StaticDataChangeReport',
      'outcome': outcome.toJson(),
      if (activeBuild != null) 'activeBuild': activeBuild,
      if (fromBuild != null) 'fromBuild': fromBuild,
      if (toBuild != null) 'toBuild': toBuild,
      if (reason != null) 'reason': reason?.toJson(),
      if (files != null)
        'files': files?.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _StaticDataChangeReportImpl extends StaticDataChangeReport {
  _StaticDataChangeReportImpl({
    required _i86spcr4.StaticDataReportOutcome outcome,
    int? activeBuild,
    int? fromBuild,
    int? toBuild,
    _iqdx9nyu.PublicReason? reason,
    List<_ik25vhmk.StaticDataReportFile>? files,
  }) : super._(
         outcome: outcome,
         activeBuild: activeBuild,
         fromBuild: fromBuild,
         toBuild: toBuild,
         reason: reason,
         files: files,
       );

  /// Returns a shallow copy of this [StaticDataChangeReport]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  StaticDataChangeReport copyWith({
    _i86spcr4.StaticDataReportOutcome? outcome,
    Object? activeBuild = _Undefined,
    Object? fromBuild = _Undefined,
    Object? toBuild = _Undefined,
    Object? reason = _Undefined,
    List<_ik25vhmk.StaticDataReportFile>? files =
        const _isc.$UndefinedList<_ik25vhmk.StaticDataReportFile>(),
  }) {
    return StaticDataChangeReport(
      outcome: outcome ?? this.outcome,
      activeBuild: activeBuild is int? ? activeBuild : this.activeBuild,
      fromBuild: fromBuild is int? ? fromBuild : this.fromBuild,
      toBuild: toBuild is int? ? toBuild : this.toBuild,
      reason: reason is _iqdx9nyu.PublicReason? ? reason : this.reason,
      files: files is _isc.UndefinedSentinel
          ? this.files?.map((e0) => e0.copyWith()).toList()
          : files,
    );
  }
}
