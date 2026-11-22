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

/// The announcement of one downloadable bundle: its build, SHA-256 (which
/// the download URL carries), compressed size and major format version.
abstract class BundleAnnouncementNamed extends _iv35mfmj.BundleAnnouncement
    implements _is.SerializableModel, _is.ProtocolSerialization {
  BundleAnnouncementNamed._({
    required super.epoch,
    required super.revision,
    required this.build,
    required this.sha256,
    required this.size,
    required this.formatMajor,
  });

  factory BundleAnnouncementNamed({
    required String epoch,
    required int revision,
    required int build,
    required String sha256,
    required int size,
    required int formatMajor,
  }) = _BundleAnnouncementNamedImpl;

  factory BundleAnnouncementNamed.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return BundleAnnouncementNamed(
      epoch: jsonSerialization['epoch'] as String,
      revision: jsonSerialization['revision'] as int,
      build: jsonSerialization['build'] as int,
      sha256: jsonSerialization['sha256'] as String,
      size: jsonSerialization['size'] as int,
      formatMajor: jsonSerialization['formatMajor'] as int,
    );
  }

  int build;

  String sha256;

  int size;

  int formatMajor;

  /// Returns a shallow copy of this [BundleAnnouncementNamed]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  BundleAnnouncementNamed copyWith({
    String? epoch,
    int? revision,
    int? build,
    String? sha256,
    int? size,
    int? formatMajor,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BundleAnnouncementNamed',
      'epoch': epoch,
      'revision': revision,
      'build': build,
      'sha256': sha256,
      'size': size,
      'formatMajor': formatMajor,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BundleAnnouncementNamed',
      'epoch': epoch,
      'revision': revision,
      'build': build,
      'sha256': sha256,
      'size': size,
      'formatMajor': formatMajor,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _BundleAnnouncementNamedImpl extends BundleAnnouncementNamed {
  _BundleAnnouncementNamedImpl({
    required String epoch,
    required int revision,
    required int build,
    required String sha256,
    required int size,
    required int formatMajor,
  }) : super._(
         epoch: epoch,
         revision: revision,
         build: build,
         sha256: sha256,
         size: size,
         formatMajor: formatMajor,
       );

  /// Returns a shallow copy of this [BundleAnnouncementNamed]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BundleAnnouncementNamed copyWith({
    String? epoch,
    int? revision,
    int? build,
    String? sha256,
    int? size,
    int? formatMajor,
  }) {
    return BundleAnnouncementNamed(
      epoch: epoch ?? this.epoch,
      revision: revision ?? this.revision,
      build: build ?? this.build,
      sha256: sha256 ?? this.sha256,
      size: size ?? this.size,
      formatMajor: formatMajor ?? this.formatMajor,
    );
  }
}
