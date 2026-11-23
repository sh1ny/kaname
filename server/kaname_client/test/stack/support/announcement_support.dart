import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kaname_client/kaname_client.dart';
import 'package:test/test.dart';

import 'stack_support.dart';

/// The Compose network the stack's services share.
const stackNetwork = '${stackProject}_default';

/// The per-client bound on announcement streams the server ships with.
const streamsPerClient = 16;

/// How long a stack test waits for a stream to be admitted or refused, or
/// for a closed stream to free its place. A deadline against a hang, never
/// a timing assertion.
const streamDeadline = Duration(seconds: 60);

/// The outcome of one announcement subscription.
enum Admission {
  /// The stream sent its first announcement.
  admitted,

  /// The stream ended without an event or an error.
  refused,
}

/// One announcement stream opened through a generated client, listened to
/// from construction.
final class AnnouncementFeed {
  AnnouncementFeed(Stream<BundleAnnouncement> stream) {
    _subscription = stream.listen(
      (event) {
        events.add(event);
        if (!_outcome.isCompleted) _outcome.complete(Admission.admitted);
      },
      onError: (Object error) {
        errors.add(error);
        if (!_outcome.isCompleted) _outcome.completeError(error);
      },
      onDone: () {
        if (!_ended.isCompleted) _ended.complete();
        if (!_outcome.isCompleted) _outcome.complete(Admission.refused);
      },
    );
    _outcome.future.ignore();
  }

  /// The announcements received, in order.
  final List<BundleAnnouncement> events = [];

  /// The errors received.
  final List<Object> errors = [];

  final Completer<Admission> _outcome = Completer<Admission>();
  final Completer<void> _ended = Completer<void>();
  late final StreamSubscription<BundleAnnouncement> _subscription;

  /// Whether the stream was admitted or refused; fails on a stream error,
  /// and after [streamDeadline] when neither happened.
  Future<Admission> get outcome => _outcome.future.timeout(
    streamDeadline,
    onTimeout: () => fail('the stream neither sent an event nor ended'),
  );

  /// Whether the stream has ended.
  bool get isEnded => _ended.isCompleted;

  /// Stops listening, which ends the stream on the server.
  Future<void> close() => _subscription.cancel();
}

/// A generated client for [origin], closed at the end of the test.
Client stackClient(String origin) {
  final client = Client('$origin/api/');
  addTearDown(client.close);
  return client;
}

