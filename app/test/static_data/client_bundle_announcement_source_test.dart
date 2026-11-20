@TestOn('vm')
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/static_data/data/bundle_announcements.dart';
import 'package:kaname_app/static_data/data/bundle_store.dart';
import 'package:kaname_app/static_data/data/client_bundle_announcement_source.dart';
import 'package:kaname_client/kaname_client.dart' as wire;

const _sha = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

/// A hand-written seam: each open returns a controller the test drives.
final class _FakeWire {
  final List<StreamController<wire.BundleAnnouncement>> opened = [];
  final List<bool> cancelled = [];

  Stream<wire.BundleAnnouncement> open() {
    final index = opened.length;
    cancelled.add(false);
    final controller = StreamController<wire.BundleAnnouncement>(
      onCancel: () => cancelled[index] = true,
    );
    opened.add(controller);
    return controller.stream;
  }
}

wire.BundleAnnouncementNamed _named({
  String epoch = 'epoch-1',
  int revision = 1,
  int build = 3714173,
  String sha256 = _sha,
  int size = 1234567,
  int formatMajor = 1,
}) => wire.BundleAnnouncementNamed(
  epoch: epoch,
  revision: revision,
  build: build,
  sha256: sha256,
  size: size,
  formatMajor: formatMajor,
);

void main() {
  group('ClientBundleAnnouncementSource', () {
    late _FakeWire fake;
    late ClientBundleAnnouncementSource source;

    setUp(() {
      fake = _FakeWire();
      source = ClientBundleAnnouncementSource(fake.open);
    });

    test('maps a named announcement to the build, hash, size and format '
        'major with its epoch and revision', () async {
      final events = <BundleAnnouncement>[];
      final subscription = source.subscribe().listen(events.add);
      addTearDown(subscription.cancel);

      fake.opened.single.add(_named(epoch: 'e7', revision: 42));
      await pumpEventQueue();

      final announced = events.single as BundleAnnounced;
      expect(announced.epoch, 'e7');
      expect(announced.revision, 42);
      expect(
        announced.bundle,
        const BundleIdentity(build: 3714173, sha256: _sha),
      );
      expect(announced.size, 1234567);
      expect(announced.formatMajor, 1);
    });

    test('maps a none announcement to "no bundle" with its epoch and '
        'revision', () async {
      final events = <BundleAnnouncement>[];
      final subscription = source.subscribe().listen(events.add);
      addTearDown(subscription.cancel);

      fake.opened.single.add(
        wire.BundleAnnouncementNone(epoch: 'e7', revision: 3),
      );
      await pumpEventQueue();

      final none = events.single as NoBundleAnnounced;
      expect((none.epoch, none.revision), ('e7', 3));
    });

    test('fails the stream with a FormatException for an announcement that '
        'names no valid bundle, and goes on', () async {
      final events = <BundleAnnouncement>[];
      final errors = <Object>[];
      final subscription = source.subscribe().listen(
        events.add,
        onError: errors.add,
      );
      addTearDown(subscription.cancel);

      fake.opened.single
        ..add(_named(sha256: 'NOT-A-HASH'))
        ..add(_named(build: 0))
        ..add(_named(size: -1))
        ..add(_named(epoch: ''))
        ..add(_named(revision: 5));
      await pumpEventQueue();

      expect(errors, everyElement(isA<FormatException>()));
      expect(errors, hasLength(4));
      expect(events.single.revision, 5);
    });

    test('passes the end and the failure of the wire stream on', () async {
      final events = <BundleAnnouncement>[];
      final errors = <Object>[];
      var done = false;
      source.subscribe().listen(
        events.add,
        onError: errors.add,
        onDone: () => done = true,
      );

      fake.opened.single.addError(StateError('connection broke'));
      await fake.opened.single.close();
      await pumpEventQueue();

      expect(errors.single, isA<StateError>());
      expect(done, isTrue);
    });

    test('opens one wire subscription for each subscribe, and cancelling '
        'closes it', () async {
      final first = source.subscribe().listen((_) {});
      final second = source.subscribe().listen((_) {});
      await pumpEventQueue();
      expect(fake.opened, hasLength(2));

      await first.cancel();

      expect(fake.cancelled, [true, false]);
      await second.cancel();
      expect(fake.cancelled, [true, true]);
    });
  });
}
