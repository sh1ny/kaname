import 'dart:async';

import 'package:kaname_core/kaname_core.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../network/client_identity.dart';
import 'admin_operation_reader.dart';
import 'bundle_announcement_runtime.dart';
import 'static_data_access.dart';
import 'static_data_bundle_topic.dart';

/// How long one announcement stream lives before the server ends it (C20).
const Duration announcementStreamLifetime = Duration(minutes: 30);

/// The static-data endpoint: the announcement stream of the client data
/// bundle.
class StaticDataEndpoint extends Endpoint {
  @override
  bool get requireLogin => false;

  /// Reads a bounded public status snapshot without requiring sign-in (D2).
  Future<StaticDataStatus> status(Session session) async =>
      await StaticDataAccess.forPod(session.serverpod).status.status() ??
      (throw StaticDataStatusUnavailable());

  /// Reads only the requested operation's durable progress (D9, D21).
  Future<AdminOperationAnswer> operation(Session session, String operationId) =>
      readPublicAdminOperation(
        StaticDataAccess.forPod(session.serverpod),
        operationId,
      );

  /// Streams the announcement of the bundle the app may download.
  ///
  /// The first event is the announcement the announcer has installed, sent
  /// once the announcer has installed its first one (a failed first refresh,
  /// or none that succeeded 19 seconds after its start, installs "none"); an
  /// event follows each change of the installed announcement. Needs no
  /// sign-in.
  ///
  /// The subscription is admitted, or refused, when this method is called:
  /// at most `BundleAnnouncementRuntime.maxStreamsPerClient` (16) streams
  /// per client and `maxStreams` (2,000) in all. A refused subscription ends
  /// at once, without an event or an error. An admitted stream holds its
  /// places and its 30-minute life runs from then; until Serverpod listens
  /// to it, it has no bus listener and receives nothing, and once listened
  /// to it first sends the announcement installed at that moment.
  ///
  /// ## Carried constraints
  ///
  /// - **C2:** Both bounds are taken in the same synchronous step as their
  ///   check (`BundleAnnouncementRuntime.admit`), and freed only by the
  ///   stream's single `end()`. A stream that has ended never subscribes to
  ///   the bus or sends, even if it is listened to later. Moving either
  ///   count to `onListen` reopens the concurrent overshoot.
  /// - **C20:** The stream is bounded by count, rate and lifetime. The server
  ///   refuses streams over its bounds by ending them at once without an
  ///   event. Each ends after 30 minutes on the server's clock, also while
  ///   its client reads nothing, because Serverpod's endpoint streams have no
  ///   backpressure (A14): what the stream sends is bounded by rate, at most
  ///   one event per change of the installed announcement, never by the
  ///   client's reading. Whatever ends the stream (expiry, the client's
  ///   disconnect, an error) removes its bus listener and frees its places.
  ///   Every send carries the announcement installed at that moment, and
  ///   only when its revision is higher than the last one this stream sent
  ///   (C16): bus messages are wake-ups, never the payload, so a late or
  ///   buffered message cannot send a retired announcement. The handoff is
  ///   synchronous; Serverpod writes the value to the WebSocket one
  ///   microtask later, and an announcement installed in that microtask
  ///   follows at once.
  Stream<BundleAnnouncement> bundleAnnouncements(Session session) {
    final runtime = bundleAnnouncementRuntime;
    final identity = runtime.clientOf(session);
    final client = identity.key;
    if (identity case ProxyFallback(:final proxy)) {
      // The trusted proxy counts as the client; logged at the refusal rate,
      // naming the proxy's own address, not its /64 key.
      _warn(
        session,
        runtime.noteRefusal(
          client,
          noUsableForwardedHeader,
          shown: proxy.address,
        ),
      );
    }
    final announcer = runtime.announcer;
    final bus = runtime.bus;
    if (announcer == null || bus == null) {
      return _refuse(session, client, AnnouncementRefusal.noAnnouncer);
    }
    final scope = runtime.scope ?? _topicScope();
    if (scope == null) {
      return _refuse(session, client, AnnouncementRefusal.noDeliveryScope);
    }
    final StreamReservation reservation;
    switch (runtime.admit(client)) {
      case StreamRefused(:final reason):
        return _refuse(session, client, reason);
      case StreamAdmitted(reservation: final admitted):
        reservation = admitted;
    }

    // A controller, not an `async*` body: a generator that waits for a
    // wake-up does not see its cancellation until it next yields, so the bus
    // listener of a disconnected client would stay until the next change.
    // A sync one: the value checked is the value handed to Serverpod in the
    // same step, with no queued delivery in between (C16).
    final controller = StreamController<BundleAnnouncement>(sync: true);
    StreamSubscription<BundleAnnouncement>? busSubscription;
    late final Timer expiry;
    var open = true;
    var lastRevision = -1;

    // Sends the installed announcement when it is newer than the last one
    // sent and passes the scope. Only a listened stream calls it.
    void sendDue() {
      final installed = announcer.installed;
      if (!open || installed == null || installed.revision <= lastRevision) {
        return;
      }
      if (!scope.passes(installed)) return;
      lastRevision = installed.revision;
      runtime.noteStep(reservation, StreamStep.sent);
      controller.add(installed);
    }

    // Ends the stream whichever way it ends: removes the bus listener and
    // the timer and frees both places, once (C2).
    Future<void> end({required bool closeController}) async {
      if (!open) return;
      open = false;
      expiry.cancel();
      runtime.release(reservation);
      // Everything above and the close below happen in the caller's step,
      // with no await in between: the expiry frees the places and hands
      // Serverpod the end at once.
      final cancelled = busSubscription?.cancel();
      Future<void>? closed;
      if (closeController) {
        // The sync controller hands Serverpod the end at once, whether or
        // not the transport can take it.
        closed = controller.close();
        runtime.endedByServer++;
      }
      await cancelled;
      await closed;
    }

    // The 30-minute life runs from admission (D5): a stream Serverpod never
    // listens to is ended by it, which frees its places.
    expiry = runtime.clock.once(
      announcementStreamLifetime,
      () => unawaited(end(closeController: true)),
    );
    controller
      ..onListen = () {
        // A stream that ended before anyone listened is already closed: the
        // listener gets its end and nothing else.
        if (!open) return;
        runtime.noteStep(reservation, StreamStep.listened);
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
        unawaited(announcer.firstInstalled.then((_) => sendDue()));
      }
      ..onCancel = () => end(closeController: false);
    return controller.stream;
  }

  /// Counts the refusal of [client]'s subscription for [reason] in the
  /// rate-limited refusal log (D6) and returns the stream that ends at once,
  /// without an event or an error.
  static Stream<BundleAnnouncement> _refuse(
    Session session,
    ClientKey client,
    AnnouncementRefusal reason,
  ) {
    _warn(session, bundleAnnouncementRuntime.noteRefusal(client, reason.label));
    return const Stream.empty();
  }

  /// Writes [warning] through the runtime, when the refusal log gave one.
  static void _warn(Session session, String? warning) {
    if (warning != null) {
      bundleAnnouncementRuntime.logWarning(session, warning);
    }
  }

  /// The scope the topic's visibility resolves to, or `null` when refused.
  static DeliveryScope<BundleAnnouncement>? _topicScope() =>
      switch (resolveDeliveryScope(staticDataTopic)) {
        DeliveryScopeAccepted(:final scope) => scope,
        DeliveryScopeRefused() => null,
      };
}
