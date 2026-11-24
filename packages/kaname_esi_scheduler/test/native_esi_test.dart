import 'dart:async';
import 'dart:io';

import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:kaname_esi_scheduler/native.dart';
import 'package:test/test.dart';

void main() {
  test('native solo sends one scheduled request with pinned headers', () async {
    final received = Completer<({String? agent, String? date, String? auth})>();
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => http.close(force: true));
    http.listen((request) async {
      received.complete((
        agent: request.headers.value(HttpHeaders.userAgentHeader),
        date: request.headers.value('x-compatibility-date'),
        auth: request.headers.value(HttpHeaders.authorizationHeader),
      ));
      request.response.write('[99000001]');
      await request.response.close();
    });
    final runtime = NativeEsiRuntime.solo(
      key: const [1],
      userAgent: 'Kaname test (contact@example.invalid)',
      testOrigin: Uri.parse('http://127.0.0.1:${http.port}'),
    );
    addTearDown(runtime.close);
    final result = await runtime.scheduler
        .client(EsiPriority.interactive)
        .getAlliances();
    expect(
      result,
      isA<EsiSuccess<List<int>>>().having((r) => r.body, 'body', [99000001]),
    );
    expect(await received.future, (
      agent: 'Kaname test (contact@example.invalid)',
      date: esiCompatibilityDate,
      auth: null,
    ));
  });

  test('native sender does not follow an upstream redirect', () async {
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => http.close(force: true));
    final targets = <String>[];
    http.listen((request) async {
      targets.add(request.uri.path);
      if (request.uri.path == '/alliances') {
        request.response.headers.set('location', '/target');
        request.response.statusCode = 302;
      } else {
        request.response.write('[]');
      }
      await request.response.close();
    });
    final runtime = NativeEsiRuntime.solo(
      key: const [1],
      userAgent: 'Kaname test (contact@example.invalid)',
      testOrigin: Uri.parse('http://127.0.0.1:${http.port}'),
    );
    addTearDown(runtime.close);
    final result = await runtime.scheduler
        .client(EsiPriority.interactive)
        .getAlliances();
    expect(
      result,
      isA<EsiError<List<int>>>().having((r) => r.status, 'wire status', 302),
    );
    expect(targets, ['/alliances']);
  });

  test('native sender refuses an oversized response without replay', () async {
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => http.close(force: true));
    var requests = 0;
    http.listen((request) async {
      requests++;
      request.response.contentLength = 16 * 1024 * 1024 + 1;
      request.response.write('[');
      await request.response.flush();
    });
    final runtime = NativeEsiRuntime.solo(
      key: const [1],
      userAgent: 'Kaname test (contact@example.invalid)',
      testOrigin: Uri.parse('http://127.0.0.1:${http.port}'),
    );
    addTearDown(runtime.close);
    expect(
      await runtime.scheduler.client(EsiPriority.interactive).getAlliances(),
      isA<EsiTransportFailed<List<int>>>(),
    );
    expect(requests, 1);
  });
}
