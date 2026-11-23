/// The static data's notifier and the providers it is built from.
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../server/data/server_address.dart';
import '../../server/logic/server_status.dart';
import '../data/bundle_announcements.dart';
import '../data/bundle_downloader.dart';
import '../data/bundle_indexer.dart';
import '../data/bundle_store.dart';
import '../data/client_bundle_announcement_source.dart';
import 'static_data_state.dart';
import 'static_data_sync.dart';

/// The announcement stream of the configured server.
///
/// Defaults to the generated client for the resolved server; tests override
/// it. Read only when the app has a usable server address.
final bundleAnnouncementSourceProvider = Provider<BundleAnnouncementSource>(
  (ref) => switch (ref.watch(serverTargetProvider)) {
    ConfiguredServer(:final uri) => ClientBundleAnnouncementSource.forServer(
      uri,
    ),
    NoServer() ||
    InvalidServer() => throw StateError('No server is configured.'),
  },
);

/// The bundle download from the configured server.
///
/// Defaults to the `package:http` downloader for the resolved server; tests
/// override it. Read only when the app has a usable server address.
final bundleDownloaderProvider = Provider<BundleDownloader>(
  (ref) => switch (ref.watch(serverTargetProvider)) {
    final ConfiguredServer server => HttpBundleDownloader(server: server),
    NoServer() ||
    InvalidServer() => throw StateError('No server is configured.'),
  },
);

/// The device's kept copy of the bundle.
///
/// Has no default: `main()` and tests override it.
final bundleStoreProvider = Provider<BundleStore>(
  (ref) => throw UnimplementedError('bundleStoreProvider must be overridden'),
);

/// The opener that checks downloaded bundles; the one the store uses.
///
/// Has no default: `main()` and tests override it.
final bundleOpenerProvider = Provider<BundleOpener>(
  (ref) => throw UnimplementedError('bundleOpenerProvider must be overridden'),
);

/// The indexer of opened bundles.
final bundleIndexerProvider = Provider<BundleIndexer>(
  (ref) => const SearchBundleIndexer(),
);

/// The timers of reconnects and download retries; tests override it with a
/// fake clock.
final staticDataTimersProvider = Provider<TimerFactory>(
  (ref) =>
      (delay, run) => Timer(delay, run),
);

/// The wall clock used for retry and download timestamps.
final staticDataNowProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The sink for private synchronization diagnostics.
final staticDataLogProvider = Provider<void Function(String)>(
  (ref) =>
      (message) => developer.log(message, name: 'kaname.static_data'),
);

/// The app-scoped static data.
final staticDataProvider =
    NotifierProvider<StaticDataNotifier, StaticDataState>(
      StaticDataNotifier.new,
    );

/// Owns [StaticDataState]: follows the server's announced bundle and keeps
/// the bundle in use.
///
/// [build] starts one [StaticDataSync] run, which loads the kept bundle,
/// subscribes to the server's announcement stream when the app has a usable
/// server address, and downloads, checks, indexes, swaps in and saves each
/// announced bundle. The run reports every new state and this notifier is the
/// only writer of [state]. Like [ServerStatusNotifier] it never throws:
/// every failure becomes a typed [NoBundleReason] or leaves the bundle in
/// use unchanged, and the cause goes to the log only (design D21).
///
/// Carried constraint C14: a reconnect that announces the same bundle never
/// bypasses the download backoff; only another announcement retries at once
/// (design D5). A download retries after 1 minute, doubling to 30, and a
/// 503 counts as a failed download.
///
/// Carried constraint C25: only the current subscription generation's
/// events, errors and reconnect timers act; an old subscription's late event
/// is ignored whatever its epoch (design D15). Subscriptions are replaced by
/// [ServerStatusNotifier.check], which resubscribes at once.
///
/// Carried constraint C26: a download superseded by another bundle or by
/// "none" is aborted at the transport, not only ignored, before the next
/// pipeline starts; an announcement of the same bundle leaves the attempt
/// running, and a bundle announced again after "none" starts a new attempt
/// whose predecessor's results, at any stage, are dropped (design D6).
///
/// Work is fenced by its attempt. One pipeline (download, check, inflate,
/// index) runs at a time; a check, inflate or index that is superseded
/// finishes and is dropped before the latest target's pipeline starts. A
/// verified bundle is swapped in before it is saved, saves run one at a time
/// and only for the bundle in use, and a save that completes after the
/// bundle in use changed is followed by a save of the new one. Revisions are
/// compared per epoch. The kept bundle is loaded before any announcement is
/// acted on (design D6, D8, D15, D16, D20, D21).
///
/// A search runs on [BundleReady.index], which it captures when it starts.
class StaticDataNotifier extends Notifier<StaticDataState> {
  StaticDataSync? _run;

  /// Starts a waiting download retry immediately.
  void downloadNow() => _run?.downloadNow();

  @override
  StaticDataState build() {
    final server = switch (ref.watch(serverTargetProvider)) {
      ConfiguredServer() => BundleServer(
        source: ref.watch(bundleAnnouncementSourceProvider),
        downloader: ref.watch(bundleDownloaderProvider),
      ),
      NoServer() || InvalidServer() => null,
    };
    final run = StaticDataSync(
      server: server,
      store: ref.watch(bundleStoreProvider),
      opener: ref.watch(bundleOpenerProvider),
      indexer: ref.watch(bundleIndexerProvider),
      timers: ref.watch(staticDataTimersProvider),
      now: ref.watch(staticDataNowProvider),
      onState: (next) => state = next,
      log: ref.watch(staticDataLogProvider),
    );
    _run = run;
    ref.onDispose(run.dispose);
    if (server != null) {
      ref.listen(serverStatusProvider, (_, next) {
        if (next is Checking) run.resubscribe();
      });
    }
    run.start();
    return run.state;
  }
}
