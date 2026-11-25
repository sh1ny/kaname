/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_type_check

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:kaname_core/kaname_core.dart' as _idp9h2tz;
import 'package:serverpod_client/serverpod_client.dart' as _isc;

import 'esi/esi_call_log_cursor.dart' as _iqs4md3s;
import 'esi/esi_call_log_item.dart' as _iuknwcy9;
import 'esi/esi_call_log_page.dart' as _iiojdgzp;
import 'esi/esi_route_count_item.dart' as _iy73o4xt;
import 'esi/esi_route_count_page.dart' as _ikoz4zoy;
import 'health/dependency_status.dart' as _iztepymd;
import 'health/health_report.dart' as _if75m2mz;
import 'static_data/admin_answer.dart' as _iyccfpu2;
import 'static_data/admin_answer_outcome.dart' as _i6gkafob;
import 'static_data/admin_operation_answer.dart' as _i7odid2e;
import 'static_data/admin_operation_read_state.dart' as _ibihcb51;
import 'static_data/admin_operation_view.dart' as _iduf9i0n;
import 'static_data/bundle_announcement.dart' as _iothyv29;
import 'static_data/public_reason.dart' as _i0rvs1mg;
import 'static_data/sde_admin_operation_kind.dart' as _ix7ishv7;
import 'static_data/sde_admin_operation_outcome.dart' as _iowegcqg;
import 'static_data/sde_build_diff_outcome.dart' as _iby3hddy;
import 'static_data/sde_build_state.dart' as _isyk7irp;
import 'static_data/sde_bundle_outcome.dart' as _iquqzrxf;
import 'static_data/sde_check_outcome.dart' as _illgk9kj;
import 'static_data/sde_import_outcome.dart' as _is3f4xcr;
import 'static_data/sde_import_source.dart' as _ice2slzs;
import 'static_data/sde_switch_kind.dart' as _iqktcwf1;
import 'static_data/sde_switch_outcome.dart' as _icb88h1v;
import 'static_data/setting_revision.dart' as _iotz1o7l;
import 'static_data/static_data_ccp_latest.dart' as _imfnodj2;
import 'static_data/static_data_change_report.dart' as _icn4k5zk;
import 'static_data/static_data_check_status.dart' as _i58p74ek;
import 'static_data/static_data_diff_status.dart' as _ivtfyb9n;
import 'static_data/static_data_import_status.dart' as _igmz1uai;
import 'static_data/static_data_report_changes.dart' as _i6y7rcpz;
import 'static_data/static_data_report_file.dart' as _iacxd2dw;
import 'static_data/static_data_report_file_status.dart' as _ijjljno5;
import 'static_data/static_data_report_outcome.dart' as _iixf2rnc;
import 'static_data/static_data_status.dart' as _i4ollqgk;
import 'static_data/static_data_status_unavailable.dart' as _ixbsr0c1;
import 'static_data/static_data_switch_status.dart' as _iidkva5e;
export 'esi/esi_call_log_cursor.dart';
export 'esi/esi_call_log_item.dart';
export 'esi/esi_call_log_page.dart';
export 'esi/esi_route_count_item.dart';
export 'esi/esi_route_count_page.dart';
export 'health/dependency_status.dart';
export 'health/health_report.dart';
export 'static_data/admin_answer.dart';
export 'static_data/admin_answer_outcome.dart';
export 'static_data/admin_operation_answer.dart';
export 'static_data/admin_operation_read_state.dart';
export 'static_data/admin_operation_view.dart';
export 'static_data/bundle_announcement.dart';
export 'static_data/public_reason.dart';
export 'static_data/sde_admin_operation_kind.dart';
export 'static_data/sde_admin_operation_outcome.dart';
export 'static_data/sde_build_diff_outcome.dart';
export 'static_data/sde_build_state.dart';
export 'static_data/sde_bundle_outcome.dart';
export 'static_data/sde_check_outcome.dart';
export 'static_data/sde_import_outcome.dart';
export 'static_data/sde_import_source.dart';
export 'static_data/sde_switch_kind.dart';
export 'static_data/sde_switch_outcome.dart';
export 'static_data/setting_revision.dart';
export 'static_data/static_data_ccp_latest.dart';
export 'static_data/static_data_change_report.dart';
export 'static_data/static_data_check_status.dart';
export 'static_data/static_data_diff_status.dart';
export 'static_data/static_data_import_status.dart';
export 'static_data/static_data_report_changes.dart';
export 'static_data/static_data_report_file.dart';
export 'static_data/static_data_report_file_status.dart';
export 'static_data/static_data_report_outcome.dart';
export 'static_data/static_data_status.dart';
export 'static_data/static_data_status_unavailable.dart';
export 'static_data/static_data_switch_status.dart';
export 'client.dart';

