import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/static_data/data/bundle_announcements.dart';
import 'package:kaname_app/static_data/data/bundle_downloader.dart';
import 'package:kaname_app/static_data/data/bundle_indexer.dart';
import 'package:kaname_app/static_data/data/bundle_store.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';

/// A fake clock for the notifier's reconnect and retry timers.
///
/// Time moves only through [elapse]; a timer fires when its time comes.
final class FakeClock {
  Duration _now = Duration.zero;
  final List<_FakeTimer> _timers = [];

  /// The delay of every timer started so far, in order.
  final List<Duration> delays = [];

  /// How many started timers are still waiting.
  int get pending => _timers.where((timer) => timer.isActive).length;

  /// The timer factory to give the notifier.
  Timer start(Duration delay, void Function() run) {
    delays.add(delay);
    final timer = _FakeTimer(_now + delay, run);
    _timers.add(timer);
    return timer;
  }

  /// Moves time on by [duration], firing the timers that fall due in order
  /// and letting the notifier react after each.
  Future<void> elapse(Duration duration) async {
    final target = _now + duration;
    await pumpEventQueue();
    while (true) {
      final due =
          _timers
              .where((timer) => timer.isActive && timer.due <= target)
              .toList()
            ..sort((a, b) => a.due.compareTo(b.due));
      if (due.isEmpty) break;
      final next = due.first;
      _now = next.due;
      next.fire();
      await pumpEventQueue();
    }
    _now = target;
    await pumpEventQueue();
  }
}

final class _FakeTimer implements Timer {
  _FakeTimer(this.due, this._run);

  final Duration due;
  final void Function() _run;
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;

  void fire() {
    _active = false;
    _run();
  }
}

/// One subscription's stream, delivering to its listener whatever the
/// listener does, even after it cancelled: a late event of a replaced
/// subscription is what the notifier must ignore.
final class FakeAnnouncementStream extends Stream<BundleAnnouncement> {
  void Function(BundleAnnouncement)? _onData;
  void Function(Object, StackTrace)? _onError;
  void Function()? _onDone;

  /// Whether the notifier cancelled its subscription.
  bool cancelled = false;

  @override
  StreamSubscription<BundleAnnouncement> listen(
    void Function(BundleAnnouncement event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    _onData = onData;
    _onError = onError == null
        ? null
        : (error, stackTrace) => Function.apply(onError, [error, stackTrace]);
    _onDone = onDone;
    return _FakeSubscription(this);
  }

  /// Delivers [announcement].
  void emit(BundleAnnouncement announcement) => _onData?.call(announcement);

  /// Delivers a failure.
  void fail([Object error = 'stream failed']) =>
      _onError?.call(error, StackTrace.empty);

  /// Delivers the stream's ending.
  void end() => _onDone?.call();
}

final class _FakeSubscription
    implements StreamSubscription<BundleAnnouncement> {
  _FakeSubscription(this._stream);

  final FakeAnnouncementStream _stream;

  @override
  Future<void> cancel() {
    _stream.cancelled = true;
    return Future<void>.value();
  }

  @override
  void onData(void Function(BundleAnnouncement data)? handleData) {}

  @override
  void onError(Function? handleError) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}

  @override
  bool get isPaused => false;

  @override
  Future<E> asFuture<E>([E? futureValue]) => Completer<E>().future;
}

/// A [BundleAnnouncementSource] whose subscriptions the test drives.
final class FakeAnnouncementSource implements BundleAnnouncementSource {
  /// Every subscription opened so far, in order.
  final List<FakeAnnouncementStream> streams = [];

  /// How many times the notifier subscribed.
  int get subscribes => streams.length;

  /// The newest subscription.
  FakeAnnouncementStream get current {
    expect(streams, isNotEmpty, reason: 'the notifier never subscribed');
    return streams.last;
  }

  @override
  Stream<BundleAnnouncement> subscribe() {
    final stream = FakeAnnouncementStream();
    streams.add(stream);
    return stream;
  }
}

/// One download the test completes when it says so.
final class FakeTransfer implements BundleTransfer {
  /// Creates a transfer of [identity]; with [finishesOnCancel] false,
  /// [cancel] leaves [result] pending until [finishCancel], as a transport
  /// that takes a moment to abort does.
  FakeTransfer(
    this.identity, {
    required this.finishesOnCancel,
    this.reload = 0,
  });

  /// Which bundle is downloading.
  final BundleIdentity identity;

  /// The reload number it was started with.
  final int reload;

  /// Whether [cancel] ends [result] at once.
  final bool finishesOnCancel;

  /// Whether [cancel] was called.
  bool cancelled = false;

  final Completer<BundleDownloadResult> _result = Completer();

  @override
  Future<BundleDownloadResult> get result => _result.future;

