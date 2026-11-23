@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/server/data/server_address.dart';
import 'package:kaname_app/static_data/data/report_client.dart';
import 'package:kaname_client/kaname_client.dart';

void main() {
  test('a request with no headers or a stalled body is aborted at 30 s '
      'and a new request succeeds', () async {
    for (final holdBody in [false, true]) {
      final server = await _HoldingServer.start(holdBody: holdBody);
      addTearDown(server.close);
      final client = HttpStaticDataReportClient(
        server: ConfiguredServer(server.base),
        timeout: const Duration(milliseconds: 500),
      );

      final first = client.read();
      await server.held.future.timeout(const Duration(seconds: 5));
      expect(
        await first.timeout(const Duration(seconds: 5)),
        isA<ReportUnavailable>(),
      );
      await server.closedByClient.future.timeout(const Duration(seconds: 5));
      final second = await client.read().timeout(const Duration(seconds: 5));
      expect(second, isA<ReportReceived>());
      expect(
        (second as ReportReceived).report.outcome,
        StaticDataReportOutcome.noPreviousBuild,
      );
    }
  });

  test(
    'resolves the configured base path and decodes a typed report',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final path = Completer<String>();
      server.listen((request) {
        path.complete('${request.method} ${request.uri.path}');
        final changes = StaticDataReportChanges(
          count: 1,
          keys: ['42'],
          cutOff: false,
        );
        final report = StaticDataChangeReport(
          outcome: StaticDataReportOutcome.reportReady,
          activeBuild: 2,
          fromBuild: 1,
          toBuild: 2,
          files: [
            StaticDataReportFile(
              file: 'types',
              status: StaticDataReportFileStatus.both,
              added: changes,
              removed: changes,
              changed: changes,
              changedFields: {'volume': 1},
              changedFieldCount: 1,
              changedFieldsCutOff: false,
            ),
          ],
        );
        request.response.write(jsonEncode(report.toJson()));
        unawaited(request.response.close());
      });
      final client = HttpStaticDataReportClient(
        server: ConfiguredServer(
          Uri.parse('http://127.0.0.1:${server.port}/api/'),
        ),
      );

      final answer = await client.read();
      expect(await path.future, 'GET /api/static-data/report');
      expect(answer, isA<ReportReceived>());
      final report = (answer as ReportReceived).report;
      expect(report.outcome, StaticDataReportOutcome.reportReady);
      expect(report.fromBuild, 1);
      expect(report.files!.single.added.keys, ['42']);
      expect(report.files!.single.changedFields, {'volume': 1});
    },
  );
  test('a broken connection is unavailable', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((socket) => socket.destroy());
    final client = HttpStaticDataReportClient(
      server: ConfiguredServer(Uri.parse('http://127.0.0.1:${server.port}/')),
    );
    expect(await client.read(), isA<ReportUnavailable>());
  });

  test('non-200 and malformed typed JSON are unavailable', () async {
    for (final (status, body) in [
      (503, '{"outcome":"reportBusy"}'),
      (200, 'not json'),
      (200, '[]'),
      (200, '{"outcome":"unknown"}'),
      (200, '{"outcome":"reportReady"}'),
      (
        200,
        '{"outcome":"reportReady","activeBuild":2,"fromBuild":1,'
            '"toBuild":2,"files":[{}]}',
      ),
    ]) {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        request.response.statusCode = status;
        request.response.write(body);
        unawaited(request.response.close());
      });
      final client = HttpStaticDataReportClient(
        server: ConfiguredServer(Uri.parse('http://127.0.0.1:${server.port}/')),
      );
      expect(await client.read(), isA<ReportUnavailable>(), reason: body);
    }
  });
}

final class _HoldingServer {
  _HoldingServer._(this._socket, this._holdBody);

  static Future<_HoldingServer> start({required bool holdBody}) async {
    final server = _HoldingServer._(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
      holdBody,
    );
    server._serve();
    return server;
  }

  final ServerSocket _socket;
  final bool _holdBody;
  final _connections = <Socket>[];
  final held = Completer<void>();
  final closedByClient = Completer<void>();
  int _requests = 0;

  Uri get base => Uri.parse('http://127.0.0.1:${_socket.port}/base/');

  void _serve() {
    _socket.listen((socket) {
      _connections.add(socket);
      final first = _requests++ == 0;
      var request = '';
      var answered = false;
      socket.listen(
        (bytes) {
          request += latin1.decode(bytes);
          if (answered || !request.contains('\r\n\r\n')) return;
          answered = true;
          if (first) {
            if (_holdBody) {
              socket.write(
                'HTTP/1.1 200 OK\r\nContent-Length: 1000\r\n'
                'Content-Type: application/json\r\n\r\n{',
              );
              unawaited(socket.flush().then((_) => held.complete()));
            } else {
              held.complete();
            }
          } else {
            const body = '{"outcome":"noPreviousBuild"}';
            socket.write(
              'HTTP/1.1 200 OK\r\nContent-Length: ${body.length}\r\n'
              'Connection: close\r\n\r\n$body',
            );
            unawaited(socket.flush().then((_) => socket.close()));
          }
        },
        onDone: () {
          if (first && !closedByClient.isCompleted) closedByClient.complete();
          socket.destroy();
        },
        onError: (Object _) {
          if (first && !closedByClient.isCompleted) closedByClient.complete();
          socket.destroy();
        },
      );
    });
  }

  Future<void> close() async {
    for (final socket in _connections) {
      socket.destroy();
    }
    await _socket.close();
  }
}
