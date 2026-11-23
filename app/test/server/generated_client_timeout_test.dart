import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_client/kaname_client.dart';

void main() {
  test(
    'A9: the generated client times out without closing the socket',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final accepted = Completer<Socket>();
      final socketEnded = Completer<void>();
      final requests = server.listen((request) async {
        await request.drain<void>();
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket.listen(
          (_) {},
          onDone: socketEnded.complete,
          onError: (Object _) => socketEnded.complete(),
          cancelOnError: true,
        );
        accepted.complete(socket);
      });
      addTearDown(requests.cancel);
      final client = Client('http://127.0.0.1:${server.port}/');
      addTearDown(client.close);

      final clock = Stopwatch()..start();
      final call = expectLater(
        client.health.check(),
        throwsA(
          isA<ServerpodClientNetworkException>().having(
            (error) => error.message,
            'message',
            contains('Request timed out.'),
          ),
        ),
      );
      final socket = await accepted.future.timeout(const Duration(seconds: 5));
      addTearDown(socket.destroy);
      await call;
      expect(clock.elapsed, greaterThanOrEqualTo(const Duration(seconds: 20)));
      expect(clock.elapsed, lessThan(const Duration(seconds: 25)));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(socketEnded.isCompleted, isFalse);
    },
  );
}
