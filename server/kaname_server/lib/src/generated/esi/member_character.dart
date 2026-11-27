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

/// Character display data; no grant, owner hash or bearer.
abstract class MemberCharacter
    implements _is.SerializableModel, _is.ProtocolSerialization {
  MemberCharacter._({
    required this.characterId,
    required this.name,
    required this.blocked,
  });

  factory MemberCharacter({
    required String characterId,
    required String name,
    required bool blocked,
  }) = _MemberCharacterImpl;

  factory MemberCharacter.fromJson(Map<String, dynamic> jsonSerialization) {
    return MemberCharacter(
      characterId: jsonSerialization['characterId'] as String,
      name: jsonSerialization['name'] as String,
      blocked: _is.BoolJsonExtension.fromJson(jsonSerialization['blocked']),
    );
  }

  String characterId;

  String name;

  bool blocked;

  /// Returns a shallow copy of this [MemberCharacter]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  MemberCharacter copyWith({String? characterId, String? name, bool? blocked});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MemberCharacter',
      'characterId': characterId,
      'name': name,
      'blocked': blocked,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'MemberCharacter',
      'characterId': characterId,
      'name': name,
      'blocked': blocked,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _MemberCharacterImpl extends MemberCharacter {
  _MemberCharacterImpl({
    required String characterId,
    required String name,
    required bool blocked,
  }) : super._(characterId: characterId, name: name, blocked: blocked);

  /// Returns a shallow copy of this [MemberCharacter]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  MemberCharacter copyWith({String? characterId, String? name, bool? blocked}) {
    return MemberCharacter(
      characterId: characterId ?? this.characterId,
      name: name ?? this.name,
      blocked: blocked ?? this.blocked,
    );
  }
}
