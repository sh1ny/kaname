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

/// One durable full-sweep dispatch for a logical slot in the issuing boot.
abstract class AffiliationSweepArgs
    implements _is.SerializableModel, _is.ProtocolSerialization {
  AffiliationSweepArgs._({required this.boot, required this.slot});

  factory AffiliationSweepArgs({required String boot, required int slot}) =
      _AffiliationSweepArgsImpl;

  factory AffiliationSweepArgs.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return AffiliationSweepArgs(
      boot: jsonSerialization['boot'] as String,
      slot: jsonSerialization['slot'] as int,
    );
  }

  String boot;

  int slot;

  /// Returns a shallow copy of this [AffiliationSweepArgs]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AffiliationSweepArgs copyWith({String? boot, int? slot});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AffiliationSweepArgs',
      'boot': boot,
      'slot': slot,
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

class _AffiliationSweepArgsImpl extends AffiliationSweepArgs {
  _AffiliationSweepArgsImpl({required String boot, required int slot})
    : super._(boot: boot, slot: slot);

  /// Returns a shallow copy of this [AffiliationSweepArgs]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AffiliationSweepArgs copyWith({String? boot, int? slot}) {
    return AffiliationSweepArgs(
      boot: boot ?? this.boot,
      slot: slot ?? this.slot,
    );
  }
}
