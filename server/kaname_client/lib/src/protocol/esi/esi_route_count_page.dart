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

import '../esi/esi_route_count_item.dart' as _i7wcmucg;

/// The released route aggregate view.
abstract class EsiRouteCountPage
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  EsiRouteCountPage._({required this.status, required this.rows});

  factory EsiRouteCountPage({
    required String status,
    required List<_i7wcmucg.EsiRouteCount> rows,
  }) = _EsiRouteCountPageImpl;

  factory EsiRouteCountPage.fromJson(Map<String, dynamic> jsonSerialization) {
    return EsiRouteCountPage(
      status: jsonSerialization['status'] as String,
      rows: _i7wvxdxe.Protocol().deserialize<List<_i7wcmucg.EsiRouteCount>>(
        jsonSerialization['rows'],
      ),
    );
  }

  String status;

  List<_i7wcmucg.EsiRouteCount> rows;

  /// Returns a shallow copy of this [EsiRouteCountPage]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  EsiRouteCountPage copyWith({
    String? status,
    List<_i7wcmucg.EsiRouteCount>? rows,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'EsiRouteCountPage',
      'status': status,
      'rows': rows.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'EsiRouteCountPage',
      'status': status,
      'rows': rows.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _EsiRouteCountPageImpl extends EsiRouteCountPage {
  _EsiRouteCountPageImpl({
    required String status,
    required List<_i7wcmucg.EsiRouteCount> rows,
  }) : super._(status: status, rows: rows);

  /// Returns a shallow copy of this [EsiRouteCountPage]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  EsiRouteCountPage copyWith({
    String? status,
    List<_i7wcmucg.EsiRouteCount>? rows,
  }) {
    return EsiRouteCountPage(
      status: status ?? this.status,
      rows: rows ?? this.rows.map((e0) => e0.copyWith()).toList(),
    );
  }
}
