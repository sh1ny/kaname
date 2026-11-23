@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaname_app/static_data/data/admin_client.dart';
import 'package:kaname_app/static_data/data/rpc_call.dart';
import 'package:kaname_client/kaname_client.dart';

void main() {
  test('admin calls end at 45 s with no answer yet', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final accepted = Completer<Socket>();
    final ended = Completer<void>();
    final requests = server.listen((request) async {
      await request.drain<void>();
      final socket = await request.response.detachSocket(writeHeaders: false);
      socket.listen(
        (_) {},
        onDone: ended.complete,
        onError: (Object _) => ended.complete(),
        cancelOnError: true,
      );
      accepted.complete(socket);
    });
    addTearDown(requests.cancel);
    final client = ClientStaticDataAdmin(
      Uri.parse('http://127.0.0.1:${server.port}/'),
    );
    addTearDown(client.close);

    final clock = Stopwatch()..start();
    final call = client.checkKey('test-key');
    final socket = await accepted.future.timeout(const Duration(seconds: 5));
    addTearDown(socket.destroy);
    expect(await call.answer, isA<RpcUnanswered<AdminAnswer>>());
    expect(await call.settled, isA<RpcUnanswered<AdminAnswer>>());
    expect(clock.elapsed, greaterThanOrEqualTo(const Duration(seconds: 45)));
    expect(clock.elapsed, lessThan(const Duration(seconds: 52)));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(ended.isCompleted, isFalse);
  }, timeout: const Timeout(Duration(seconds: 65)));

  test('short action deadlines retain the generated call settlement', () async {
    final responses = <Completer<http.Response>>[];
    final requests = <http.Request>[];
    final transport = MockClient((request) {
      requests.add(request);
      final response = Completer<http.Response>();
      responses.add(response);
      return response.future;
    });
    final client = ClientStaticDataAdmin(
      Uri.parse('https://example.com/'),
      httpClientOverride: transport,
    );
    addTearDown(client.close);

    // Accelerate only the answer deadlines, not the generated transport timer.
    final durations = <Duration>[];
    await runZoned(
      () async {
        final update = client.updateNow('key', 'update-id');
        final rollback = client.rollBack('key', 'rollback-id', 42);
        expect(await update.answer, isA<RpcUnanswered<AdminAnswer>>());
        expect(await rollback.answer, isA<RpcUnanswered<AdminAnswer>>());
        expect(durations, contains(const Duration(seconds: 15)));
        expect(durations, contains(const Duration(seconds: 40)));
        expect(durations, contains(const Duration(seconds: 45)));
        expect(requests, hasLength(2));
        var updateSettled = false;
        var rollbackSettled = false;
        unawaited(update.settled.then((_) => updateSettled = true));
        unawaited(rollback.settled.then((_) => rollbackSettled = true));
        await Future<void>.delayed(Duration.zero);
        expect(updateSettled, isFalse);
        expect(rollbackSettled, isFalse);
        for (final response in responses) {
          response.complete(http.Response('{"outcome":"started"}', 200));
        }
        final updateResult = await update.settled as RpcAnswered<AdminAnswer>;
        final rollbackResult =
            await rollback.settled as RpcAnswered<AdminAnswer>;
        expect(updateResult.value.outcome, AdminAnswerOutcome.started);
        expect(rollbackResult.value.outcome, AdminAnswerOutcome.started);
        final updateBody = jsonDecode(requests[0].body) as Map<String, dynamic>;
        final rollbackBody =
            jsonDecode(requests[1].body) as Map<String, dynamic>;
        expect(updateBody['operationId'], 'update-id');
        expect(rollbackBody['operationId'], 'rollback-id');
        expect(rollbackBody['expectedRevision'], 42);
      },
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          durations.add(duration);
          final scaled =
              duration == const Duration(seconds: 15) ||
                  duration == const Duration(seconds: 40)
              ? const Duration(milliseconds: 10)
              : duration;
          return parent.createTimer(zone, scaled, callback);
        },
      ),
    );
  });

  test(
    'serializes write ids and revisions and preserves public replies',
    () async {
      final requests = <http.Request>[];
      final transport = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/operation')) {
          return http.Response('{"state":"operationReadBusy"}', 200);
        }
        return http.Response('{"outcome":"settingConfirmed"}', 200);
      });
      final client = ClientStaticDataAdmin(
        Uri.parse('https://example.com/'),
        httpClientOverride: transport,
      );
      addTearDown(client.close);

      final write =
          await client
                  .setAutoUpdate('key', true, WriteRevision(id: 17), 'write-id')
                  .answer
              as RpcAnswered<AdminAnswer>;
      expect(write.value.outcome, AdminAnswerOutcome.settingConfirmed);
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['writeId'], 'write-id');
      expect(body['value'], isTrue);
      expect(body['expectedRevision'], containsPair('id', 17));
      final operation =
          await client.operation('operation-id').answer
              as RpcAnswered<AdminOperationAnswer>;
      expect(operation.value.state, AdminOperationReadState.operationReadBusy);
      final operationBody =
          jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(operationBody['operationId'], 'operation-id');
      expect(operationBody.containsKey('adminKey'), isFalse);
    },
  );

  test('insecure origins never send a key but allow public reads', () async {
    final requests = <http.Request>[];
    final transport = MockClient((request) async {
      requests.add(request);
      return http.Response('{"state":"waiting"}', 200);
    });
    final client = ClientStaticDataAdmin(
      Uri.parse('http://example.com/'),
      httpClientOverride: transport,
    );
    addTearDown(client.close);
    expect(
      await client.checkKey('key').answer,
      isA<RpcUnanswered<AdminAnswer>>(),
    );
    expect(
      await client.updateNow('key', 'id').answer,
      isA<RpcUnanswered<AdminAnswer>>(),
    );
    expect(
      await client.rollBack('key', 'id', 1).answer,
      isA<RpcUnanswered<AdminAnswer>>(),
    );
    expect(
      await client.setAutoUpdate('key', true, NoWrites(), 'id').answer,
      isA<RpcUnanswered<AdminAnswer>>(),
    );
    expect(requests, isEmpty);
    final answer =
        await client.operation('id').answer
            as RpcAnswered<AdminOperationAnswer>;
    expect(answer.value.state, AdminOperationReadState.waiting);
    expect(requests, hasLength(1));
  });

  test('request ids are distinct UUID v4 values', () {
    final ids = List.generate(100, (_) => newStaticDataRequestId());
    final uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids.every(uuid.hasMatch), isTrue);
  });
}
