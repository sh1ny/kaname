/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'setting_revision.dart';

/// No auto-update write has committed yet (D3).
abstract class NoWrites extends _iv35mfmj.SettingRevision
    implements _is.SerializableModel, _is.ProtocolSerialization {
  NoWrites._();

  factory NoWrites() = _NoWritesImpl;

  factory NoWrites.fromJson(Map<String, dynamic> jsonSerialization) {
    return NoWrites();
  }

  /// Returns a shallow copy of this [NoWrites]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  NoWrites copyWith();
  @override
  Map<String, dynamic> toJson() {
    return {'__className__': 'NoWrites'};
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {'__className__': 'NoWrites'};
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _NoWritesImpl extends NoWrites {
  _NoWritesImpl() : super._();

  /// Returns a shallow copy of this [NoWrites]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  NoWrites copyWith() {
    return NoWrites();
  }
}
