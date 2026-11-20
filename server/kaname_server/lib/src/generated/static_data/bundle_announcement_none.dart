/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'bundle_announcement.dart';

/// The announcement that no bundle is available: nothing is imported yet,
/// or no stored bundle is in the server's current format.
abstract class BundleAnnouncementNone extends _iv35mfmj.BundleAnnouncement
    implements _is.SerializableModel, _is.ProtocolSerialization {
  BundleAnnouncementNone._({required super.epoch, required super.revision});

  factory BundleAnnouncementNone({
    required String epoch,
    required int revision,
  }) = _BundleAnnouncementNoneImpl;

  factory BundleAnnouncementNone.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return BundleAnnouncementNone(
      epoch: jsonSerialization['epoch'] as String,
      revision: jsonSerialization['revision'] as int,
    );
  }

  /// Returns a shallow copy of this [BundleAnnouncementNone]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  BundleAnnouncementNone copyWith({String? epoch, int? revision});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BundleAnnouncementNone',
      'epoch': epoch,
      'revision': revision,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BundleAnnouncementNone',
      'epoch': epoch,
      'revision': revision,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _BundleAnnouncementNoneImpl extends BundleAnnouncementNone {
  _BundleAnnouncementNoneImpl({required String epoch, required int revision})
    : super._(epoch: epoch, revision: revision);

  /// Returns a shallow copy of this [BundleAnnouncementNone]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BundleAnnouncementNone copyWith({String? epoch, int? revision}) {
    return BundleAnnouncementNone(
      epoch: epoch ?? this.epoch,
      revision: revision ?? this.revision,
    );
  }
}
