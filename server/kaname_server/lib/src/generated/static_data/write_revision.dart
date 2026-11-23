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

/// The id of the newest committed auto-update write (D3).
abstract class WriteRevision extends _iv35mfmj.SettingRevision
    implements _is.SerializableModel, _is.ProtocolSerialization {
  WriteRevision._({required this.id});

  factory WriteRevision({required int id}) = _WriteRevisionImpl;

  factory WriteRevision.fromJson(Map<String, dynamic> jsonSerialization) {
    return WriteRevision(id: jsonSerialization['id'] as int);
  }

  int id;

  /// Returns a shallow copy of this [WriteRevision]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  WriteRevision copyWith({int? id});
  @override
  Map<String, dynamic> toJson() {
    return {'__className__': 'WriteRevision', 'id': id};
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {'__className__': 'WriteRevision', 'id': id};
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _WriteRevisionImpl extends WriteRevision {
  _WriteRevisionImpl({required int id}) : super._(id: id);

  /// Returns a shallow copy of this [WriteRevision]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  WriteRevision copyWith({int? id}) {
    return WriteRevision(id: id ?? this.id);
  }
}
