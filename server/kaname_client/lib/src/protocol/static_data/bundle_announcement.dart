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

import '../protocol.dart' as _iv35mfmj;
part 'bundle_announcement_named.dart';
part 'bundle_announcement_none.dart';

/// What the announcement stream sends: which static-data bundle apps should
/// hold (design D8, ADR 0014).
///
/// `epoch` is a random id chosen at each server start, and `revision` rises
/// with each change of the installed announcement within an epoch; an app
/// ignores a revision it has passed within the same epoch and takes any
/// announcement of a new epoch. The sealed children say whether a bundle is
/// announced. The model is also the payload of the static-data bus topic.
sealed class BundleAnnouncement
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  BundleAnnouncement({required this.epoch, required this.revision});

  String epoch;

  int revision;

  /// Returns a shallow copy of this [BundleAnnouncement]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  BundleAnnouncement copyWith({String? epoch, int? revision});
}
