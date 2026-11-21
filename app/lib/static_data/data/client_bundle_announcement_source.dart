/// The announcement stream over the generated Serverpod client.
library;

import 'dart:async';

import 'package:kaname_client/kaname_client.dart' as wire;

import 'bundle_announcements.dart';
import 'bundle_store.dart';

/// Opens one subscription to the generated client's announcement stream.
///
/// This is the seam between the generated client and the app: tests give a
/// fake that returns a controller's stream.
typedef OpenWireAnnouncements = Stream<wire.BundleAnnouncement> Function();

final RegExp _sha256Digits = RegExp(r'^[0-9a-f]{64}$');

/// A [BundleAnnouncementSource] that maps the generated client's events.
///
/// Each [subscribe] opens one subscription on the wire; the stream ends or
/// fails with it, and cancelling it cancels the wire subscription. An event
/// that names no valid bundle (a hash that is not 64 lower-case hexadecimal
/// digits, a build below 1, a negative size or format, an empty epoch or a
/// negative revision) becomes a [FormatException] error on the stream, never
/// a dropped event, so the caller resubscribes as it does after any failure.
final class ClientBundleAnnouncementSource implements BundleAnnouncementSource {
  /// Creates a source that opens its subscriptions with [open].
  ClientBundleAnnouncementSource(OpenWireAnnouncements open) : _open = open;

  /// Creates a source for the server at [base], an absolute URL ending in
  /// `/`, over a generated [wire.Client].
  factory ClientBundleAnnouncementSource.forServer(Uri base) {
    final client = wire.Client(base.toString());
    return ClientBundleAnnouncementSource(
      client.staticData.bundleAnnouncements,
    );
  }

  final OpenWireAnnouncements _open;

  /// Each subscription's events, mapped by [_map].
  ///
  /// The generated client (Serverpod 4.1.2) sends the server its close
  /// command only for a subscription the server has acknowledged; one
  /// cancelled before that would keep its server stream, place and bus
  /// listener until the stream's own end. So a cancel before the first
  /// event keeps the wire subscription until that event, which the server
  /// sends soon after it opens the stream (C29), and cancels it then.
  @override
  Stream<BundleAnnouncement> subscribe() {
    late final StreamSubscription<wire.BundleAnnouncement> onWire;
    var answered = false;
    var cancelled = false;
    final events = StreamController<BundleAnnouncement>();
    void cancelWire() => unawaited(onWire.cancel());
    events
      ..onListen = () {
        onWire = _open().listen(
          (event) {
            final first = !answered;
            answered = true;
            if (cancelled) {
              // The acknowledgement came before this event; cancel once the
              // client has taken it in.
              if (first) Timer.run(cancelWire);
              return;
            }
            final BundleAnnouncement mapped;
            try {
              mapped = _map(event);
            } on FormatException catch (error, stack) {
              events.addError(error, stack);
              return;
            }
            events.add(mapped);
          },
          onError: (Object error, StackTrace stack) {
            if (cancelled) return cancelWire();
            events.addError(error, stack);
          },
          onDone: () {
            if (!cancelled) unawaited(events.close());
          },
        );
      }
      ..onPause = (() => onWire.pause())
      ..onResume = (() => onWire.resume())
      ..onCancel = () {
        cancelled = true;
        if (answered) return onWire.cancel();
        // Still waiting for the first event: it must be able to arrive.
        while (onWire.isPaused) {
          onWire.resume();
        }
      };
    return events.stream;
  }

  static BundleAnnouncement _map(wire.BundleAnnouncement event) {
    if (event.epoch.isEmpty || event.revision < 0) {
      throw FormatException(
        'announcement with epoch "${event.epoch}" and revision '
        '${event.revision}',
      );
    }
    return switch (event) {
      wire.BundleAnnouncementNamed(
        :final epoch,
        :final revision,
        :final build,
        :final sha256,
        :final size,
        :final formatMajor,
      ) =>
        build < 1 ||
                size < 0 ||
                formatMajor < 0 ||
                !_sha256Digits.hasMatch(sha256)
            ? throw FormatException(
                'announcement names no valid bundle: build $build, '
                'sha256 "$sha256", size $size, format $formatMajor',
              )
            : BundleAnnounced(
                epoch: epoch,
                revision: revision,
                bundle: BundleIdentity(build: build, sha256: sha256),
                size: size,
                formatMajor: formatMajor,
              ),
      wire.BundleAnnouncementNone(:final epoch, :final revision) =>
        NoBundleAnnounced(epoch: epoch, revision: revision),
    };
  }
}