  @override
  void cancel() {
    if (_result.isCompleted) return;
    cancelled = true;
    if (finishesOnCancel) finishCancel();
  }

  /// Ends the cancelled transfer.
  void finishCancel() {
    if (!_result.isCompleted) _result.complete(const BundleDownloadCancelled());
  }

  /// Completes with the body [bytes].
  void complete(Uint8List bytes) => _result.complete(BundleDownloaded(bytes));

  /// Completes with a failure.
  void fail([
    BundleDownloadFailure failure = const BundleNetworkError('connection'),
  ]) => _result.complete(BundleDownloadFailed(failure));
}

/// A [BundleDownloader] whose transfers the test completes.
final class FakeBundleDownloader implements BundleDownloader {
  /// Whether a cancelled transfer ends at once.
  bool finishesOnCancel = true;

  /// Every transfer started so far, in order.
  final List<FakeTransfer> started = [];

  /// The builds of [started], in order.
  List<int> get builds => [for (final t in started) t.identity.build];

  /// The newest transfer.
  FakeTransfer get last {
    expect(started, isNotEmpty, reason: 'no download was started');
    return started.last;
  }

  @override
  BundleTransfer start(BundleIdentity bundle, {int reload = 0}) {
    final transfer = FakeTransfer(
      bundle,
      finishesOnCancel: finishesOnCancel,
      reload: reload,
    );
    started.add(transfer);
    return transfer;
  }
}

/// A [BundleStore] keeping its copy in memory, whose load and saves the
/// test can hold.
final class FakeBundleStore implements BundleStore {
  /// Creates a store keeping [kept].
  FakeBundleStore({this.kept});

  /// The kept copy.
  BundleCopy? kept;

  /// Whether a load waits for [releaseLoads].
  bool holdLoad = false;

  /// Whether a loaded bundle carries its index, as the native store's does.
  bool withIndex = false;

  /// Whether saves wait for [releaseSaves].
  bool holdSave = false;

  /// Whether saves are refused, as a browser that denies Cache Storage
  /// refuses them; nothing is kept then.
  bool refuseSaves = false;

  /// How many loads were asked for.
  int loads = 0;

  /// The identity of every save started, in order.
  final List<BundleIdentity> savesStarted = [];

  /// The identity of every save completed, in order.
  final List<BundleIdentity> savesDone = [];

  final List<Completer<void>> _loadGates = [];
  final List<Completer<void>> _saveGates = [];

  /// Lets held loads go on, and later loads run at once.
  void releaseLoads() {
    holdLoad = false;
    for (final gate in _loadGates) {
      gate.complete();
    }
    _loadGates.clear();
  }

  /// Lets held saves go on, and later saves run at once.
  void releaseSaves() {
    holdSave = false;
    for (final gate in _saveGates) {
      gate.complete();
    }
    _saveGates.clear();
  }

  @override
  Future<KeptBundleLoad> load() async {
    loads++;
    if (holdLoad) {
      final gate = Completer<void>();
      _loadGates.add(gate);
      await gate.future;
    }
    final copy = kept;
    if (copy == null) return const NoKeptBundle();
    final opened = openBundle(
      copy.bytes,
      build: copy.identity.build,
      sha256: copy.identity.sha256,
    );
    return switch (opened) {
      BundleOpened(:final bundle) => KeptBundleLoaded(
        identity: copy.identity,
        bundle: bundle,
        index: withIndex ? SearchIndex.of(bundle) : null,
      ),
      BundleRefused(:final refusal) => KeptBundleRejected(refusal),
    };
  }

  @override
  Future<BundleSaveOutcome> save(BundleCopy copy) async {
    savesStarted.add(copy.identity);
    if (holdSave) {
      final gate = Completer<void>();
      _saveGates.add(gate);
      await gate.future;
    }
    if (refuseSaves) return const BundleNotSaved('storage refused');
    kept = copy;
    savesDone.add(copy.identity);
    return const BundleSaved();
  }
}

/// A [BundleIndexer] that can be held or made to fail.
final class FakeBundleIndexer implements BundleIndexer {
  /// Whether an index waits for [release].
  bool hold = false;

  /// Whether the next index fails.
  bool failNext = false;

  /// How many indexes were asked for.
  int calls = 0;

  final List<Completer<void>> _gates = [];

  /// Whether an index is waiting for [release].
  bool get waiting => _gates.isNotEmpty;

  /// Lets held indexes go on, and later ones run at once.
  void release() {
    hold = false;
    for (final gate in _gates) {
      gate.complete();
    }
    _gates.clear();
  }

  @override
  Future<SearchIndex> index(ClientBundle bundle) async {
    calls++;
    if (hold) {
      final gate = Completer<void>();
      _gates.add(gate);
      await gate.future;
    }
    if (failNext) {
      failNext = false;
      throw StateError('indexing failed');
    }
    return SearchIndex.of(bundle);
  }
}
