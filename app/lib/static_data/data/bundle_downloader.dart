/// The bundle download over `package:http`.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../server/data/server_address.dart';
import 'bundle_http_client.dart';
import 'bundle_store.dart';

/// The URL of the bundle [bundle] on [server]:
/// `static-data/bundle/<build>/<sha256>` under the server's base address.
///
/// A native app keeps its configured base path; the web app's base is its
/// own origin's `/api/` ([ServerAddress]).
Uri bundleUrl(ConfiguredServer server, BundleIdentity bundle) =>
    server.uri.resolveUri(
      Uri(
        pathSegments: [
          'static-data',
          'bundle',
          '${bundle.build}',
          bundle.sha256,
        ],
      ),
    );

/// The outcome of one bundle download.
sealed class BundleDownloadResult {
  const BundleDownloadResult();
}

/// The whole body arrived.
final class BundleDownloaded extends BundleDownloadResult {
  /// Creates the result holding the compressed bundle [bytes].
  const BundleDownloaded(this.bytes);

  /// The body as received; not yet checked.
  final Uint8List bytes;
}

/// The download failed.
final class BundleDownloadFailed extends BundleDownloadResult {
  /// Creates the result for [failure].
  const BundleDownloadFailed(this.failure);

  /// Why the download failed.
  final BundleDownloadFailure failure;
}

/// The download was cancelled before it ended.
final class BundleDownloadCancelled extends BundleDownloadResult {
  /// Creates the result.
  const BundleDownloadCancelled();
}

/// Why a download failed; [detail] is for the log only, never for the UI.
sealed class BundleDownloadFailure {
  const BundleDownloadFailure();

  /// What went wrong, for the log.
  String get detail;
}

/// The server answered with another status than 200, for example 404 for a
/// bundle it no longer serves or 503 when it is busy (design D4, D5).
final class BundleHttpStatus extends BundleDownloadFailure {
  /// Creates the failure for [statusCode].
  const BundleHttpStatus(this.statusCode);

  /// The HTTP status the server answered.
  final int statusCode;

  @override
  String get detail => 'HTTP $statusCode';
}

/// The connection failed or broke.
final class BundleNetworkError extends BundleDownloadFailure {
  /// Creates the failure explained by [detail].
  const BundleNetworkError(this.detail);

  @override
  final String detail;
}

/// The download did not end within its time limit.
final class BundleDownloadTimedOut extends BundleDownloadFailure {
  /// Creates the failure after [limit].
  const BundleDownloadTimedOut(this.limit);

  /// The time limit that passed.
  final Duration limit;

  @override
  String get detail => 'no complete body after $limit';
}

/// One running download.
abstract interface class BundleTransfer {
  /// Completes once with the download's outcome; never with an error.
  Future<BundleDownloadResult> get result;

  /// Aborts the download at once, also while its connection is still being
  /// set up or its body is still arriving, and closes its connection; [result] then completes with
  /// [BundleDownloadCancelled]. Does nothing once [result] has completed.
  void cancel();
}

/// Downloads bundles from the server.
abstract interface class BundleDownloader {
  /// Starts downloading the bundle [bundle].
  BundleTransfer start(BundleIdentity bundle);
}

/// A [BundleDownloader] over `package:http`, from the server [server].
final class HttpBundleDownloader implements BundleDownloader {
  /// Creates the downloader for [server]; each transfer sends through its
  /// own client from [clientFor], which the transfer's abort ends at every
  /// stage of the connection.
  HttpBundleDownloader({
    required this.server,
    this.timeout = defaultTimeout,
    this._clientFor = abortableBundleClient,
  });

  /// The time limit of one download (design D4's 2 minutes).
  static const defaultTimeout = Duration(minutes: 2);

  /// The server the bundles come from.
  final ConfiguredServer server;

  /// How long one download may take before it is aborted.
  final Duration timeout;

  final http.Client Function(Future<void> abort) _clientFor;

  @override
  BundleTransfer start(BundleIdentity bundle) =>
      _HttpBundleTransfer(_clientFor, bundleUrl(server, bundle), timeout);
}

/// Why a transfer's abort trigger fired.
enum _Abort { cancelled, timedOut }

final class _HttpBundleTransfer implements BundleTransfer {
  _HttpBundleTransfer(
    http.Client Function(Future<void> abort) clientFor,
    this._url,
    this._timeout,
  ) {
    _client = clientFor(_abortTrigger.future);
    _timer = Timer(_timeout, () => _abort(_Abort.timedOut));
    unawaited(_run());
  }

  late final http.Client _client;
  final Uri _url;
  final Duration _timeout;
  late final Timer _timer;
  final Completer<void> _abortTrigger = Completer();
  final Completer<BundleDownloadResult> _result = Completer();
  _Abort? _aborted;

  @override
  Future<BundleDownloadResult> get result => _result.future;

  @override
  void cancel() => _abort(_Abort.cancelled);

  void _abort(_Abort why) {
    if (_result.isCompleted || _aborted != null) return;
    _aborted = why;
    _abortTrigger.complete();
  }

  Future<void> _run() async {
    final request = http.AbortableRequest(
      'GET',
      _url,
      abortTrigger: _abortTrigger.future,
    );
    BundleDownloadResult outcome;
    try {
      final response = await _client.send(request);
      // A failed status is known from the headers; its body, which may be
      // slow or large, is never read: closing the client below ends it.
      outcome = response.statusCode == 200
          ? BundleDownloaded(await response.stream.toBytes())
          : BundleDownloadFailed(BundleHttpStatus(response.statusCode));
    } on http.RequestAbortedException {
      outcome = _abortedOutcome();
    } on http.ClientException catch (error) {
      outcome = _aborted != null
          ? _abortedOutcome()
          : BundleDownloadFailed(BundleNetworkError(error.message));
    } on Exception catch (error) {
      // Any other failure of the platform client is still a failed
      // download, never an error out of [result].
      outcome = _aborted != null
          ? _abortedOutcome()
          : BundleDownloadFailed(BundleNetworkError('$error'));
    }
    _timer.cancel();
    _client.close();
    _result.complete(outcome);
  }

  BundleDownloadResult _abortedOutcome() => switch (_aborted) {
    _Abort.timedOut => BundleDownloadFailed(BundleDownloadTimedOut(_timeout)),
    _Abort.cancelled || null => const BundleDownloadCancelled(),
  };
}
