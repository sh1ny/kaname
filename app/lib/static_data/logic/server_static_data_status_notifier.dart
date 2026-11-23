import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kaname_client/kaname_client.dart';

import '../../server/data/server_address.dart';
import '../../server/logic/server_status.dart';
import '../data/rpc_call.dart';
import '../data/status_client.dart';
import 'static_data_notifier.dart';

/// Whether Settings is the current foreground destination.
final staticDataSettingsVisibleProvider =
    NotifierProvider<StaticDataSettingsVisibleNotifier, bool>(
      StaticDataSettingsVisibleNotifier.new,
    );

/// Holds the router and lifecycle visibility shared by Settings' pollers.
class StaticDataSettingsVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Updates whether Settings is visible in the foreground.
  void setVisible(bool visible) => state = visible;
}

/// The injectable client for public server status reads.
final staticDataStatusClientProvider = Provider<StaticDataStatusClient?>((ref) {
  switch (ref.watch(serverTargetProvider)) {
    case ConfiguredServer(:final uri):
      final client = ClientStaticDataStatus(uri);
      ref.onDispose(client.close);
      return client;
    case NoServer() || InvalidServer():
      return null;
  }
});

/// The state of the server status section.
sealed class ServerStaticDataStatusState {
  const ServerStaticDataStatusState();
}

/// The first status read is pending.
final class StatusLoading extends ServerStaticDataStatusState {
  /// Creates a loading state.
  const StatusLoading();
}

/// The latest status and whether another read is pending.
final class StatusShown extends ServerStaticDataStatusState {
  /// Creates a displayed status.
  const StatusShown(this.status, {this.refreshing = false});

  /// The last successful server snapshot.
  final StaticDataStatus status;

  /// Whether a new snapshot is being read.
  final bool refreshing;
}

/// Status could not be read and needs a manual refresh.
final class StatusUnavailable extends ServerStaticDataStatusState {
  /// Creates an unavailable state.
  const StatusUnavailable();
}

/// The server status and its polling controller.
final serverStaticDataStatusProvider =
    NotifierProvider<
      ServerStaticDataStatusNotifier,
      ServerStaticDataStatusState
    >(ServerStaticDataStatusNotifier.new);

/// Reads status one transport call at a time while Settings is visible.
class ServerStaticDataStatusNotifier
    extends Notifier<ServerStaticDataStatusState> {
  StaticDataStatusClient? _client;
  Timer? _timer;
  bool _visible = false;
  bool _inFlight = false;
  bool _pending = false;
  bool _stopped = false;
  bool _disposed = false;
  int _failures = 0;
  int _generation = 0;
  StaticDataStatus? _last;

  @override
  ServerStaticDataStatusState build() {
    _disposed = false;
    _generation++;
    _inFlight = false;
    _pending = false;
    _stopped = false;
    _failures = 0;
    _last = null;
    _client = ref.watch(staticDataStatusClientProvider);
    _visible = ref.read(staticDataSettingsVisibleProvider);
    ref.listen(staticDataSettingsVisibleProvider, (_, visible) {
      _visible = visible;
      _timer?.cancel();
      if (visible && !_stopped) {
        if (!_inFlight) _start();
      } else if (!visible) {
        _pending = false;
      }
    });
    ref.listen(staticDataProvider.select((value) => value.announced), (
      before,
      after,
    ) {
      if (before != after && _visible && !_stopped) _trigger();
    });
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });
    if (_visible) scheduleMicrotask(_trigger);
    return const StatusLoading();
  }

  /// Retries the status read, including after automatic polling has stopped.
  void refresh() {
    _stopped = false;
    _failures = 0;
    if (_visible) _trigger();
  }

  void _trigger() {
    if (_disposed || !_visible || _stopped) return;
    _timer?.cancel();
    if (_inFlight) {
      _pending = true;
    } else {
      _start();
    }
  }

  void _start() {
    if (_disposed || !_visible || _stopped) return;
    final client = _client;
    if (client == null) {
      state = const StatusUnavailable();
      _stopped = true;
      return;
    }
    _inFlight = true;
    final generation = ++_generation;
    if (_last != null) state = StatusShown(_last!, refreshing: true);
    final call = client.read();
    unawaited(_finish(call, generation));
  }

  Future<void> _finish(RpcCall<StaticDataStatus> call, int generation) async {
    final answer = await call.answer;
    if (!_disposed && generation == _generation) {
      switch (answer) {
        case RpcAnswered<StaticDataStatus>(:final value):
          _last = value;
          _failures = 0;
          state = StatusShown(value);
        case RpcUnanswered<StaticDataStatus>():
          _failures++;
          if (_failures >= 3) {
            _stopped = true;
            _pending = false;
            state = const StatusUnavailable();
          } else if (_last != null) {
            state = StatusShown(_last!);
          } else {
            state = const StatusUnavailable();
          }
      }
    }
    await call.settled;
    if (_disposed || generation != _generation) return;
    _inFlight = false;
    if (!_visible || _stopped) return;
    if (_pending) {
      _pending = false;
      _start();
    } else {
      _timer = Timer(Duration(seconds: _last?.busy == true ? 5 : 30), _trigger);
    }
  }
}

/// Binds the current router path and app lifecycle to Settings visibility.
class StaticDataSettingsVisibilityBinding extends ConsumerStatefulWidget {
  /// Creates a binding for [router] around [child].
  const StaticDataSettingsVisibilityBinding({
    required this.router,
    required this.child,
    super.key,
  });

  /// The router whose current location determines visibility.
  final GoRouter router;

  /// The application below the binding.
  final Widget child;

  @override
  ConsumerState<StaticDataSettingsVisibilityBinding> createState() =>
      _StaticDataSettingsVisibilityBindingState();
}

class _StaticDataSettingsVisibilityBindingState
    extends ConsumerState<StaticDataSettingsVisibilityBinding>
    with WidgetsBindingObserver {
  late bool _foreground;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.router.routeInformationProvider.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _update();
    });
  }

  @override
  void didUpdateWidget(StaticDataSettingsVisibilityBinding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routeInformationProvider.removeListener(_update);
      widget.router.routeInformationProvider.addListener(_update);
      _update();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _update();
  }

  void _update() {
    ref
        .read(staticDataSettingsVisibleProvider.notifier)
        .setVisible(
          _foreground &&
              widget.router.routeInformationProvider.value.uri.path ==
                  '/settings',
        );
  }

  @override
  void dispose() {
    widget.router.routeInformationProvider.removeListener(_update);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(serverStaticDataStatusProvider);
    return widget.child;
  }
}