class Protocol extends _isc.SerializationManager
    implements _isc.ProtocolDeserializationProvider {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  @override
  _isc.ProtocolDeserialization get deserializationMetadata =>
      _isc.ProtocolDeserialization.cached(
        this,
        types: const [
          _isc.getType<_iqs4md3s.EsiCallLogCursor>,
          _isc.getType<_iuknwcy9.EsiCallLogReceipt>,
          _isc.getType<_iiojdgzp.EsiCallLogPage>,
          _isc.getType<_iy73o4xt.EsiRouteCount>,
          _isc.getType<_ikoz4zoy.EsiRouteCountPage>,
          _isc.getType<_iztepymd.DependencyStatus>,
          _isc.getType<_if75m2mz.HealthReport>,
          _isc.getType<_iyccfpu2.AdminAnswer>,
          _isc.getType<_i6gkafob.AdminAnswerOutcome>,
          _isc.getType<_i7odid2e.AdminOperationAnswer>,
          _isc.getType<_ibihcb51.AdminOperationReadState>,
          _isc.getType<_iduf9i0n.AdminOperationView>,
          _isc.getType<_iothyv29.BundleAnnouncementNamed>,
          _isc.getType<_iothyv29.BundleAnnouncementNone>,
          _isc.getType<_iotz1o7l.NoWrites>,
          _isc.getType<_i0rvs1mg.PublicReason>,
          _isc.getType<_ix7ishv7.SdeAdminOperationKind>,
          _isc.getType<_iowegcqg.SdeAdminOperationOutcome>,
          _isc.getType<_iby3hddy.SdeBuildDiffOutcome>,
          _isc.getType<_isyk7irp.SdeBuildState>,
          _isc.getType<_iquqzrxf.SdeBundleOutcome>,
          _isc.getType<_illgk9kj.SdeCheckOutcome>,
          _isc.getType<_is3f4xcr.SdeImportOutcome>,
          _isc.getType<_ice2slzs.SdeImportSource>,
          _isc.getType<_iqktcwf1.SdeSwitchKind>,
          _isc.getType<_icb88h1v.SdeSwitchOutcome>,
          _isc.getType<_iotz1o7l.WriteRevision>,
          _isc.getType<_imfnodj2.StaticDataCcpLatest>,
          _isc.getType<_icn4k5zk.StaticDataChangeReport>,
          _isc.getType<_i58p74ek.StaticDataCheckStatus>,
          _isc.getType<_ivtfyb9n.StaticDataDiffStatus>,
          _isc.getType<_igmz1uai.StaticDataImportStatus>,
          _isc.getType<_i6y7rcpz.StaticDataReportChanges>,
          _isc.getType<_iacxd2dw.StaticDataReportFile>,
          _isc.getType<_ijjljno5.StaticDataReportFileStatus>,
          _isc.getType<_iixf2rnc.StaticDataReportOutcome>,
          _isc.getType<_i4ollqgk.StaticDataStatus>,
          _isc.getType<_ixbsr0c1.StaticDataStatusUnavailable>,
          _isc.getType<_iidkva5e.StaticDataSwitchStatus>,
          _isc.getType<_iqs4md3s.EsiCallLogCursor?>,
          _isc.getType<_iuknwcy9.EsiCallLogReceipt?>,
          _isc.getType<_iiojdgzp.EsiCallLogPage?>,
          _isc.getType<_iy73o4xt.EsiRouteCount?>,
          _isc.getType<_ikoz4zoy.EsiRouteCountPage?>,
          _isc.getType<_iztepymd.DependencyStatus?>,
          _isc.getType<_if75m2mz.HealthReport?>,
          _isc.getType<_iyccfpu2.AdminAnswer?>,
          _isc.getType<_i6gkafob.AdminAnswerOutcome?>,
          _isc.getType<_i7odid2e.AdminOperationAnswer?>,
          _isc.getType<_ibihcb51.AdminOperationReadState?>,
          _isc.getType<_iduf9i0n.AdminOperationView?>,
          _isc.getType<_iothyv29.BundleAnnouncementNamed?>,
          _isc.getType<_iothyv29.BundleAnnouncementNone?>,
          _isc.getType<_iotz1o7l.NoWrites?>,
          _isc.getType<_i0rvs1mg.PublicReason?>,
          _isc.getType<_ix7ishv7.SdeAdminOperationKind?>,
          _isc.getType<_iowegcqg.SdeAdminOperationOutcome?>,
          _isc.getType<_iby3hddy.SdeBuildDiffOutcome?>,
          _isc.getType<_isyk7irp.SdeBuildState?>,
          _isc.getType<_iquqzrxf.SdeBundleOutcome?>,
          _isc.getType<_illgk9kj.SdeCheckOutcome?>,
          _isc.getType<_is3f4xcr.SdeImportOutcome?>,
          _isc.getType<_ice2slzs.SdeImportSource?>,
          _isc.getType<_iqktcwf1.SdeSwitchKind?>,
          _isc.getType<_icb88h1v.SdeSwitchOutcome?>,
          _isc.getType<_iotz1o7l.WriteRevision?>,
          _isc.getType<_imfnodj2.StaticDataCcpLatest?>,
          _isc.getType<_icn4k5zk.StaticDataChangeReport?>,
          _isc.getType<_i58p74ek.StaticDataCheckStatus?>,
          _isc.getType<_ivtfyb9n.StaticDataDiffStatus?>,
          _isc.getType<_igmz1uai.StaticDataImportStatus?>,
          _isc.getType<_i6y7rcpz.StaticDataReportChanges?>,
          _isc.getType<_iacxd2dw.StaticDataReportFile?>,
          _isc.getType<_ijjljno5.StaticDataReportFileStatus?>,
          _isc.getType<_iixf2rnc.StaticDataReportOutcome?>,
          _isc.getType<_i4ollqgk.StaticDataStatus?>,
          _isc.getType<_ixbsr0c1.StaticDataStatusUnavailable?>,
          _isc.getType<_iidkva5e.StaticDataSwitchStatus?>,
          _isc.getType<List<_iuknwcy9.EsiCallLogReceipt>>,
          _isc.getType<List<_iy73o4xt.EsiRouteCount>>,
          _isc.getType<List<_iacxd2dw.StaticDataReportFile>>,
          _isc.getType<List<_iacxd2dw.StaticDataReportFile>?>,
          _isc.getType<Map<String, int>>,
          _isc.getType<Map<String, int>?>,
          _isc.getType<List<String>>,
          _isc.getType<_idp9h2tz.SdeJson>,
          _isc.getType<_idp9h2tz.SdeJson?>,
        ],
        modules: const [],
        classNames: const [
          'SdeJson',
          'EsiCallLogCursor',
          'EsiCallLogReceipt',
          'EsiCallLogPage',
          'EsiRouteCount',
          'EsiRouteCountPage',
          'DependencyStatus',
          'HealthReport',
          'AdminAnswer',
          'AdminAnswerOutcome',
          'AdminOperationAnswer',
          'AdminOperationReadState',
          'AdminOperationView',
          'BundleAnnouncementNamed',
          'BundleAnnouncementNone',
          'NoWrites',
          'PublicReason',
          'SdeAdminOperationKind',
          'SdeAdminOperationOutcome',
          'SdeBuildDiffOutcome',
          'SdeBuildState',
          'SdeBundleOutcome',
          'SdeCheckOutcome',
          'SdeImportOutcome',
          'SdeImportSource',
          'SdeSwitchKind',
          'SdeSwitchOutcome',
          'WriteRevision',
          'StaticDataCcpLatest',
          'StaticDataChangeReport',
          'StaticDataCheckStatus',
          'StaticDataDiffStatus',
          'StaticDataImportStatus',
          'StaticDataReportChanges',
          'StaticDataReportFile',
          'StaticDataReportFileStatus',
          'StaticDataReportOutcome',
          'StaticDataStatus',
          'StaticDataStatusUnavailable',
          'StaticDataSwitchStatus',
        ],
      );

  static String? getClassNameFromObjectJson(dynamic data) =>
      _isc.ProtocolDeserialization.readClassName(data);

  @override
  T deserialize<T>(dynamic data, [Type? t]) {
    t ??= T;
    final rawDataClassName = _isc.ProtocolDeserialization.readClassName(data);
    final dataClassName = rawDataClassName;
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on _isc.DeserializationClassNameNotFoundException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _iqs4md3s.EsiCallLogCursor) {
      return _iqs4md3s.EsiCallLogCursor.fromJson(data) as T;
    }
    if (t == _iuknwcy9.EsiCallLogReceipt) {
      return _iuknwcy9.EsiCallLogReceipt.fromJson(data) as T;
    }
    if (t == _iiojdgzp.EsiCallLogPage) {
      return _iiojdgzp.EsiCallLogPage.fromJson(data) as T;
    }
    if (t == _iy73o4xt.EsiRouteCount) {
      return _iy73o4xt.EsiRouteCount.fromJson(data) as T;
    }
    if (t == _ikoz4zoy.EsiRouteCountPage) {
      return _ikoz4zoy.EsiRouteCountPage.fromJson(data) as T;
    }
    if (t == _iztepymd.DependencyStatus) {
      return _iztepymd.DependencyStatus.fromJson(data) as T;
    }
    if (t == _if75m2mz.HealthReport) {
      return _if75m2mz.HealthReport.fromJson(data) as T;
    }
    if (t == _iyccfpu2.AdminAnswer) {
      return _iyccfpu2.AdminAnswer.fromJson(data) as T;
    }
    if (t == _i6gkafob.AdminAnswerOutcome) {
      return _i6gkafob.AdminAnswerOutcome.fromJson(data) as T;
    }
    if (t == _i7odid2e.AdminOperationAnswer) {
      return _i7odid2e.AdminOperationAnswer.fromJson(data) as T;
    }
    if (t == _ibihcb51.AdminOperationReadState) {
      return _ibihcb51.AdminOperationReadState.fromJson(data) as T;
    }
    if (t == _iduf9i0n.AdminOperationView) {
      return _iduf9i0n.AdminOperationView.fromJson(data) as T;
    }
    if (t == _iothyv29.BundleAnnouncementNamed) {
      return _iothyv29.BundleAnnouncementNamed.fromJson(data) as T;
    }
    if (t == _iothyv29.BundleAnnouncementNone) {
      return _iothyv29.BundleAnnouncementNone.fromJson(data) as T;
    }
    if (t == _iotz1o7l.NoWrites) {
      return _iotz1o7l.NoWrites.fromJson(data) as T;
    }
    if (t == _i0rvs1mg.PublicReason) {
      return _i0rvs1mg.PublicReason.fromJson(data) as T;
    }
    if (t == _ix7ishv7.SdeAdminOperationKind) {
      return _ix7ishv7.SdeAdminOperationKind.fromJson(data) as T;
    }
    if (t == _iowegcqg.SdeAdminOperationOutcome) {
      return _iowegcqg.SdeAdminOperationOutcome.fromJson(data) as T;
    }
    if (t == _iby3hddy.SdeBuildDiffOutcome) {
      return _iby3hddy.SdeBuildDiffOutcome.fromJson(data) as T;
    }
    if (t == _isyk7irp.SdeBuildState) {
      return _isyk7irp.SdeBuildState.fromJson(data) as T;
    }
    if (t == _iquqzrxf.SdeBundleOutcome) {
      return _iquqzrxf.SdeBundleOutcome.fromJson(data) as T;
    }
    if (t == _illgk9kj.SdeCheckOutcome) {
      return _illgk9kj.SdeCheckOutcome.fromJson(data) as T;
    }
    if (t == _is3f4xcr.SdeImportOutcome) {
      return _is3f4xcr.SdeImportOutcome.fromJson(data) as T;
    }
    if (t == _ice2slzs.SdeImportSource) {
      return _ice2slzs.SdeImportSource.fromJson(data) as T;
    }
    if (t == _iqktcwf1.SdeSwitchKind) {
      return _iqktcwf1.SdeSwitchKind.fromJson(data) as T;
    }
    if (t == _icb88h1v.SdeSwitchOutcome) {
      return _icb88h1v.SdeSwitchOutcome.fromJson(data) as T;
    }
    if (t == _iotz1o7l.WriteRevision) {
      return _iotz1o7l.WriteRevision.fromJson(data) as T;
    }
    if (t == _imfnodj2.StaticDataCcpLatest) {
      return _imfnodj2.StaticDataCcpLatest.fromJson(data) as T;
    }
    if (t == _icn4k5zk.StaticDataChangeReport) {
      return _icn4k5zk.StaticDataChangeReport.fromJson(data) as T;
    }
    if (t == _i58p74ek.StaticDataCheckStatus) {
      return _i58p74ek.StaticDataCheckStatus.fromJson(data) as T;
    }
    if (t == _ivtfyb9n.StaticDataDiffStatus) {
      return _ivtfyb9n.StaticDataDiffStatus.fromJson(data) as T;
    }
    if (t == _igmz1uai.StaticDataImportStatus) {
      return _igmz1uai.StaticDataImportStatus.fromJson(data) as T;
    }
    if (t == _i6y7rcpz.StaticDataReportChanges) {
      return _i6y7rcpz.StaticDataReportChanges.fromJson(data) as T;
    }
    if (t == _iacxd2dw.StaticDataReportFile) {
      return _iacxd2dw.StaticDataReportFile.fromJson(data) as T;
    }
    if (t == _ijjljno5.StaticDataReportFileStatus) {
      return _ijjljno5.StaticDataReportFileStatus.fromJson(data) as T;
    }
    if (t == _iixf2rnc.StaticDataReportOutcome) {
      return _iixf2rnc.StaticDataReportOutcome.fromJson(data) as T;
    }
    if (t == _i4ollqgk.StaticDataStatus) {
      return _i4ollqgk.StaticDataStatus.fromJson(data) as T;
    }
    if (t == _ixbsr0c1.StaticDataStatusUnavailable) {
      return _ixbsr0c1.StaticDataStatusUnavailable.fromJson(data) as T;
    }
    if (t == _iidkva5e.StaticDataSwitchStatus) {
      return _iidkva5e.StaticDataSwitchStatus.fromJson(data) as T;
    }
    if (t == _isc.getType<_iqs4md3s.EsiCallLogCursor?>()) {
      return (data != null ? _iqs4md3s.EsiCallLogCursor.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_iuknwcy9.EsiCallLogReceipt?>()) {
      return (data != null ? _iuknwcy9.EsiCallLogReceipt.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_iiojdgzp.EsiCallLogPage?>()) {
      return (data != null ? _iiojdgzp.EsiCallLogPage.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_iy73o4xt.EsiRouteCount?>()) {
      return (data != null ? _iy73o4xt.EsiRouteCount.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ikoz4zoy.EsiRouteCountPage?>()) {
      return (data != null ? _ikoz4zoy.EsiRouteCountPage.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_iztepymd.DependencyStatus?>()) {
      return (data != null ? _iztepymd.DependencyStatus.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_if75m2mz.HealthReport?>()) {
      return (data != null ? _if75m2mz.HealthReport.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_iyccfpu2.AdminAnswer?>()) {
      return (data != null ? _iyccfpu2.AdminAnswer.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i6gkafob.AdminAnswerOutcome?>()) {
      return (data != null ? _i6gkafob.AdminAnswerOutcome.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i7odid2e.AdminOperationAnswer?>()) {
      return (data != null
              ? _i7odid2e.AdminOperationAnswer.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_ibihcb51.AdminOperationReadState?>()) {
      return (data != null
              ? _ibihcb51.AdminOperationReadState.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_iduf9i0n.AdminOperationView?>()) {
      return (data != null ? _iduf9i0n.AdminOperationView.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_iothyv29.BundleAnnouncementNamed?>()) {
      return (data != null
              ? _iothyv29.BundleAnnouncementNamed.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_iothyv29.BundleAnnouncementNone?>()) {
      return (data != null
              ? _iothyv29.BundleAnnouncementNone.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_iotz1o7l.NoWrites?>()) {
      return (data != null ? _iotz1o7l.NoWrites.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i0rvs1mg.PublicReason?>()) {
      return (data != null ? _i0rvs1mg.PublicReason.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ix7ishv7.SdeAdminOperationKind?>()) {
      return (data != null
              ? _ix7ishv7.SdeAdminOperationKind.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_iowegcqg.SdeAdminOperationOutcome?>()) {
      return (data != null
              ? _iowegcqg.SdeAdminOperationOutcome.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_iby3hddy.SdeBuildDiffOutcome?>()) {
      return (data != null
              ? _iby3hddy.SdeBuildDiffOutcome.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_isyk7irp.SdeBuildState?>()) {
      return (data != null ? _isyk7irp.SdeBuildState.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_iquqzrxf.SdeBundleOutcome?>()) {
      return (data != null ? _iquqzrxf.SdeBundleOutcome.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_illgk9kj.SdeCheckOutcome?>()) {
      return (data != null ? _illgk9kj.SdeCheckOutcome.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_is3f4xcr.SdeImportOutcome?>()) {
      return (data != null ? _is3f4xcr.SdeImportOutcome.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ice2slzs.SdeImportSource?>()) {
      return (data != null ? _ice2slzs.SdeImportSource.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_iqktcwf1.SdeSwitchKind?>()) {
      return (data != null ? _iqktcwf1.SdeSwitchKind.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_icb88h1v.SdeSwitchOutcome?>()) {
      return (data != null ? _icb88h1v.SdeSwitchOutcome.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_iotz1o7l.WriteRevision?>()) {
      return (data != null ? _iotz1o7l.WriteRevision.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_imfnodj2.StaticDataCcpLatest?>()) {
      return (data != null
              ? _imfnodj2.StaticDataCcpLatest.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_icn4k5zk.StaticDataChangeReport?>()) {
      return (data != null
              ? _icn4k5zk.StaticDataChangeReport.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_i58p74ek.StaticDataCheckStatus?>()) {
      return (data != null
              ? _i58p74ek.StaticDataCheckStatus.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_ivtfyb9n.StaticDataDiffStatus?>()) {
      return (data != null
              ? _ivtfyb9n.StaticDataDiffStatus.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_igmz1uai.StaticDataImportStatus?>()) {
      return (data != null
              ? _igmz1uai.StaticDataImportStatus.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_i6y7rcpz.StaticDataReportChanges?>()) {
      return (data != null
              ? _i6y7rcpz.StaticDataReportChanges.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_iacxd2dw.StaticDataReportFile?>()) {
      return (data != null
              ? _iacxd2dw.StaticDataReportFile.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_ijjljno5.StaticDataReportFileStatus?>()) {
      return (data != null
              ? _ijjljno5.StaticDataReportFileStatus.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_iixf2rnc.StaticDataReportOutcome?>()) {
      return (data != null
              ? _iixf2rnc.StaticDataReportOutcome.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_i4ollqgk.StaticDataStatus?>()) {
      return (data != null ? _i4ollqgk.StaticDataStatus.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ixbsr0c1.StaticDataStatusUnavailable?>()) {
      return (data != null
              ? _ixbsr0c1.StaticDataStatusUnavailable.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_iidkva5e.StaticDataSwitchStatus?>()) {
      return (data != null
              ? _iidkva5e.StaticDataSwitchStatus.fromJson(data)
              : null)
          as T;
    }
    if (t == List<_iuknwcy9.EsiCallLogReceipt>) {
      return (data as List)
              .map((e) => deserialize<_iuknwcy9.EsiCallLogReceipt>(e))
              .toList()
          as T;
    }
    if (t == List<_iy73o4xt.EsiRouteCount>) {
      return (data as List)
              .map((e) => deserialize<_iy73o4xt.EsiRouteCount>(e))
              .toList()
          as T;
    }
    if (t == List<_iacxd2dw.StaticDataReportFile>) {
      return (data as List)
              .map((e) => deserialize<_iacxd2dw.StaticDataReportFile>(e))
              .toList()
          as T;
    }
    if (t == _isc.getType<List<_iacxd2dw.StaticDataReportFile>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_iacxd2dw.StaticDataReportFile>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == Map<String, int>) {
      return (data as Map).map(
        (k, v) => MapEntry(deserialize<String>(k), deserialize<int>(v)),
      ) as T;
    }
    if (t == _isc.getType<Map<String, int>?>()) {
      return (data != null
              ? (data as Map).map(
                  (k, v) =>
                      MapEntry(deserialize<String>(k), deserialize<int>(v)),
                )
              : null)
          as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == _idp9h2tz.SdeJson) {
      return _idp9h2tz.SdeJson.fromJson(data) as T;
    }
    if (t == _isc.getType<_idp9h2tz.SdeJson?>()) {
      return (data != null ? _idp9h2tz.SdeJson.fromJson(data) : null) as T;
    }
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _idp9h2tz.SdeJson => 'SdeJson',
      _iqs4md3s.EsiCallLogCursor => 'EsiCallLogCursor',
      _iuknwcy9.EsiCallLogReceipt => 'EsiCallLogReceipt',
      _iiojdgzp.EsiCallLogPage => 'EsiCallLogPage',
      _iy73o4xt.EsiRouteCount => 'EsiRouteCount',
      _ikoz4zoy.EsiRouteCountPage => 'EsiRouteCountPage',
      _iztepymd.DependencyStatus => 'DependencyStatus',
      _if75m2mz.HealthReport => 'HealthReport',
      _iyccfpu2.AdminAnswer => 'AdminAnswer',
      _i6gkafob.AdminAnswerOutcome => 'AdminAnswerOutcome',
      _i7odid2e.AdminOperationAnswer => 'AdminOperationAnswer',
      _ibihcb51.AdminOperationReadState => 'AdminOperationReadState',
      _iduf9i0n.AdminOperationView => 'AdminOperationView',
      _iothyv29.BundleAnnouncementNamed => 'BundleAnnouncementNamed',
      _iothyv29.BundleAnnouncementNone => 'BundleAnnouncementNone',
      _iotz1o7l.NoWrites => 'NoWrites',
      _i0rvs1mg.PublicReason => 'PublicReason',
      _ix7ishv7.SdeAdminOperationKind => 'SdeAdminOperationKind',
      _iowegcqg.SdeAdminOperationOutcome => 'SdeAdminOperationOutcome',
      _iby3hddy.SdeBuildDiffOutcome => 'SdeBuildDiffOutcome',
      _isyk7irp.SdeBuildState => 'SdeBuildState',
      _iquqzrxf.SdeBundleOutcome => 'SdeBundleOutcome',
      _illgk9kj.SdeCheckOutcome => 'SdeCheckOutcome',
      _is3f4xcr.SdeImportOutcome => 'SdeImportOutcome',
      _ice2slzs.SdeImportSource => 'SdeImportSource',
      _iqktcwf1.SdeSwitchKind => 'SdeSwitchKind',
      _icb88h1v.SdeSwitchOutcome => 'SdeSwitchOutcome',
      _iotz1o7l.WriteRevision => 'WriteRevision',
      _imfnodj2.StaticDataCcpLatest => 'StaticDataCcpLatest',
      _icn4k5zk.StaticDataChangeReport => 'StaticDataChangeReport',
      _i58p74ek.StaticDataCheckStatus => 'StaticDataCheckStatus',
      _ivtfyb9n.StaticDataDiffStatus => 'StaticDataDiffStatus',
      _igmz1uai.StaticDataImportStatus => 'StaticDataImportStatus',
      _i6y7rcpz.StaticDataReportChanges => 'StaticDataReportChanges',
      _iacxd2dw.StaticDataReportFile => 'StaticDataReportFile',
      _ijjljno5.StaticDataReportFileStatus => 'StaticDataReportFileStatus',
      _iixf2rnc.StaticDataReportOutcome => 'StaticDataReportOutcome',
      _i4ollqgk.StaticDataStatus => 'StaticDataStatus',
      _ixbsr0c1.StaticDataStatusUnavailable => 'StaticDataStatusUnavailable',
      _iidkva5e.StaticDataSwitchStatus => 'StaticDataSwitchStatus',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst('kaname.', '');
    }

    switch (data) {
      case _idp9h2tz.SdeJson():
        return 'SdeJson';
      case _iqs4md3s.EsiCallLogCursor():
        return 'EsiCallLogCursor';
      case _iuknwcy9.EsiCallLogReceipt():
        return 'EsiCallLogReceipt';
      case _iiojdgzp.EsiCallLogPage():
        return 'EsiCallLogPage';
      case _iy73o4xt.EsiRouteCount():
        return 'EsiRouteCount';
      case _ikoz4zoy.EsiRouteCountPage():
        return 'EsiRouteCountPage';
      case _iztepymd.DependencyStatus():
        return 'DependencyStatus';
      case _if75m2mz.HealthReport():
        return 'HealthReport';
      case _iyccfpu2.AdminAnswer():
        return 'AdminAnswer';
      case _i6gkafob.AdminAnswerOutcome():
        return 'AdminAnswerOutcome';
      case _i7odid2e.AdminOperationAnswer():
        return 'AdminOperationAnswer';
      case _ibihcb51.AdminOperationReadState():
        return 'AdminOperationReadState';
      case _iduf9i0n.AdminOperationView():
        return 'AdminOperationView';
      case _iothyv29.BundleAnnouncementNamed():
        return 'BundleAnnouncementNamed';
      case _iothyv29.BundleAnnouncementNone():
        return 'BundleAnnouncementNone';
      case _iotz1o7l.NoWrites():
        return 'NoWrites';
      case _i0rvs1mg.PublicReason():
        return 'PublicReason';
      case _ix7ishv7.SdeAdminOperationKind():
        return 'SdeAdminOperationKind';
      case _iowegcqg.SdeAdminOperationOutcome():
        return 'SdeAdminOperationOutcome';
      case _iby3hddy.SdeBuildDiffOutcome():
        return 'SdeBuildDiffOutcome';
      case _isyk7irp.SdeBuildState():
        return 'SdeBuildState';
      case _iquqzrxf.SdeBundleOutcome():
        return 'SdeBundleOutcome';
      case _illgk9kj.SdeCheckOutcome():
        return 'SdeCheckOutcome';
      case _is3f4xcr.SdeImportOutcome():
        return 'SdeImportOutcome';
      case _ice2slzs.SdeImportSource():
        return 'SdeImportSource';
      case _iqktcwf1.SdeSwitchKind():
        return 'SdeSwitchKind';
      case _icb88h1v.SdeSwitchOutcome():
        return 'SdeSwitchOutcome';
      case _iotz1o7l.WriteRevision():
        return 'WriteRevision';
      case _imfnodj2.StaticDataCcpLatest():
        return 'StaticDataCcpLatest';
      case _icn4k5zk.StaticDataChangeReport():
        return 'StaticDataChangeReport';
      case _i58p74ek.StaticDataCheckStatus():
        return 'StaticDataCheckStatus';
      case _ivtfyb9n.StaticDataDiffStatus():
        return 'StaticDataDiffStatus';
      case _igmz1uai.StaticDataImportStatus():
        return 'StaticDataImportStatus';
      case _i6y7rcpz.StaticDataReportChanges():
        return 'StaticDataReportChanges';
      case _iacxd2dw.StaticDataReportFile():
        return 'StaticDataReportFile';
      case _ijjljno5.StaticDataReportFileStatus():
        return 'StaticDataReportFileStatus';
      case _iixf2rnc.StaticDataReportOutcome():
        return 'StaticDataReportOutcome';
      case _i4ollqgk.StaticDataStatus():
        return 'StaticDataStatus';
      case _ixbsr0c1.StaticDataStatusUnavailable():
        return 'StaticDataStatusUnavailable';
      case _iidkva5e.StaticDataSwitchStatus():
        return 'StaticDataSwitchStatus';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'SdeJson') {
      return deserialize<_idp9h2tz.SdeJson>(data['data']);
    }
    if (dataClassName == 'EsiCallLogCursor') {
      return deserialize<_iqs4md3s.EsiCallLogCursor>(data['data']);
    }
    if (dataClassName == 'EsiCallLogReceipt') {
      return deserialize<_iuknwcy9.EsiCallLogReceipt>(data['data']);
    }
    if (dataClassName == 'EsiCallLogPage') {
      return deserialize<_iiojdgzp.EsiCallLogPage>(data['data']);
    }
    if (dataClassName == 'EsiRouteCount') {
      return deserialize<_iy73o4xt.EsiRouteCount>(data['data']);
    }
    if (dataClassName == 'EsiRouteCountPage') {
      return deserialize<_ikoz4zoy.EsiRouteCountPage>(data['data']);
    }
    if (dataClassName == 'DependencyStatus') {
      return deserialize<_iztepymd.DependencyStatus>(data['data']);
    }
    if (dataClassName == 'HealthReport') {
      return deserialize<_if75m2mz.HealthReport>(data['data']);
    }
    if (dataClassName == 'AdminAnswer') {
      return deserialize<_iyccfpu2.AdminAnswer>(data['data']);
    }
    if (dataClassName == 'AdminAnswerOutcome') {
      return deserialize<_i6gkafob.AdminAnswerOutcome>(data['data']);
    }
    if (dataClassName == 'AdminOperationAnswer') {
      return deserialize<_i7odid2e.AdminOperationAnswer>(data['data']);
    }
    if (dataClassName == 'AdminOperationReadState') {
      return deserialize<_ibihcb51.AdminOperationReadState>(data['data']);
    }
    if (dataClassName == 'AdminOperationView') {
      return deserialize<_iduf9i0n.AdminOperationView>(data['data']);
    }
    if (dataClassName == 'BundleAnnouncementNamed') {
      return deserialize<_iothyv29.BundleAnnouncementNamed>(data['data']);
    }
    if (dataClassName == 'BundleAnnouncementNone') {
      return deserialize<_iothyv29.BundleAnnouncementNone>(data['data']);
    }
    if (dataClassName == 'NoWrites') {
      return deserialize<_iotz1o7l.NoWrites>(data['data']);
    }
    if (dataClassName == 'PublicReason') {
      return deserialize<_i0rvs1mg.PublicReason>(data['data']);
    }
    if (dataClassName == 'SdeAdminOperationKind') {
      return deserialize<_ix7ishv7.SdeAdminOperationKind>(data['data']);
    }
    if (dataClassName == 'SdeAdminOperationOutcome') {
      return deserialize<_iowegcqg.SdeAdminOperationOutcome>(data['data']);
    }
    if (dataClassName == 'SdeBuildDiffOutcome') {
      return deserialize<_iby3hddy.SdeBuildDiffOutcome>(data['data']);
    }
    if (dataClassName == 'SdeBuildState') {
      return deserialize<_isyk7irp.SdeBuildState>(data['data']);
    }
    if (dataClassName == 'SdeBundleOutcome') {
      return deserialize<_iquqzrxf.SdeBundleOutcome>(data['data']);
    }
    if (dataClassName == 'SdeCheckOutcome') {
      return deserialize<_illgk9kj.SdeCheckOutcome>(data['data']);
    }
    if (dataClassName == 'SdeImportOutcome') {
      return deserialize<_is3f4xcr.SdeImportOutcome>(data['data']);
    }
    if (dataClassName == 'SdeImportSource') {
      return deserialize<_ice2slzs.SdeImportSource>(data['data']);
    }
    if (dataClassName == 'SdeSwitchKind') {
      return deserialize<_iqktcwf1.SdeSwitchKind>(data['data']);
    }
    if (dataClassName == 'SdeSwitchOutcome') {
      return deserialize<_icb88h1v.SdeSwitchOutcome>(data['data']);
    }
    if (dataClassName == 'WriteRevision') {
      return deserialize<_iotz1o7l.WriteRevision>(data['data']);
    }
    if (dataClassName == 'StaticDataCcpLatest') {
      return deserialize<_imfnodj2.StaticDataCcpLatest>(data['data']);
    }
    if (dataClassName == 'StaticDataChangeReport') {
      return deserialize<_icn4k5zk.StaticDataChangeReport>(data['data']);
    }
    if (dataClassName == 'StaticDataCheckStatus') {
      return deserialize<_i58p74ek.StaticDataCheckStatus>(data['data']);
    }
    if (dataClassName == 'StaticDataDiffStatus') {
      return deserialize<_ivtfyb9n.StaticDataDiffStatus>(data['data']);
    }
    if (dataClassName == 'StaticDataImportStatus') {
      return deserialize<_igmz1uai.StaticDataImportStatus>(data['data']);
    }
    if (dataClassName == 'StaticDataReportChanges') {
      return deserialize<_i6y7rcpz.StaticDataReportChanges>(data['data']);
    }
    if (dataClassName == 'StaticDataReportFile') {
      return deserialize<_iacxd2dw.StaticDataReportFile>(data['data']);
    }
    if (dataClassName == 'StaticDataReportFileStatus') {
      return deserialize<_ijjljno5.StaticDataReportFileStatus>(data['data']);
    }
    if (dataClassName == 'StaticDataReportOutcome') {
      return deserialize<_iixf2rnc.StaticDataReportOutcome>(data['data']);
    }
    if (dataClassName == 'StaticDataStatus') {
      return deserialize<_i4ollqgk.StaticDataStatus>(data['data']);
    }
    if (dataClassName == 'StaticDataStatusUnavailable') {
      return deserialize<_ixbsr0c1.StaticDataStatusUnavailable>(data['data']);
    }
    if (dataClassName == 'StaticDataSwitchStatus') {
      return deserialize<_iidkva5e.StaticDataSwitchStatus>(data['data']);
    }
    return super.deserializeByClassName(data);
  }

  @override
  String getModuleName() => 'kaname';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
