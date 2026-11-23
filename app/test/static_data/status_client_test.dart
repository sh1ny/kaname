import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaname_app/static_data/data/rpc_call.dart';
import 'package:kaname_app/static_data/data/status_client.dart';
import 'package:kaname_client/kaname_client.dart';

final _base = Uri.parse('http://127.0.0.1:8080/kaname/');

StaticDataStatus _snapshot({required bool busy}) => StaticDataStatus(
  activeBuild: busy ? 77 : null,
  buildRevision: busy ? 2 : 0,
  settingRevision: busy ? WriteRevision(id: 3) : NoWrites(),
  autoUpdate: !busy,
  adminConfigured: busy,
  busy: busy,
  workerStuck: false,
  settlementStuck: false,
  recoveryStuck: false,
  startupStuck: false,
);

http.Response _response(StaticDataStatus status) => http.Response(
  jsonEncode(status.toJson()),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('status client maps each answer to a typed status and a failure to '
      'unavailable', () async {
    final replies = [
      _response(_snapshot(busy: false)),
      _response(_snapshot(busy: true)),
      http.Response('private-server.invalid:1234', 500),
    ].iterator;
    final urls = <Uri>[];
    final client = ClientStaticDataStatus(
      _base,
      httpClientOverride: MockClient((request) async {
        urls.add(request.url);
        replies.moveNext();
        return replies.current;
      }),
    );
    addTearDown(client.close);

    final fresh = await client.read().answer as RpcAnswered<StaticDataStatus>;
    expect(fresh.value.activeBuild, isNull);
    expect(fresh.value.settingRevision, isA<NoWrites>());
    final busy = await client.read().answer as RpcAnswered<StaticDataStatus>;
    expect(busy.value.activeBuild, 77);
    expect(busy.value.busy, isTrue);
    expect((busy.value.settingRevision as WriteRevision).id, 3);
    expect(await client.read().answer, isA<RpcUnanswered<StaticDataStatus>>());
    expect(
      urls.map((url) => url.path),
      everyElement('/kaname/staticData/status'),
    );
  });

  test(
    'timing out a status answer leaves the generated call outstanding',
    () async {
      final deferred = Completer<http.Response>();
      final client = ClientStaticDataStatus(
        _base,
        httpClientOverride: MockClient((_) => deferred.future),
        answerTimeout: const Duration(milliseconds: 10),
      );
      addTearDown(client.close);
      final read = client.read();
      var transportEnded = false;
      unawaited(read.settled.then<void>((_) => transportEnded = true));
      expect(await read.answer, isA<RpcUnanswered<StaticDataStatus>>());
      expect(transportEnded, isFalse);
      deferred.complete(_response(_snapshot(busy: true)));
      final settled = await read.settled as RpcAnswered<StaticDataStatus>;
      expect(settled.value.activeBuild, 77);
    },
  );
}
