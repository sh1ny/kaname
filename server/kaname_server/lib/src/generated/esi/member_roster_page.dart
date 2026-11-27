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
import 'package:kaname_server/src/generated/protocol.dart' as _iwxagaxh;
import 'package:serverpod/serverpod.dart' as _is;

import '../esi/member_character.dart' as _idwuil4b;
import '../esi/member_roster_status.dart' as _i4dtv4x5;

/// One connected account page with main and signing roles outside the page.
abstract class MemberRosterPage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  MemberRosterPage._({
    required this.status,
    this.accountId,
    this.main,
    this.signing,
    required this.characters,
    this.next,
  });

  factory MemberRosterPage({
    required _i4dtv4x5.MemberRosterStatus status,
    String? accountId,
    _idwuil4b.MemberCharacter? main,
    _idwuil4b.MemberCharacter? signing,
    required List<_idwuil4b.MemberCharacter> characters,
    String? next,
  }) = _MemberRosterPageImpl;

  factory MemberRosterPage.fromJson(Map<String, dynamic> jsonSerialization) {
    return MemberRosterPage(
      status: _i4dtv4x5.MemberRosterStatus.fromJson(
        (jsonSerialization['status'] as String),
      ),
      accountId: jsonSerialization['accountId'] as String?,
      main: jsonSerialization['main'] == null
          ? null
          : _iwxagaxh.Protocol().deserialize<_idwuil4b.MemberCharacter>(
              jsonSerialization['main'],
            ),
      signing: jsonSerialization['signing'] == null
          ? null
          : _iwxagaxh.Protocol().deserialize<_idwuil4b.MemberCharacter>(
              jsonSerialization['signing'],
            ),
      characters: _iwxagaxh.Protocol()
          .deserialize<List<_idwuil4b.MemberCharacter>>(
            jsonSerialization['characters'],
          ),
      next: jsonSerialization['next'] as String?,
    );
  }

  _i4dtv4x5.MemberRosterStatus status;

  String? accountId;

  _idwuil4b.MemberCharacter? main;

  _idwuil4b.MemberCharacter? signing;

  List<_idwuil4b.MemberCharacter> characters;

  String? next;

  /// Returns a shallow copy of this [MemberRosterPage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  MemberRosterPage copyWith({
    _i4dtv4x5.MemberRosterStatus? status,
    String? accountId,
    _idwuil4b.MemberCharacter? main = const _UndefinedMemberRosterPage$main(),
    _idwuil4b.MemberCharacter? signing =
        const _UndefinedMemberRosterPage$main(),
    List<_idwuil4b.MemberCharacter>? characters,
    String? next,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MemberRosterPage',
      'status': status.toJson(),
      if (accountId != null) 'accountId': accountId,
      if (main != null) 'main': main?.toJson(),
      if (signing != null) 'signing': signing?.toJson(),
      'characters': characters.toJson(valueToJson: (v) => v.toJson()),
      if (next != null) 'next': next,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'MemberRosterPage',
      'status': status.toJson(),
      if (accountId != null) 'accountId': accountId,
      if (main != null) 'main': main?.toJsonForProtocol(),
      if (signing != null) 'signing': signing?.toJsonForProtocol(),
      'characters': characters.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
      if (next != null) 'next': next,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedMemberRosterPage$main extends _is.UndefinedSentinel
    implements _idwuil4b.MemberCharacter {
  const _UndefinedMemberRosterPage$main();
}

class _MemberRosterPageImpl extends MemberRosterPage {
  _MemberRosterPageImpl({
    required _i4dtv4x5.MemberRosterStatus status,
    String? accountId,
    _idwuil4b.MemberCharacter? main,
    _idwuil4b.MemberCharacter? signing,
    required List<_idwuil4b.MemberCharacter> characters,
    String? next,
  }) : super._(
         status: status,
         accountId: accountId,
         main: main,
         signing: signing,
         characters: characters,
         next: next,
       );

  /// Returns a shallow copy of this [MemberRosterPage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  MemberRosterPage copyWith({
    _i4dtv4x5.MemberRosterStatus? status,
    Object? accountId = _Undefined,
    _idwuil4b.MemberCharacter? main = const _UndefinedMemberRosterPage$main(),
    _idwuil4b.MemberCharacter? signing =
        const _UndefinedMemberRosterPage$main(),
    List<_idwuil4b.MemberCharacter>? characters,
    Object? next = _Undefined,
  }) {
    return MemberRosterPage(
      status: status ?? this.status,
      accountId: accountId is String? ? accountId : this.accountId,
      main: main is _is.UndefinedSentinel ? this.main?.copyWith() : main,
      signing: signing is _is.UndefinedSentinel
          ? this.signing?.copyWith()
          : signing,
      characters:
          characters ?? this.characters.map((e0) => e0.copyWith()).toList(),
      next: next is String? ? next : this.next,
    );
  }
}
