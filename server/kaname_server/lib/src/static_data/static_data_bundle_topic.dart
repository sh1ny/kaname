import 'package:kaname_core/kaname_core.dart';

import '../generated/protocol.dart';

/// The public static-data topic of the realtime bus (ADR 0014): its message is
/// the [BundleAnnouncement] the announcer has just installed.
///
/// The topic is public: an announcement names a build and a hash of public
/// SDE data and nothing else (C9). Streams use its messages only as wake-ups
/// and send the announcer's installed announcement (C16).
const Topic<BundleAnnouncement> staticDataTopic = Topic<BundleAnnouncement>(
  name: 'static-data',
  version: 1,
  visibility: TopicVisibility.public,
);
