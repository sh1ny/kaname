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

import '../health/dependency_status.dart' as _ib8xwxvz;

/// The typed answer of the health endpoint: the server version and the
/// status of each dependency. It never carries hosts, ports, credentials or
/// dependency error text. Fields are only ever added.
abstract class HealthReport
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  HealthReport._({
    required this.version,
    required this.postgres,
    required this.redis,
  });

  factory HealthReport({
    required String version,
    required _ib8xwxvz.DependencyStatus postgres,
    required _ib8xwxvz.DependencyStatus redis,
  }) = _HealthReportImpl;

  factory HealthReport.fromJson(Map<String, dynamic> jsonSerialization) {
    return HealthReport(
      version: jsonSerialization['version'] as String,
      postgres: _ib8xwxvz.DependencyStatus.fromJson(
        (jsonSerialization['postgres'] as String),
      ),
      redis: _ib8xwxvz.DependencyStatus.fromJson(
        (jsonSerialization['redis'] as String),
      ),
    );
  }

  String version;

  _ib8xwxvz.DependencyStatus postgres;

  _ib8xwxvz.DependencyStatus redis;

  /// Returns a shallow copy of this [HealthReport]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  HealthReport copyWith({
    String? version,
    _ib8xwxvz.DependencyStatus? postgres,
    _ib8xwxvz.DependencyStatus? redis,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'HealthReport',
      'version': version,
      'postgres': postgres.toJson(),
      'redis': redis.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'HealthReport',
      'version': version,
      'postgres': postgres.toJson(),
      'redis': redis.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _HealthReportImpl extends HealthReport {
  _HealthReportImpl({
    required String version,
    required _ib8xwxvz.DependencyStatus postgres,
    required _ib8xwxvz.DependencyStatus redis,
  }) : super._(version: version, postgres: postgres, redis: redis);

  /// Returns a shallow copy of this [HealthReport]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  HealthReport copyWith({
    String? version,
    _ib8xwxvz.DependencyStatus? postgres,
    _ib8xwxvz.DependencyStatus? redis,
  }) {
    return HealthReport(
      version: version ?? this.version,
      postgres: postgres ?? this.postgres,
      redis: redis ?? this.redis,
    );
  }
}
