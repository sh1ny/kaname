import 'dart:async';

import 'package:kaname_core/kaname_core.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'bundle_announcement_runtime.dart';
import 'static_data_bundle_topic.dart';

/// How long one announcement stream lives before the server ends it (C20).
const Duration announcementStreamLifetime = Duration(minutes: 30);

/// The static-data endpoint: the announcement stream of the client data
/// bundle.
class StaticDataEndpoint extends Endpoint {
  @override
  bool get requireLogin => false;

  /// Streams the announcement of the bundle the app may download.
  ///
  /// The first event is the announcement the announcer has installed, sent
  /// once the announcer has installed its first one (a failed first refresh,
  /// or none that succeeded 19 seconds after its start, installs "none"); an
  /// event follows each change of the installed announcement. Needs no
  /// sign-in.
  ///
  /// ## Carried constraint
  ///
  /// - **C20:** The stream is bounded by count, rate and lifetime. The server
  ///   holds at most 2,000 of them (`BundleAnnouncementRuntime.maxStreams`)
  ///   and refuses more by ending the stream at once without an event. Each
  ///   ends after 30 minutes on the server's clock, also while its client
  ///   reads nothing, because Serverpod's endpoint streams have no
  ///   backpressure (A14): what the stream sends is bounded by rate, at most
  ///   one event per change of the installed announcement, never by the
  ///   client's reading. Whatever ends the stream (expiry, the client's
  ///   disconnect, an error) removes its bus listener and frees its place.
  ///   Every send carries the announcement installed at that moment, and
  ///   only when its revision is higher than the last one this stream sent
  ///   (C16): bus messages are wake-ups, never the payload, so a late or
  ///   buffered message cannot send a retired announcement. The handoff is
  ///   synchronous; Serverpod writes the value to the WebSocket one
  ///   microtask later, and an announcement installed in that microtask
  ///   follows at once.
  Stream<BundleAnnouncement> bundleAnnouncements(Session session) {
    final runtime = bundleAnnouncementRuntime;
    final announcer = runtime.announcer;
    final bus = runtime.bus;
    if (announcer == null || bus == null) {
      session.log(
        'announcement stream refused: this server runs no announcer',
        level: LogLevel.warning,
      );
      return const Stream.empty();
    }
    final scope = runtime.scope ?? _topicScope();
    if (scope == null) {
      session.log(
        'announcement stream refused: the topic needs the privacy scope',
        level: LogLevel.warning,
      );
      return const Stream.empty();
    }
    if (runtime.openStreams >= runtime.maxStreams) {
      session.log(
        'announcement stream refused: ${runtime.maxStreams} streams are open',
        level: LogLevel.warning,
      );
      return const Stream.empty();
    }

    // A controller, not an `async*` body: a generator that waits for a
    // wake-up does not see its cancellation until it next yields, so the bus
    // listener of a disconnected client would stay until the next change.
    // A sync one: the value checked is the value handed to Serverpod in the
    // same step, with no queued delivery in between (C16).
    final controller = StreamController<BundleAnnouncement>(sync: true);
    StreamSubscription<BundleAnnouncement>? busSubscription;
    Timer? expiry;
    var open = false;
    var lastRevision = -1;

    // Sends the installed announcement when it is newer than the last one
    // sent and passes the scope.
    void sendDue() {
      final installed = announcer.installed;
      if (!open || installed == null || installed.revision <= lastRevision) {
        return;
      }
      if (!scope.passes(installed)) return;
      lastRevision = installed.revision;
      controller.add(installed);
    }

    // Ends the stream whichever way it ends: removes the bus listener and
    // the timer and frees the place.
    Future<void> end({required bool closeController}) async {
      if (!open) return;
      open = false;
      expiry?.cancel();
      runtime.openStreams--;
      await busSubscription?.cancel();
      if (closeController) await controller.close();
    }

    controller
      ..onListen = () {
        open = true;
        runtime.openStreams++;
        // Subscribe first, so no change falls between the snapshot and the
        // subscription; the messages only wake this stream up.
        busSubscription = bus
            .subscribe(staticDataTopic)
            .listen(
              (_) => sendDue(),
              onError: (Object error) {
                session.log(
                  'announcement stream: bus error: $error',
                  level: LogLevel.warning,
                );
              },
            );
        expiry = runtime.clock.once(
          announcementStreamLifetime,
          () => unawaited(end(closeController: true)),
        );
        unawaited(announcer.firstInstalled.then((_) => sendDue()));
      }
      ..onCancel = () => end(closeController: false);
    return controller.stream;
  }

  /// The scope the topic's visibility resolves to, or `null` when refused.
  static DeliveryScope<BundleAnnouncement>? _topicScope() =>
      switch (resolveDeliveryScope(staticDataTopic)) {
        DeliveryScopeAccepted(:final scope) => scope,
        DeliveryScopeRefused() => null,
      };
}
