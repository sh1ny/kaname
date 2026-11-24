import 'dart:async';

import 'package:kaname_server/src/static_data/static_data_lock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod(
    'Vault store prerequisites',
    (sessions, _) {
      test('disabled session logging does not emit or persist a SQL failure', () async {
        const marker = 'synthetic_vault_failure_marker';
        final session = sessions.build();
        addTearDown(session.close);
        final prints = <String>[];
        await runZoned(
          () async {
            await expectLater(
              session.serverpod.withSession((vaultSession) async {
                await vaultSession.db.unsafeQuery(
                  'SELECT * FROM synthetic_vault_failure_marker',
                );
              }, enableLogging: false),
              throwsA(
                isA<Object>().having(
                  (error) => error.toString(),
                  'original error',
                  contains(marker),
                ),
              ),
            );
          },
          zoneSpecification: ZoneSpecification(
            print: (_, _, _, line) => prints.add(line),
          ),
        );
        expect(prints.join('\n'), isNot(contains(marker)));
        for (final table in [
          'serverpod_log',
          'serverpod_query_log',
          'serverpod_session_log',
        ]) {
          final result = await session.db.unsafeQuery(
            'SELECT count(*) FROM $table AS logs WHERE to_jsonb(logs)::text LIKE @needle',
            parameters: QueryParameters.named({'needle': '%$marker%'}),
          );
          expect(result.single.single, 0);
        }
      }, timeout: const Timeout(Duration(minutes: 3)));

      test(
        'vault advisory namespace does not conflict with bigint locks',
        () async {
          final session = sessions.build();
          addTearDown(session.close);
          await session.db.transaction((holder) async {
            final both = await session.db.unsafeQuery('''
SELECT pg_try_advisory_xact_lock(-9223372036854775766::bigint),
       pg_try_advisory_xact_lock($staticDataAdvisoryLockKey::bigint)
''', transaction: holder);
            expect(both.single.toList(), [true, true]);
            await session.serverpod.withSession((competitor) async {
              await competitor.db.transaction((vault) async {
                final vaultLock = await competitor.db.unsafeQuery(
                  "SELECT pg_try_advisory_xact_lock('-2147483648'::int4, 42::int4)",
                  transaction: vault,
                );
                expect(vaultLock.single.single, isTrue);
              });
            }, enableLogging: false);
          });
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
    configOverride: (config) => config.copyWith(
      redis: RedisConfig(enabled: false, host: 'localhost', port: 8091),
      sessionLogs: SessionLogConfig(
        consoleEnabled: true,
        persistentEnabled: true,
        cleanupInterval: Duration(hours: 24),
        retentionPeriod: Duration(days: 1),
        retentionCount: 100,
      ),
    ),
  );
}
