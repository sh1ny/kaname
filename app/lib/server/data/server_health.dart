/// The server health call behind a plain-Dart interface.
library;

import 'package:kaname_client/kaname_client.dart';

/// Asks the server how it is.
///
/// Plain Dart with no state management, so it can be replaced by a fake in
/// tests (ADR 0010: `data/` never imports Riverpod).
abstract interface class ServerHealth {
  /// Calls the server's health endpoint and returns its report.
  ///
  /// Completes with an error when the server cannot be reached or answers
  /// unexpectedly; callers map every failure to a typed state.
  Future<HealthReport> check();
}

/// A [ServerHealth] over the generated Serverpod [Client].
///
/// The client gives up waiting after 10 seconds (`connectionTimeout`). That
/// limits opening the connection and the wait for an answer, but does not abort
/// the HTTP request underneath; the notifier owns the overall backstop and the
/// single-flight rule.
final class ClientServerHealth implements ServerHealth {
  /// Creates an adapter for the server at [base], an absolute URL ending in
  /// `/`.
  ClientServerHealth(Uri base)
    : _client = Client(
        base.toString(),
        connectionTimeout: const Duration(seconds: 10),
      );

  final Client _client;

  @override
  Future<HealthReport> check() => _client.health.check();
}