/// Opens streams on [client] until it holds [streamsPerClient] admitted
/// ones, and returns them.
///
/// A refused stream is retried after a short pause until [streamDeadline]:
/// a stream closed by an earlier test frees its place on the server only
/// once the server sees the WebSocket close.
Future<List<AnnouncementFeed>> holdEveryPlace(Client client) async {
  final held = <AnnouncementFeed>[];
  final deadline = DateTime.now().add(streamDeadline);
  while (held.length < streamsPerClient) {
    final feed = AnnouncementFeed(client.staticData.bundleAnnouncements());
    addTearDown(feed.close);
    switch (await feed.outcome) {
      case Admission.admitted:
        held.add(feed);
      case Admission.refused:
        if (DateTime.now().isAfter(deadline)) {
          fail('only ${held.length} of $streamsPerClient streams admitted');
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }
  return held;
}

/// The gateway address of [stackNetwork], through which host clients reach
/// Caddy's published port.
Future<String> stackGateway() async {
  final result = await run('docker', [
    'network',
    'inspect',
    stackNetwork,
    '--format',
    '{{(index .IPAM.Config 0).Gateway}}',
  ]);
  expect(result.exitCode, 0, reason: result.output);
  return result.output.trim();
}

/// Everything the stack's server wrote to its log so far.
Future<String> serverLogs() async {
  final result = await compose(['logs', '--no-color', 'server']);
  expect(result.exitCode, 0, reason: result.output);
  return result.output;
}

/// The Caddy image of `deploy/compose.yaml`, pinned by digest.
String caddyImage() {
  final compose = File('${repositoryRoot()}/deploy/compose.yaml')
      .readAsStringSync();
  final match = RegExp(r'image:\s*(caddy:\S+)').firstMatch(compose);
  if (match == null) fail('deploy/compose.yaml names no caddy image');
  return match.group(1)!;
}

/// Starts a relay on the stack network: a container with its own dynamic
/// address that forwards a loopback port to the stack's Caddy. A client on
/// the host that connects to the returned origin reaches Caddy from the
/// relay's address, as a container client on the stack network would.
/// Removed at the end of the test.
Future<String> startRelay() async {
  final scratch = await Directory.systemTemp.createTemp('kaname-relay-');
  addTearDown(() => scratch.delete(recursive: true));
  File('${scratch.path}/Caddyfile').writeAsStringSync('''
{
\tauto_https off
\tadmin off
}

:8090 {
\treverse_proxy caddy:80
}
''');
  final name = 'kaname-relay-$pid';
  final started = await run('docker', [
    'run',
    '--rm',
    '--detach',
    '--name',
    name,
    '--network',
    stackNetwork,
    '--publish',
    '127.0.0.1::8090',
    '--volume',
    '${scratch.path}/Caddyfile:/etc/caddy/Caddyfile:ro',
    caddyImage(),
  ]);
  expect(started.exitCode, 0, reason: started.output);
  addTearDown(() => run('docker', ['rm', '--force', name]));
  final mapped = await run('docker', ['port', name, '8090/tcp']);
  expect(mapped.exitCode, 0, reason: mapped.output);
  final port = int.parse(
    mapped.output.trim().split('\n').first.split(':').last,
  );
  final origin = 'http://127.0.0.1:$port';
  await _untilServing(origin);
  return origin;
}

/// Starts the shipped `deploy/Caddyfile` in front of an echo upstream and
/// returns its origin on a loopback port.
///
/// Both run on their own network, where the upstream answers to `server`,
/// so every route of the Caddyfile reaches it. The upstream answers each
/// request with the `X-Forwarded-For` header it received, as Caddy sent it.
/// All of it is removed at the end of the test.
Future<String> startCaddyBeforeEcho() async {
  final scratch = await Directory.systemTemp.createTemp('kaname-echo-');
  addTearDown(() => scratch.delete(recursive: true));
  File('${scratch.path}/Caddyfile').writeAsStringSync('''
{
\tauto_https off
\tadmin off
}

:8080 {
\trespond "{header.X-Forwarded-For}"
}
''');
  final network = 'kaname-echo-$pid';
  final created = await run('docker', ['network', 'create', network]);
  expect(created.exitCode, 0, reason: created.output);
  // Teardowns run last first: the containers go before their network.
  addTearDown(() => run('docker', ['network', 'rm', network]));

  final upstream = 'kaname-echo-upstream-$pid';
  final echo = await run('docker', [
    'run',
    '--rm',
    '--detach',
    '--name',
    upstream,
    '--network',
    network,
    '--network-alias',
    'server',
    '--volume',
    '${scratch.path}/Caddyfile:/etc/caddy/Caddyfile:ro',
    caddyImage(),
  ]);
  expect(echo.exitCode, 0, reason: echo.output);
  addTearDown(() => run('docker', ['rm', '--force', upstream]));

  final front = 'kaname-echo-front-$pid';
  final started = await run('docker', [
    'run',
    '--rm',
    '--detach',
    '--name',
    front,
    '--network',
    network,
    '--publish',
    '127.0.0.1::80',
    '--volume',
    '${repositoryRoot()}/deploy/Caddyfile:/etc/caddy/Caddyfile:ro',
    caddyImage(),
  ]);
  expect(started.exitCode, 0, reason: started.output);
  addTearDown(() => run('docker', ['rm', '--force', front]));

  final mapped = await run('docker', ['port', front, '80/tcp']);
  expect(mapped.exitCode, 0, reason: mapped.output);
  final port = int.parse(
    mapped.output.trim().split('\n').first.split(':').last,
  );
  final origin = 'http://127.0.0.1:$port';
  await _untilServing(origin);
  return origin;
}

/// Polls [origin]'s `/readyz` until it answers 200.
Future<void> _untilServing(String origin) async {
  final deadline = DateTime.now().add(streamDeadline);
  Object? last;
  while (DateTime.now().isBefore(deadline)) {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('$origin/readyz'));
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode == 200) return;
      last = 'status ${response.statusCode}';
    } on IOException catch (error) {
      last = error;
    } finally {
      client.close(force: true);
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  fail('$origin never served /readyz (last: $last)');
}

/// A loopback forwarder to the stack's Caddy that adds an
/// `X-Forwarded-For` line to the first request of each connection, with a
/// different address on each: for a WebSocket client, its upgrade request.
final class ForwardedHeaderInjector {
  ForwardedHeaderInjector._(this._server);

  final ServerSocket _server;
  final List<Socket> _sockets = [];

  /// The `X-Forwarded-For` value sent on each connection, in order.
  final List<String> sent = [];

  /// The origin that forwards to the stack's Caddy.
  String get origin => 'http://127.0.0.1:${_server.port}';

  /// Starts the forwarder; it stops at the end of the test.
  static Future<ForwardedHeaderInjector> start() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final injector = ForwardedHeaderInjector._(server);
    server.listen(injector._forward);
    addTearDown(injector._close);
    return injector;
  }

  Future<void> _forward(Socket client) async {
    final target = await Socket.connect(InternetAddress.loopbackIPv4, 80);
    _sockets.addAll([client, target]);
    final value = '198.51.100.${sent.length + 1}';
    sent.add(value);
    final pending = <int>[];
    var injected = false;
    client.listen(
      (data) {
        if (injected) {
          target.add(data);
          return;
        }
        pending.addAll(data);
        for (var i = 0; i + 1 < pending.length; i++) {
          if (pending[i] == 13 && pending[i + 1] == 10) {
            target
              ..add(pending.sublist(0, i + 2))
              ..add(ascii.encode('X-Forwarded-For: $value\r\n'))
              ..add(pending.sublist(i + 2));
            injected = true;
            return;
          }
        }
      },
      onDone: target.destroy,
      onError: (Object _) => target.destroy(),
    );
    target.listen(
      client.add,
      onDone: client.destroy,
      onError: (Object _) => client.destroy(),
    );
  }

  Future<void> _close() async {
    await _server.close();
    for (final socket in _sockets) {
      socket.destroy();
    }
  }
}
