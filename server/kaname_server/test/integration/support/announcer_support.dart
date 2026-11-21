import 'dart:async';
import 'dart:typed_data';

import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/realtime/server_clock.dart';
import 'package:kaname_server/src/static_data/bundle_announcer.dart';
import 'package:kaname_server/src/workers/worker_messages.dart';
import 'package:kaname_static_data/kaname_static_data.dart'
    show BuildSwitched, BuildUpToDate;
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart'
    show bundleFormatMajor, bundleFormatMinor, bundleSha256;
import 'package:serverpod/serverpod.dart' show Session;

/// A clock a test moves by hand: timers fire in due order as time elapses.
final class FakeClock implements ServerClock {
  FakeClock([DateTime? start]) : _now = start ?? DateTime.utc(2026, 1, 1);

  DateTime _now;
  int _nextId = 0;
  final List<_FakeTimer> _timers = [];

  @override
  DateTime now() => _now;

  /// How many timers are waiting to fire.
  int get activeTimers => _timers.where((t) => t.isActive).length;

  @override
  Timer once(Duration duration, void Function() callback) =>
      _add(duration, callback, periodic: false);

  @override
  Timer periodic(Duration duration, void Function() callback) =>
      _add(duration, callback, periodic: true);

  _FakeTimer _add(
    Duration duration,
    void Function() callback, {
    required bool periodic,
  }) {
    final timer = _FakeTimer(
      id: _nextId++,
      due: _now.add(duration),
      period: periodic ? duration : null,
      callback: callback,
    );
    _timers.add(timer);
    return timer;
  }

  /// Moves time forward by [duration], firing every timer that falls due, in
  /// due order and, for equal times, in creation order.
  void elapse(Duration duration) {
    final end = _now.add(duration);
    while (true) {
      final due =
          _timers.where((t) => t.isActive && !t.due.isAfter(end)).toList()
            ..sort((a, b) {
              final byTime = a.due.compareTo(b.due);
              return byTime != 0 ? byTime : a.id.compareTo(b.id);
            });
      if (due.isEmpty) break;
      final next = due.first;
      _now = next.due;
      if (next.period case final period?) {
        next.due = next.due.add(period);
      } else {
        next.fired = true;
      }
      next.callback();
    }
    _now = end;
    _timers.removeWhere((t) => !t.isActive);
  }
}

final class _FakeTimer implements Timer {
  _FakeTimer({
    required this.id,
    required this.due,
    required this.period,
    required this.callback,
  });

  final int id;
  DateTime due;
  final Duration? period;
  final void Function() callback;
  bool fired = false;
  bool cancelled = false;

  @override
  bool get isActive => !fired && !cancelled;

  @override
  int get tick => 0;

  @override
  void cancel() => cancelled = true;
}

/// A bus that records every message published on it and delivers through an
/// in-memory bus; [failNextPublish] makes the next publish throw.
final class RecordingBus implements RealtimeBus {
  final InMemoryRealtimeBus _inner = InMemoryRealtimeBus();

  /// Every announcement published, in order.
  final List<BundleAnnouncement> published = [];

  /// Whether the next publish throws.
  bool failNextPublish = false;

  @override
  Future<void> publish<T>(Topic<T> topic, T message) async {
    if (failNextPublish) {
      failNextPublish = false;
      throw StateError('the bus refused the message');
    }
    if (message is BundleAnnouncement) published.add(message);
    await _inner.publish(topic, message);
  }

  @override
  Stream<T> subscribe<T>(Topic<T> topic) => _inner.subscribe(topic);
}

/// The builds each published announcement names, in order.
List<int?> namedBuilds(Iterable<BundleAnnouncement> announcements) => [
  for (final announcement in announcements)
    switch (announcement) {
      BundleAnnouncementNamed(:final build) => build,
      BundleAnnouncementNone() => null,
    },
];

/// A [BundleStateSource] over another one that a test can fail or hold, and
/// that counts its calls.
final class ScriptedSource implements BundleStateSource {
  ScriptedSource(this.inner);

  /// The source the calls are passed to.
  final BundleStateSource inner;

  /// How many state reads were started.
  int reads = 0;

  /// How many byte loads were started.
  int loads = 0;

  /// While set, a state read completes only after the gate does; the read
  /// itself has already been done when it waits.
  Completer<void>? holdReads;

  /// While set, a state read waits for the gate before it queries the
  /// database, so it reads what is committed when the gate opens.
  Completer<void>? holdReadStarts;

  /// While set, a byte load completes only after the gate does.
  Completer<void>? holdLoads;

  /// While positive, that many state reads fail.
  int failReads = 0;

  /// While positive, that many byte loads fail.
  int failLoads = 0;

  @override
  Future<BundleStateRead> readState() async {
    reads++;
    final gate = holdReads;
    if (failReads > 0) {
      failReads--;
      throw StateError('the state read failed');
    }
    if (holdReadStarts case final start?) await start.future;
    final result = await inner.readState();
    if (gate != null) await gate.future;
    return result;
  }

  @override
  Future<Uint8List> loadBytes(BundleRef ref) async {
    loads++;
    final gate = holdLoads;
    if (failLoads > 0) {
      failLoads--;
      throw StateError('the byte load failed');
    }
    final result = await inner.loadBytes(ref);
    if (gate != null) await gate.future;
    return result;
  }
}

/// Inserts build [build] in [state] (`active`, `previous` or `staged`).
Future<void> seedBuild(Session session, int build, SdeBuildState state) =>
    SdeBuild.db.insertRow(
      session,
      SdeBuild(
        build: build,
        state: state,
        importedAt: DateTime.utc(2026, 1, 1),
        activeMarker: state == SdeBuildState.active ? true : null,
        previousMarker: state == SdeBuildState.previous ? true : null,
      ),
    );

