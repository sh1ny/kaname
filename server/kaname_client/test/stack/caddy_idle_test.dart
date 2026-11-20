/// The deploy proxy closes a download whose client has stopped reading
/// (design D4, C19; `write_idle` in `deploy/Caddyfile`).
///
/// Runs the pinned Caddy image of `deploy/compose.yaml` with the repository's
/// Caddyfile in front of a stub upstream that streams a large body, opens a
/// download through it and never reads. The proxy must give up the stalled
/// write and close its upstream connection, while the client still reads
/// nothing. Needs Docker; does not need the stack.
@Tags(['stack'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'support/stack_support.dart';

/// The Caddy image of `deploy/compose.yaml`, pinned by digest.
String _caddyImage(String root) {
  final compose = File('$root/deploy/compose.yaml').readAsStringSync();
  final match = RegExp(r'image:\s*(caddy:\S+)').firstMatch(compose);
  if (match == null) fail('deploy/compose.yaml names no caddy image');
  return match.group(1)!;
}

void main() {
  test(
    'Caddy closes a stalled download and its upstream connection while the '
    'client still reads nothing',
    timeout: const Timeout(Duration(minutes: 5)),
    () async {
      final root = repositoryRoot();

      // The upstream: a raw socket that streams 1 MiB chunks of a 1 GiB
      // body until the proxy drops the connection. A raw socket sees the
      // reset as a failed write or the end of its input; an HttpServer's
      // response can stay blocked in a flush that never fails.
      final upstreamClosed = Completer<DateTime>();
      void closed() {
        if (!upstreamClosed.isCompleted) {
          upstreamClosed.complete(DateTime.now());
        }
      }

      var requests = 0;
      final upstream = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      addTearDown(upstream.close);
      final chunk = Uint8List(1 << 20);
      upstream.listen((socket) {
        addTearDown(socket.destroy);
        var answered = false;
        socket.listen(
          (_) async {
            if (answered) return;
            answered = true;
            requests++;
            try {
              socket.write(
                'HTTP/1.1 200 OK\r\n'
                'Content-Type: application/gzip\r\n'
                'Content-Length: ${1 << 30}\r\n\r\n',
              );
              for (var sent = 0; sent < 1 << 30; sent += chunk.length) {
                if (upstreamClosed.isCompleted) return;
                socket.add(chunk);
                await socket.flush();
              }
            } on Object {
              closed();
            }
          },
          onDone: closed,
          onError: (Object _) => closed(),
        );
      });

      // The repository's Caddyfile; only the upstream's port differs.
      final scratch = await Directory.systemTemp.createTemp('kaname_caddy_');
      addTearDown(() => scratch.delete(recursive: true));
      final caddyfile = File('$root/deploy/Caddyfile')
          .readAsStringSync()
          .replaceAll('server:8080', 'server:${upstream.port}');
      expect(caddyfile, contains('server:${upstream.port}'));
      File('${scratch.path}/Caddyfile').writeAsStringSync(caddyfile);

      final name = 'kaname-caddy-idle-$pid';
      final started = await run('docker', [
        'run',
        '--rm',
        '--detach',
        '--name',
        name,
        '--add-host',
        'server:host-gateway',
        '--publish',
        '127.0.0.1::80',
        '--volume',
        '${scratch.path}/Caddyfile:/etc/caddy/Caddyfile:ro',
        _caddyImage(root),
      ]);
      expect(started.exitCode, 0, reason: started.output);
      addTearDown(() => run('docker', ['rm', '--force', name]));
      final mapped = await run('docker', ['port', name, '80/tcp']);
      expect(mapped.exitCode, 0, reason: mapped.output);
      final port = int.parse(
        mapped.output.trim().split('\n').first.split(':').last,
      );

      // A client that sends the request and then reads nothing: its
      // subscription is paused, so the kernel buffers fill and the proxy's
      // writes stall.
      Socket? client;
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (client == null) {
        try {
          client = await Socket.connect(InternetAddress.loopbackIPv4, port);
        } on SocketException {
          if (DateTime.now().isAfter(deadline)) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
      addTearDown(client.destroy);
      var clientClosed = false;
      client
          .listen((_) {}, onDone: () => clientClosed = true, onError: (_) {})
          .pause();
      client.write(
        'GET /api/static-data/bundle/1/stalled HTTP/1.1\r\n'
        'Host: localhost\r\n\r\n',
      );
      await client.flush();
      final stalledFrom = DateTime.now();

      final closedAt = await upstreamClosed.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => fail('the proxy kept the upstream connection'),
      );

      expect(requests, 1, reason: 'the request reached the upstream');
      // The close comes from the idle limit, not at once.
      expect(
        closedAt.difference(stalledFrom),
        greaterThan(const Duration(seconds: 30)),
      );
      // The client never read: the connection was given up on its behalf.
      expect(clientClosed, isFalse, reason: 'the client never resumed');
    },
  );
}
