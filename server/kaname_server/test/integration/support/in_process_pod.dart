import 'package:kaname_server/src/generated/endpoints.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

import 'scratch_database.dart';

/// A Serverpod of this package running inside the test process, in the
/// `test` run mode, on its own scratch database, which it migrates.
///
/// Unlike `withServerpod`, it lets a test register middleware and extra
/// endpoints before `pod.start()`, and it serves real HTTP and WebSocket
/// traffic on its API listener, a free port chosen by the `test` config.
final class InProcessPod {
  InProcessPod._(this.pod, this._database);

  /// The running server.
  final Serverpod pod;

  final ScratchDatabase _database;

  /// The port the API server listens on.
  int get port => pod.server.port;

  /// The API server's base URL, as a generated client takes it.
  String get baseUrl => 'http://127.0.0.1:$port/';

  /// Starts a pod with the generated endpoints plus [extraEndpoints], and
  /// [middleware] added to the API server in order, before it starts.
  ///
  /// [configOverride] adjusts the loaded `test` config after the database
  /// name is set, for example to disable Redis.
  static Future<InProcessPod> start({
    Map<String, Endpoint> extraEndpoints = const {},
    Map<String, Map<String, EndpointMethodConnector>> extraMethods = const {},
    List<Middleware> middleware = const [],
    ServerpodConfig Function(ServerpodConfig)? configOverride,
  }) async {
    return _start(
      await ScratchDatabase.create(),
      extraEndpoints: extraEndpoints,
      extraMethods: extraMethods,
      middleware: middleware,
      configOverride: configOverride,
    );
  }

  /// Restarts with only the generated endpoints, keeping the same database.
  Future<InProcessPod> restart() async {
    await shutdown();
    return _start(_database);
  }

  static Future<InProcessPod> _start(
    ScratchDatabase database, {
    Map<String, Endpoint> extraEndpoints = const {},
    Map<String, Map<String, EndpointMethodConnector>> extraMethods = const {},
    List<Middleware> middleware = const [],
    ServerpodConfig Function(ServerpodConfig)? configOverride,
  }) async {
    final pod = Serverpod(
      ['--mode', 'test', '--apply-migrations'],
      Protocol(),
      _ProbeEndpoints(extraEndpoints, extraMethods),
      configOverride: (config) {
        final named = config.copyWith(
          database: (config.database! as PostgresDatabaseConfig).withName(
            database.name,
          ),
        );
        return configOverride?.call(named) ?? named;
      },
    );
    for (final each in middleware) {
      pod.server.addMiddleware(each);
    }
    await pod.start(runInGuardedZone: false);
    return InProcessPod._(pod, database);
  }

  bool _shutDown = false;

  /// Shuts the server down, once; its database stays until [stop].
  Future<void> shutdown() async {
    if (_shutDown) return;
    _shutDown = true;
    await pod.shutdown(exitProcess: false);
  }

  /// Shuts the server down and drops its database.
  Future<void> stop() async {
    await shutdown();
    await _database.drop();
  }
}

/// The generated [Endpoints] plus test-only endpoints, wired by hand the way
/// the generated code wires its own.
final class _ProbeEndpoints extends Endpoints {
  _ProbeEndpoints(this._extraEndpoints, this._extraMethods);

  final Map<String, Endpoint> _extraEndpoints;
  final Map<String, Map<String, EndpointMethodConnector>> _extraMethods;

  @override
  void initializeEndpoints(Server server) {
    super.initializeEndpoints(server);
    for (final MapEntry(key: name, value: endpoint)
        in _extraEndpoints.entries) {
      endpoint.initialize(server, name, null);
      connectors[name] = EndpointConnector(
        name: name,
        endpoint: endpoint,
        methodConnectors: _extraMethods[name] ?? const {},
      );
    }
  }
}
