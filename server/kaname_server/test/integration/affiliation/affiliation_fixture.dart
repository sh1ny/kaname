import 'dart:convert';
import 'dart:io';

import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:kaname_server/src/affiliation/affiliation_runtime.dart';
import 'package:kaname_server/src/esi/server_esi_runtime.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/kaname_serverpod.dart';
import 'package:serverpod/protocol.dart' show FutureCallEntry;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../../support/manual_sweep_clock.dart';
import '../support/scratch_database.dart';

/// An actual framework queue and scheduler with an event-controlled ESI origin.
final class AffiliationFixture {
  AffiliationFixture._(this.pod, this.origin);

  final KanameServerpod pod;
  final HttpServer origin;
  final clock = ManualSweepClock();
  final log = <String>[];
  final wire = <({String path, List<int> ids, String? token})>[];
  late final ServerEsiRuntime esi;
  AffiliationRuntime? runtime;
  DateTime now = DateTime.utc(2026, 11, 27);
  int closes = 0;
  bool stopped = false;

  Future<void> Function(HttpRequest, List<int>) respond = (request, ids) async {
    request.response.write(
      jsonEncode([
        for (final id in ids) {'character_id': id, 'corporation_id': 42},
      ]),
    );
    await request.response.close();
  };

  static Future<AffiliationFixture> open({bool active = true}) async {
    final db = await ScratchDatabase.create();
    addTearDown(db.drop);
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => origin.close(force: true));
    final pod = KanameServerpod(
      ['--mode', 'test', '--apply-migrations'],
      environment: const {},
      configOverride: (config) => config.copyWith(
        database: (config.database! as PostgresDatabaseConfig).withName(
          db.name,
        ),
        futureCall: const FutureCallConfig(
          concurrencyLimit: 4,
          scanInterval: Duration(milliseconds: 25),
        ),
        futureCallExecutionEnabled: false,
      ),
    );
    final fixture = AffiliationFixture._(pod, origin);
    origin.listen(fixture._handle);
    fixture.esi = ServerEsiRuntime.open(
      redis: pod.config.redis!,
      installKey: const [1],
      userAgent: 'Kaname test (contact@example.invalid)',
      onStateFailure: () => fail('scheduler state reconciliation failed'),
      testOrigin: Uri.parse('http://127.0.0.1:${origin.port}'),
      now: () => fixture.now,
      namespace: db.name,
    );
    pod.experimental.shutdownTasks.addTask('esi-runtime', () async {
      fixture.closes++;
      await fixture.esi.close();
    });
    if (active) {
      fixture.runtime = AffiliationRuntime.bind(
        pod,
        client: fixture.client,
        report: fixture.log.add,
        boot: 'current',
        elapsed: () => fixture.clock.elapsed,
        arm: fixture.clock.arm,
        now: () => fixture.now,
      );
    }
    await pod.start(runInGuardedZone: false);
    addTearDown(fixture.shutdown);
    return fixture;
  }

  EsiClient get client => esi.client(EsiPriority.sync, poll: true);

  Future<void> _handle(HttpRequest request) async {
    final ids = request.method == 'POST'
        ? (jsonDecode(await utf8.decoder.bind(request).join()) as List<Object?>)
              .cast<int>()
        : <int>[];
    wire.add((
      path: request.uri.path,
      ids: ids,
      token: request.headers.value(HttpHeaders.authorizationHeader),
    ));
    await respond(request, ids);
  }

  Future<SsoIdentityRow> addIdentity(
    Session s,
    int id, {
    bool blocked = false,
  }) => SsoIdentityRow.db.insertRow(
    s,
    SsoIdentityRow(
      characterId: id,
      characterName: 'Character $id',
      owner: 'verified-owner',
      blocked: blocked,
    ),
  );

  Future<List<FutureCallEntry>> queue(Session s) => FutureCallEntry.db.find(s);

  Future<void> json(HttpRequest request, int status, Object body) async {
    request.response.statusCode = status;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  Future<void> shutdown() async {
    if (stopped) return;
    stopped = true;
    await pod.shutdown(exitProcess: false);
  }
}
