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

/// Which way a switch moved the active build.
/// `switch` is a Dart reserved word, so the forward kind is `forward`.
enum SdeSwitchKind implements _isc.SerializableModel {
  forward,
  rollback;

  static SdeSwitchKind fromJson(String name) {
    switch (name) {
      case 'forward':
        return SdeSwitchKind.forward;
      case 'rollback':
        return SdeSwitchKind.rollback;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "SdeSwitchKind"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
