import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/health/health_endpoint.dart';
import 'package:kaname_server/src/static_data/admin_gate.dart';
import 'package:kaname_server/src/static_data/static_data_access.dart';
import 'package:kaname_server/src/static_data/static_data_start.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../support/in_process_pod.dart';

void main() {
  test('A2/A4: failed HTTP calls do not echo call parameters', () async {
    const failingSentinel = 'kaname-test-rpc-failing-sentinel';
    const malformedSentinel = 'kaname-test-rpc-malformed-sentinel';
    const marker = 'intentional failure from the health probe';
    final console = <String>[];
    final capture = _ConsoleCapture(console);
    late InProcessPod server;
    var calls = 0;
    await IOOverrides.runZoned(
      () => runZoned(
        () async {
          server = await InProcessPod.start(
            // Keep the existing health route; only its test dispatch takes an
            // argument and throws, rather than checking the dependencies.
            extraEndpoints: {'health': HealthEndpoint()},
            extraMethods: {
              'health': {
                'check': MethodConnector(
                  name: 'check',
                  params: {
                    'probe': ParameterDescription(
                      name: 'probe',
                      type: String,
                      nullable: false,
                    ),
                  },
                  call: (session, arguments) async {
                    if (arguments['probe'] == failingSentinel) calls++;
                    throw StateError(marker);
                  },
                ),
              },
            },
            configOverride: (config) => config.copyWith(
              sessionLogs: config.sessionLogs.copyWith(
                persistentEnabled: true,
                consoleEnabled: true,
              ),
            ),
          );
          addTearDown(server.stop);
          final endpoint = Uri.parse('${server.baseUrl}health/check');
          Future<http.Response> send(Object value) => http.post(
            endpoint,
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'probe': value}),
          );

          final failing = await send(failingSentinel);
          expect(failing.statusCode, HttpStatus.internalServerError);
          final malformed = await send({'value': malformedSentinel});
          expect(malformed.statusCode, HttpStatus.badRequest);
          expect(calls, 1);

          final logs = await server.pod.withSession((session) async {
            final rows = await session.db.unsafeQuery('''
SELECT row_to_json(s)::text FROM serverpod_session_log AS s
WHERE s.endpoint = 'health' AND s.method = 'check'
''');
            return rows.map((row) => row.single as String).join('\n');
          });
          expect(logs, contains(marker));
          final printed = console.join('\n');
          expect(printed, contains(marker));
          for (final surface in [failing.body, malformed.body, printed, logs]) {
            expect(surface, isNot(contains(failingSentinel)));
            expect(surface, isNot(contains(malformedSentinel)));
          }
        },
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) => console.add(line),
        ),
      ),
      stdout: () => capture,
      stderr: () => capture,
    );
  });

  test(
    'real admin HTTP answers, logs and setting records contain no key',
    () async {
      const accepted = 'sentinel-accepted-admin-key-0123456789123456789';
      const rejected = 'sentinel-rejected-admin-key-9876543219876543210';
      const malformed = 'sentinel-malformed-key-argument-12345678901234';
      final console = <String>[];
      final capture = _ConsoleCapture(console);
      await IOOverrides.runZoned(
        () => runZoned(
          () async {
            final server = await InProcessPod.start(
              configOverride: (config) => config.copyWith(
                sessionLogs: config.sessionLogs.copyWith(
                  persistentEnabled: true,
                  consoleEnabled: true,
                ),
              ),
            );
            addTearDown(server.stop);
            final settings = server.pod.runtimeSettings;
            await server.pod.updateRuntimeSettings(
              settings.copyWith(
                logSettings: settings.logSettings.copyWith(
                  logAllSessions: true,
                  logAllQueries: true,
                ),
              ),
            );
            StaticDataAccess.installForTest(
              server.pod,
              StaticDataAccess(
                gate: AdminGate(
                  key: accepted,
                  log: (level, message) =>
                      logStaticData(server.pod, level, message),
                ),
                withSession: server.pod.withSession,
              ),
            );
            Future<http.Response> post(
              String method,
              Map<String, Object?> body,
            ) => http.post(
              Uri.parse('${server.baseUrl}staticDataAdmin/$method'),
              headers: {'content-type': 'application/json'},
              body: jsonEncode(body),
            );

            final saved = await post('setAutoUpdate', {
              'adminKey': accepted,
              'value': false,
              'expectedRevision': NoWrites().toJson(),
              'writeId': '302b1b0d-fcb7-4ae8-8bd4-add5e94e5332',
            });
            expect(saved.statusCode, HttpStatus.ok);
            expect(saved.body, contains('settingConfirmed'));
            final refused = await post('checkKey', {'adminKey': rejected});
            expect(refused.statusCode, HttpStatus.ok);
            expect(refused.body, contains('keyRejected'));
            final invalid = await post('checkKey', {
              'adminKey': {'key': malformed},
            });
            expect(invalid.statusCode, HttpStatus.badRequest);

            final persisted = await server.pod.withSession((session) async {
              expect(
                (await SdeSettingWrite.db.find(session)).single.autoUpdate,
                isFalse,
              );
              final rows = await session.db.unsafeQuery('''
              SELECT row_to_json(s)::text FROM serverpod_session_log AS s
              UNION ALL SELECT row_to_json(l)::text FROM serverpod_log AS l
              UNION ALL SELECT row_to_json(q)::text FROM serverpod_query_log AS q
              UNION ALL SELECT row_to_json(w)::text FROM sde_setting_write AS w
              UNION ALL SELECT row_to_json(a)::text FROM sde_admin_operation AS a
            ''');
              return rows.map((row) => row.single as String).join('\n');
            });
            expect(persisted, contains('setAutoUpdate'));
            final printed = console.join('\n');
            expect(printed, contains('admin key rejected'));
            for (final surface in [
              saved.body,
              refused.body,
              invalid.body,
              printed,
              persisted,
            ]) {
              for (final key in [accepted, rejected, malformed]) {
                expect(surface, isNot(contains(key)));
              }
            }
          },
          zoneSpecification: ZoneSpecification(
            print: (_, _, _, line) => console.add(line),
          ),
        ),
        stdout: () => capture,
        stderr: () => capture,
      );
    },
  );
}

final class _ConsoleCapture implements Stdout {
  _ConsoleCapture(this.lines);

  final List<String> lines;

  @override
  bool get hasTerminal => false;

  @override
  Future<void> flush() async {}

  @override
  void write(Object? object) => lines.add('$object');

  @override
  void writeln([Object? object = '']) => write(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