/// Stores a built bundle of [build] with [content] as its bytes, in the
/// current format unless [formatMajor] says otherwise, and returns its
/// identity.
Future<BundleRef> seedBundle(
  Session session,
  int build, {
  String content = '',
  int? formatMajor,
}) async {
  final bytes = Uint8List.fromList('bundle $build $content'.codeUnits);
  final sha = bundleSha256(bytes);
  await storeBundleRows(session, build, bytes, formatMajor: formatMajor);
  return BundleRef(
    build: build,
    sha256: sha,
    size: bytes.length,
    formatMajor: formatMajor ?? bundleFormatMajor,
  );
}

/// Writes [build]'s bundle rows for [bytes], replacing the build's old ones.
Future<void> storeBundleRows(
  Session session,
  int build,
  Uint8List bytes, {
  int? formatMajor,
}) async {
  await SdeBundle.db.deleteWhere(session, where: (t) => t.build.equals(build));
  await SdeBundleBytes.db.deleteWhere(
    session,
    where: (t) => t.build.equals(build),
  );
  final sha = bundleSha256(bytes);
  await SdeBundle.db.insertRow(
    session,
    SdeBundle(
      build: build,
      outcome: SdeBundleOutcome.built,
      formatMajor: formatMajor ?? bundleFormatMajor,
      formatMinor: bundleFormatMinor,
      sha256: sha,
      size: bytes.length,
      builtAt: DateTime.utc(2026, 1, 1),
    ),
  );
  await SdeBundleBytes.db.insertRow(
    session,
    SdeBundleBytes(
      build: build,
      sha256: sha,
      bytes: ByteData.sublistView(bytes),
    ),
  );
}

/// Switches to [build], as a check does: the previous build goes with its
/// bundle, the active one becomes previous and [build] active.
Future<void> switchTo(Session session, int build) =>
    session.db.transaction((tx) async {
      Future<void> sql(String statement) =>
          session.db.unsafeExecute(statement, transaction: tx);
      await sql(
        'DELETE FROM "sde_bundle" WHERE "build" IN '
        '(SELECT "build" FROM "sde_build" WHERE "state" = \'previous\')',
      );
      await sql(
        'DELETE FROM "sde_bundle_bytes" WHERE "build" IN '
        '(SELECT "build" FROM "sde_build" WHERE "state" = \'previous\')',
      );
      await sql('DELETE FROM "sde_build" WHERE "state" = \'previous\'');
      await sql(
        'UPDATE "sde_build" SET "state" = \'previous\', '
        '"activeMarker" = NULL, "previousMarker" = TRUE '
        'WHERE "state" = \'active\'',
      );
      await sql(
        'UPDATE "sde_build" SET "state" = \'active\', '
        '"activeMarker" = TRUE, "previousMarker" = NULL '
        'WHERE "build" = $build',
      );
    });

/// Rolls back, as `sde:rollback` does: the active and the previous build
/// swap states.
Future<void> rollback(Session session) => session.db.transaction((tx) async {
  Future<void> sql(String statement) =>
      session.db.unsafeExecute(statement, transaction: tx);
  await sql(
    'UPDATE "sde_build" SET "state" = \'staged\', "previousMarker" = NULL '
    'WHERE "state" = \'previous\'',
  );
  await sql(
    'UPDATE "sde_build" SET "state" = \'previous\', "activeMarker" = NULL, '
    '"previousMarker" = TRUE WHERE "state" = \'active\'',
  );
  await sql(
    'UPDATE "sde_build" SET "state" = \'active\', "activeMarker" = TRUE '
    'WHERE "state" = \'staged\'',
  );
});

/// The reply of a check that switched to [build].
WorkerReply switchedReply(int build) =>
    BuildCheckFinished(requestId: 1, result: BuildSwitched(build));

/// The reply of a check that found [build] up to date.
WorkerReply upToDateReply(int build) =>
    BuildCheckFinished(requestId: 1, result: BuildUpToDate(build));

/// A started announcer over [session]'s database with a fake clock and a
/// recording bus, for tests that feed it the worker replies they produce.
final class TestAnnouncer {
  TestAnnouncer._(this.announcer, this.bus, this.clock, this.source);

  /// The announcer.
  final BundleAnnouncer announcer;

  /// The source it reads through, which a test can hold.
  final ScriptedSource source;

  /// Everything it published.
  final RecordingBus bus;

  /// Its clock.
  final FakeClock clock;

  /// Starts an announcer that reads through [session] and waits for its
  /// first refresh to end. Stop it with [BundleAnnouncer.stop].
  static Future<TestAnnouncer> start(
    Session session, {
    Future<WorkerReply> Function()? runRepair,
    void Function(String message)? log,
  }) async {
    final bus = RecordingBus();
    final clock = FakeClock();
    final source = ScriptedSource(
      OrmBundleStateSource(<T>(action) => action(session)),
    );
    final announcer = BundleAnnouncer(
      source: source,
      bus: bus,
      clock: clock,
      log: (level, message) => log?.call(message),
      runRepair: runRepair,
      epoch: 'test-epoch',
    )..start();
    await announcer.settled;
    return TestAnnouncer._(announcer, bus, clock, source);
  }

  /// Feeds [reply] to the announcer and waits for the refresh it causes.
  Future<void> reply(WorkerReply reply) => announcer.workerReplied(reply);

  /// The builds named by the announcements published so far.
  List<int?> get builds => namedBuilds(bus.published);

  /// The newest published announcement, which must name a bundle.
  BundleAnnouncementNamed get lastNamed =>
      bus.published.last as BundleAnnouncementNamed;
}
