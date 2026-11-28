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

/// Registry key for one public lookup after an identity commits.
abstract class AffiliationFirstKnownArgs
    implements _is.SerializableModel, _is.ProtocolSerialization {
  AffiliationFirstKnownArgs._({required this.identityId});

  factory AffiliationFirstKnownArgs({required int identityId}) =
      _AffiliationFirstKnownArgsImpl;

  factory AffiliationFirstKnownArgs.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return AffiliationFirstKnownArgs(
      identityId: jsonSerialization['identityId'] as int,
    );
  }

  int identityId;

  /// Returns a shallow copy of this [AffiliationFirstKnownArgs]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AffiliationFirstKnownArgs copyWith({int? identityId});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AffiliationFirstKnownArgs',
      'identityId': identityId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _AffiliationFirstKnownArgsImpl extends AffiliationFirstKnownArgs {
  _AffiliationFirstKnownArgsImpl({required int identityId})
    : super._(identityId: identityId);

  /// Returns a shallow copy of this [AffiliationFirstKnownArgs]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AffiliationFirstKnownArgs copyWith({int? identityId}) {
    return AffiliationFirstKnownArgs(identityId: identityId ?? this.identityId);
  }
}
