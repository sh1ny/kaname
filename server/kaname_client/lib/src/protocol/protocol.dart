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

import 'health/dependency_status.dart' as _iztepymd;
import 'health/health_report.dart' as _if75m2mz;
import 'static_data/sde_build_diff_outcome.dart' as _iby3hddy;
import 'static_data/sde_build_state.dart' as _isyk7irp;
import 'static_data/sde_bundle_outcome.dart' as _iquqzrxf;
import 'static_data/sde_check_outcome.dart' as _illgk9kj;
import 'static_data/sde_import_outcome.dart' as _is3f4xcr;
import 'static_data/sde_import_source.dart' as _ice2slzs;
import 'static_data/sde_switch_kind.dart' as _iqktcwf1;
import 'static_data/sde_switch_outcome.dart' as _icb88h1v;
export 'health/dependency_status.dart';
export 'health/health_report.dart';
export 'static_data/sde_build_diff_outcome.dart';
export 'static_data/sde_build_state.dart';
export 'static_data/sde_bundle_outcome.dart';
export 'static_data/sde_check_outcome.dart';
export 'static_data/sde_import_outcome.dart';
export 'static_data/sde_import_source.dart';
export 'static_data/sde_switch_kind.dart';
export 'static_data/sde_switch_outcome.dart';
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
          _isc.getType<_iztepymd.DependencyStatus>,
          _isc.getType<_if75m2mz.HealthReport>,
          _isc.getType<_iby3hddy.SdeBuildDiffOutcome>,
          _isc.getType<_isyk7irp.SdeBuildState>,
          _isc.getType<_iquqzrxf.SdeBundleOutcome>,
          _isc.getType<_illgk9kj.SdeCheckOutcome>,
          _isc.getType<_is3f4xcr.SdeImportOutcome>,
          _isc.getType<_ice2slzs.SdeImportSource>,
          _isc.getType<_iqktcwf1.SdeSwitchKind>,
          _isc.getType<_icb88h1v.SdeSwitchOutcome>,
          _isc.getType<_iztepymd.DependencyStatus?>,
          _isc.getType<_if75m2mz.HealthReport?>,
          _isc.getType<_iby3hddy.SdeBuildDiffOutcome?>,
          _isc.getType<_isyk7irp.SdeBuildState?>,
          _isc.getType<_iquqzrxf.SdeBundleOutcome?>,
          _isc.getType<_illgk9kj.SdeCheckOutcome?>,
          _isc.getType<_is3f4xcr.SdeImportOutcome?>,
          _isc.getType<_ice2slzs.SdeImportSource?>,
          _isc.getType<_iqktcwf1.SdeSwitchKind?>,
          _isc.getType<_icb88h1v.SdeSwitchOutcome?>,
          _isc.getType<_idp9h2tz.SdeJson>,
          _isc.getType<_idp9h2tz.SdeJson?>,
        ],
        modules: const [],
        classNames: const [
          'SdeJson',
          'DependencyStatus',
          'HealthReport',
          'SdeBuildDiffOutcome',
          'SdeBuildState',
          'SdeBundleOutcome',
          'SdeCheckOutcome',
          'SdeImportOutcome',
          'SdeImportSource',
          'SdeSwitchKind',
          'SdeSwitchOutcome',
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

    if (t == _iztepymd.DependencyStatus) {
      return _iztepymd.DependencyStatus.fromJson(data) as T;
    }
    if (t == _if75m2mz.HealthReport) {
      return _if75m2mz.HealthReport.fromJson(data) as T;
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
    if (t == _isc.getType<_iztepymd.DependencyStatus?>()) {
      return (data != null ? _iztepymd.DependencyStatus.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_if75m2mz.HealthReport?>()) {
      return (data != null ? _if75m2mz.HealthReport.fromJson(data) : null) as T;
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
      _iztepymd.DependencyStatus => 'DependencyStatus',
      _if75m2mz.HealthReport => 'HealthReport',
      _iby3hddy.SdeBuildDiffOutcome => 'SdeBuildDiffOutcome',
      _isyk7irp.SdeBuildState => 'SdeBuildState',
      _iquqzrxf.SdeBundleOutcome => 'SdeBundleOutcome',
      _illgk9kj.SdeCheckOutcome => 'SdeCheckOutcome',
      _is3f4xcr.SdeImportOutcome => 'SdeImportOutcome',
      _ice2slzs.SdeImportSource => 'SdeImportSource',
      _iqktcwf1.SdeSwitchKind => 'SdeSwitchKind',
      _icb88h1v.SdeSwitchOutcome => 'SdeSwitchOutcome',
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
      case _iztepymd.DependencyStatus():
        return 'DependencyStatus';
      case _if75m2mz.HealthReport():
        return 'HealthReport';
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
    if (dataClassName == 'DependencyStatus') {
      return deserialize<_iztepymd.DependencyStatus>(data['data']);
    }
    if (dataClassName == 'HealthReport') {
      return deserialize<_if75m2mz.HealthReport>(data['data']);
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
