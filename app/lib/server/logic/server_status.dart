/// The server's state as the app shows it, and the notifier that owns it.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaname_client/kaname_client.dart';

import '../data/server_address.dart';
import '../data/server_health.dart';

/// The server's state, switched over exhaustively by widgets.
///
/// Carried constraint C7: UI errors from server calls never show exception
/// text, hosts or ports; they map to typed states. That is why [Unreachable]
/// has no fields at all. See the spec requirement "app-server-connection → An
/// unreachable server is shown without internal detail".
sealed class ServerStatus {
  const ServerStatus();
}

/// No server address was configured; no call is made.
final class NotConfigured extends ServerStatus {
  /// Creates the not-configured status.
  const NotConfigured();
}

/// The configured server address is invalid; no call is made.
final class InvalidAddress extends ServerStatus {
  /// Creates the invalid-address status.
  const InvalidAddress();
}

/// A health call is running.
final class Checking extends ServerStatus {
  /// Creates the checking status, optionally carrying the [previous] answer.
  const Checking({this.previous});

  /// The last [Connected] answer, so the UI can keep showing it, if any.
  final Connected? previous;
}

/// The server answered with [report].
final class Connected extends ServerStatus {
  /// Creates a connected status for [report].
  const Connected(this.report);

  /// The server's health answer.
  final HealthReport report;
}

/// The health call failed or timed out; the cause is deliberately not kept.
final class Unreachable extends ServerStatus {
  /// Creates the unreachable status.
  const Unreachable();
}

/// The resolved server target.
///
/// Has no default: `main()` and tests override it.
final serverTargetProvider = Provider<ServerTarget>(
  (ref) => throw UnimplementedError('serverTargetProvider must be overridden'),
);

/// The health call implementation.
///
/// Has no default: `main()` and tests override it.
final serverHealthProvider = Provider<ServerHealth>(
  (ref) => throw UnimplementedError('serverHealthProvider must be overridden'),
);

/// How long the notifier waits for one health call before giving up.
///
/// Defaults to 10 seconds; tests override it with a short duration.
final serverCheckTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 10),
);

/// The app-scoped server status.
final serverStatusProvider =
    NotifierProvider<ServerStatusNotifier, ServerStatus>(
      ServerStatusNotifier.new,
    );

/// Owns [ServerStatus]: runs the health check at start and on request.
///
/// [build] makes no call when there is no usable address; otherwise it starts
/// the first check. [check] is single-flight: while a call runs it returns the
/// same future. Every failure (any exception, error or time-out) becomes
/// [Unreachable]; the notifier never throws, because Riverpod retries failing
/// providers.
class ServerStatusNotifier extends Notifier<ServerStatus> {
  late ServerHealth _health;
  late Duration _timeout;
  Future<void>? _inFlight;

  @override
  ServerStatus build() {
    _inFlight = null;
    final target = ref.watch(serverTargetProvider);
    _timeout = ref.watch(serverCheckTimeoutProvider);
    switch (target) {
      case NoServer():
        return const NotConfigured();
      case InvalidServer():
        return const InvalidAddress();
      case ConfiguredServer():
        _health = ref.watch(serverHealthProvider);
        _inFlight = _run();
        return const Checking();
    }
  }

  /// Checks the server again and returns when the answer is in.
  ///
  /// Returns the running call's future when one is in flight. Does nothing
  /// when there is no usable address.
  Future<void> check() {
    final running = _inFlight;
    if (running != null) return running;
    final current = state;
    if (current is NotConfigured || current is InvalidAddress) {
      return Future<void>.value();
    }
    final previous = switch (current) {
      Connected() => current,
      Checking(:final previous) => previous,
      _ => null,
    };
    state = Checking(previous: previous);
    return _inFlight = _run();
  }

  Future<void> _run() async {
    ServerStatus result;
    try {
      final report = await _health.check().timeout(_timeout);
      result = Connected(report);
    } on Object catch (error) {
      if (kDebugMode) debugPrint('Server health check failed: $error');
      result = const Unreachable();
    }
    if (!ref.mounted) return;
    _inFlight = null;
    state = result;
  }
}
