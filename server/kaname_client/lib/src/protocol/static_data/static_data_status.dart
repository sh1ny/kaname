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

import '../static_data/setting_revision.dart' as _il5o3xgp;
import '../static_data/static_data_ccp_latest.dart' as _ij6w9u6q;
import '../static_data/static_data_check_status.dart' as _iu10hvva;
import '../static_data/static_data_diff_status.dart' as _id9zqsex;
import '../static_data/static_data_import_status.dart' as _i6d1acwi;
import '../static_data/static_data_switch_status.dart' as _ijhkszaj;

/// A safe snapshot of stored static-data state (D2, D15).
abstract class StaticDataStatus
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  StaticDataStatus._({
    this.activeBuild,
    this.previousBuild,
    this.stagedBuild,
    this.heldBuild,
    required this.buildRevision,
    required this.settingRevision,
    required this.autoUpdate,
    required this.busy,
    required this.adminConfigured,
    required this.workerStuck,
    required this.settlementStuck,
    required this.recoveryStuck,
    required this.startupStuck,
    this.ccpLatest,
    this.latestCheck,
    this.latestImport,
    this.latestSwitch,
    this.latestDiff,
  });

  factory StaticDataStatus({
    int? activeBuild,
    int? previousBuild,
    int? stagedBuild,
    int? heldBuild,
    required int buildRevision,
    required _il5o3xgp.SettingRevision settingRevision,
    required bool autoUpdate,
    required bool busy,
    required bool adminConfigured,
    required bool workerStuck,
    required bool settlementStuck,
    required bool recoveryStuck,
    required bool startupStuck,
    _ij6w9u6q.StaticDataCcpLatest? ccpLatest,
    _iu10hvva.StaticDataCheckStatus? latestCheck,
    _i6d1acwi.StaticDataImportStatus? latestImport,
    _ijhkszaj.StaticDataSwitchStatus? latestSwitch,
    _id9zqsex.StaticDataDiffStatus? latestDiff,
  }) = _StaticDataStatusImpl;

  factory StaticDataStatus.fromJson(Map<String, dynamic> jsonSerialization) {
    return StaticDataStatus(
      activeBuild: jsonSerialization['activeBuild'] as int?,
      previousBuild: jsonSerialization['previousBuild'] as int?,
      stagedBuild: jsonSerialization['stagedBuild'] as int?,
      heldBuild: jsonSerialization['heldBuild'] as int?,
      buildRevision: jsonSerialization['buildRevision'] as int,
      settingRevision: _i7wvxdxe.Protocol()
          .deserialize<_il5o3xgp.SettingRevision>(
            jsonSerialization['settingRevision'],
          ),
      autoUpdate: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['autoUpdate'],
      ),
      busy: _isc.BoolJsonExtension.fromJson(jsonSerialization['busy']),
      adminConfigured: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['adminConfigured'],
      ),
      workerStuck: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['workerStuck'],
      ),
      settlementStuck: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['settlementStuck'],
      ),
      recoveryStuck: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['recoveryStuck'],
      ),
      startupStuck: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['startupStuck'],
      ),
      ccpLatest: jsonSerialization['ccpLatest'] == null
          ? null
          : _i7wvxdxe.Protocol().deserialize<_ij6w9u6q.StaticDataCcpLatest>(
              jsonSerialization['ccpLatest'],
            ),
      latestCheck: jsonSerialization['latestCheck'] == null
          ? null
          : _i7wvxdxe.Protocol().deserialize<_iu10hvva.StaticDataCheckStatus>(
              jsonSerialization['latestCheck'],
            ),
      latestImport: jsonSerialization['latestImport'] == null
          ? null
          : _i7wvxdxe.Protocol().deserialize<_i6d1acwi.StaticDataImportStatus>(
              jsonSerialization['latestImport'],
            ),
      latestSwitch: jsonSerialization['latestSwitch'] == null
          ? null
          : _i7wvxdxe.Protocol().deserialize<_ijhkszaj.StaticDataSwitchStatus>(
              jsonSerialization['latestSwitch'],
            ),
      latestDiff: jsonSerialization['latestDiff'] == null
          ? null
          : _i7wvxdxe.Protocol().deserialize<_id9zqsex.StaticDataDiffStatus>(
              jsonSerialization['latestDiff'],
            ),
    );
  }

  int? activeBuild;

  int? previousBuild;

  int? stagedBuild;

  int? heldBuild;

  int buildRevision;

  _il5o3xgp.SettingRevision settingRevision;

  bool autoUpdate;

  bool busy;

  bool adminConfigured;

  bool workerStuck;

  bool settlementStuck;

  bool recoveryStuck;

  bool startupStuck;

  _ij6w9u6q.StaticDataCcpLatest? ccpLatest;

  _iu10hvva.StaticDataCheckStatus? latestCheck;

  _i6d1acwi.StaticDataImportStatus? latestImport;

  _ijhkszaj.StaticDataSwitchStatus? latestSwitch;

  _id9zqsex.StaticDataDiffStatus? latestDiff;

  /// Returns a shallow copy of this [StaticDataStatus]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  StaticDataStatus copyWith({
    int? activeBuild,
    int? previousBuild,
    int? stagedBuild,
    int? heldBuild,
    int? buildRevision,
    _il5o3xgp.SettingRevision? settingRevision,
    bool? autoUpdate,
    bool? busy,
    bool? adminConfigured,
    bool? workerStuck,
    bool? settlementStuck,
    bool? recoveryStuck,
    bool? startupStuck,
    _ij6w9u6q.StaticDataCcpLatest? ccpLatest =
        const _UndefinedStaticDataStatus$ccpLatest(),
    _iu10hvva.StaticDataCheckStatus? latestCheck =
        const _UndefinedStaticDataStatus$latestCheck(),
    _i6d1acwi.StaticDataImportStatus? latestImport =
        const _UndefinedStaticDataStatus$latestImport(),
    _ijhkszaj.StaticDataSwitchStatus? latestSwitch =
        const _UndefinedStaticDataStatus$latestSwitch(),
    _id9zqsex.StaticDataDiffStatus? latestDiff =
        const _UndefinedStaticDataStatus$latestDiff(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StaticDataStatus',
      if (activeBuild != null) 'activeBuild': activeBuild,
      if (previousBuild != null) 'previousBuild': previousBuild,
      if (stagedBuild != null) 'stagedBuild': stagedBuild,
      if (heldBuild != null) 'heldBuild': heldBuild,
      'buildRevision': buildRevision,
      'settingRevision': settingRevision.toJson(),
      'autoUpdate': autoUpdate,
      'busy': busy,
      'adminConfigured': adminConfigured,
      'workerStuck': workerStuck,
      'settlementStuck': settlementStuck,
      'recoveryStuck': recoveryStuck,
      'startupStuck': startupStuck,
      if (ccpLatest != null) 'ccpLatest': ccpLatest?.toJson(),
      if (latestCheck != null) 'latestCheck': latestCheck?.toJson(),
      if (latestImport != null) 'latestImport': latestImport?.toJson(),
      if (latestSwitch != null) 'latestSwitch': latestSwitch?.toJson(),
      if (latestDiff != null) 'latestDiff': latestDiff?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StaticDataStatus',
      if (activeBuild != null) 'activeBuild': activeBuild,
      if (previousBuild != null) 'previousBuild': previousBuild,
      if (stagedBuild != null) 'stagedBuild': stagedBuild,
      if (heldBuild != null) 'heldBuild': heldBuild,
      'buildRevision': buildRevision,
      'settingRevision': settingRevision.toJsonForProtocol(),
      'autoUpdate': autoUpdate,
      'busy': busy,
      'adminConfigured': adminConfigured,
      'workerStuck': workerStuck,
      'settlementStuck': settlementStuck,
      'recoveryStuck': recoveryStuck,
      'startupStuck': startupStuck,
      if (ccpLatest != null) 'ccpLatest': ccpLatest?.toJsonForProtocol(),
      if (latestCheck != null) 'latestCheck': latestCheck?.toJsonForProtocol(),
      if (latestImport != null)
        'latestImport': latestImport?.toJsonForProtocol(),
      if (latestSwitch != null)
        'latestSwitch': latestSwitch?.toJsonForProtocol(),
      if (latestDiff != null) 'latestDiff': latestDiff?.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedStaticDataStatus$ccpLatest extends _isc.UndefinedSentinel
    implements _ij6w9u6q.StaticDataCcpLatest {
  const _UndefinedStaticDataStatus$ccpLatest();
}

class _UndefinedStaticDataStatus$latestCheck extends _isc.UndefinedSentinel
    implements _iu10hvva.StaticDataCheckStatus {
  const _UndefinedStaticDataStatus$latestCheck();
}

class _UndefinedStaticDataStatus$latestImport extends _isc.UndefinedSentinel
    implements _i6d1acwi.StaticDataImportStatus {
  const _UndefinedStaticDataStatus$latestImport();
}

class _UndefinedStaticDataStatus$latestSwitch extends _isc.UndefinedSentinel
    implements _ijhkszaj.StaticDataSwitchStatus {
  const _UndefinedStaticDataStatus$latestSwitch();
}

class _UndefinedStaticDataStatus$latestDiff extends _isc.UndefinedSentinel
    implements _id9zqsex.StaticDataDiffStatus {
  const _UndefinedStaticDataStatus$latestDiff();
}

class _StaticDataStatusImpl extends StaticDataStatus {
  _StaticDataStatusImpl({
    int? activeBuild,
    int? previousBuild,
    int? stagedBuild,
    int? heldBuild,
    required int buildRevision,
    required _il5o3xgp.SettingRevision settingRevision,
    required bool autoUpdate,
    required bool busy,
    required bool adminConfigured,
    required bool workerStuck,
    required bool settlementStuck,
    required bool recoveryStuck,
    required bool startupStuck,
    _ij6w9u6q.StaticDataCcpLatest? ccpLatest,
    _iu10hvva.StaticDataCheckStatus? latestCheck,
    _i6d1acwi.StaticDataImportStatus? latestImport,
    _ijhkszaj.StaticDataSwitchStatus? latestSwitch,
    _id9zqsex.StaticDataDiffStatus? latestDiff,
  }) : super._(
         activeBuild: activeBuild,
         previousBuild: previousBuild,
         stagedBuild: stagedBuild,
         heldBuild: heldBuild,
         buildRevision: buildRevision,
         settingRevision: settingRevision,
         autoUpdate: autoUpdate,
         busy: busy,
         adminConfigured: adminConfigured,
         workerStuck: workerStuck,
         settlementStuck: settlementStuck,
         recoveryStuck: recoveryStuck,
         startupStuck: startupStuck,
         ccpLatest: ccpLatest,
         latestCheck: latestCheck,
         latestImport: latestImport,
         latestSwitch: latestSwitch,
         latestDiff: latestDiff,
       );

  /// Returns a shallow copy of this [StaticDataStatus]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  StaticDataStatus copyWith({
    Object? activeBuild = _Undefined,
    Object? previousBuild = _Undefined,
    Object? stagedBuild = _Undefined,
    Object? heldBuild = _Undefined,
    int? buildRevision,
    _il5o3xgp.SettingRevision? settingRevision,
    bool? autoUpdate,
    bool? busy,
    bool? adminConfigured,
    bool? workerStuck,
    bool? settlementStuck,
    bool? recoveryStuck,
    bool? startupStuck,
    _ij6w9u6q.StaticDataCcpLatest? ccpLatest =
        const _UndefinedStaticDataStatus$ccpLatest(),
    _iu10hvva.StaticDataCheckStatus? latestCheck =
        const _UndefinedStaticDataStatus$latestCheck(),
    _i6d1acwi.StaticDataImportStatus? latestImport =
        const _UndefinedStaticDataStatus$latestImport(),
    _ijhkszaj.StaticDataSwitchStatus? latestSwitch =
        const _UndefinedStaticDataStatus$latestSwitch(),
    _id9zqsex.StaticDataDiffStatus? latestDiff =
        const _UndefinedStaticDataStatus$latestDiff(),
  }) {
    return StaticDataStatus(
      activeBuild: activeBuild is int? ? activeBuild : this.activeBuild,
      previousBuild: previousBuild is int? ? previousBuild : this.previousBuild,
      stagedBuild: stagedBuild is int? ? stagedBuild : this.stagedBuild,
      heldBuild: heldBuild is int? ? heldBuild : this.heldBuild,
      buildRevision: buildRevision ?? this.buildRevision,
      settingRevision: settingRevision ?? this.settingRevision.copyWith(),
      autoUpdate: autoUpdate ?? this.autoUpdate,
      busy: busy ?? this.busy,
      adminConfigured: adminConfigured ?? this.adminConfigured,
      workerStuck: workerStuck ?? this.workerStuck,
      settlementStuck: settlementStuck ?? this.settlementStuck,
      recoveryStuck: recoveryStuck ?? this.recoveryStuck,
      startupStuck: startupStuck ?? this.startupStuck,
      ccpLatest: ccpLatest is _isc.UndefinedSentinel
          ? this.ccpLatest?.copyWith()
          : ccpLatest,
      latestCheck: latestCheck is _isc.UndefinedSentinel
          ? this.latestCheck?.copyWith()
          : latestCheck,
      latestImport: latestImport is _isc.UndefinedSentinel
          ? this.latestImport?.copyWith()
          : latestImport,
      latestSwitch: latestSwitch is _isc.UndefinedSentinel
          ? this.latestSwitch?.copyWith()
          : latestSwitch,
      latestDiff: latestDiff is _isc.UndefinedSentinel
          ? this.latestDiff?.copyWith()
          : latestDiff,
    );
  }
}
