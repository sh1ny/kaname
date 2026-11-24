import 'dart:async';
import 'dart:convert';

import 'package:kaname_esi_vault/kaname_esi_vault.dart';
import 'package:kaname_server/src/esi/server_esi_vault.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../test_tools/serverpod_test_tools.dart';

const _server = (kind: VaultHolderKind.server, id: 'server-fixture');
const _device = (kind: VaultHolderKind.device, id: 'device-fixture');
const _initial = 'synthetic-initial-refresh-token';
const _rotated = 'synthetic-rotated-refresh-token';
const _access = 'synthetic-access-token';

void main() {
  withServerpod(
    'Postgres vault',
    (sessions, _) {
      late Session session;
      late String key;
      late DateTime now;
      setUp(() {
        session = sessions.build();
        key = base64Encode(List.filled(32, 0x43));
        now = DateTime.utc(2026, 1, 1);
        addTearDown(session.close);
      });

      EsiTokenVault make(VaultRefreshExchange refresh) => createServerEsiVault(
        session.serverpod,
        readKey: () => key,
        refresh: refresh,
        now: () => now,
      );

      test('first activations contend across Postgres sessions', () async {
        final calls = <String>[];
        Future<VaultRefreshReply> exchange(String token) async {
          calls.add(token);
          return const VaultRefreshTemporaryFailure();
        }

        final a = make(exchange);
        final b = make(exchange);
        const character = 0x180000001;
        final results = await Future.wait([
          a.activate(
            character: character,
            holder: _server,
            expectedGeneration: 0,
            refreshToken: _initial,
          ),
          b.activate(
            character: character,
            holder: _device,
            expectedGeneration: 0,
            refreshToken: _rotated,
          ),
        ]);
        final winner = results
            .whereType<VaultSuccess<VaultAuthorization>>()
            .single
            .value;
        final loser = (
          character: character,
          holder: winner.holder == _server ? _device : _server,
          generation: winner.generation,
        );
        expect(await b.bearer(loser), _failure(VaultFailureReason.notHolder));
        expect(calls, isEmpty);
        final rows = await session.db.unsafeQuery(
          'SELECT count(*) FROM esi_token_vault',
        );
        expect(rows.single.single, 1);
      }, timeout: const Timeout(Duration(minutes: 3)));

      test(
        'Postgres holds only ciphertext through install and rotation',
        () async {
          final arrived = Completer<String>();
          final release = Completer<VaultRefreshReply>();
          addTearDown(() {
            if (!release.isCompleted) {
              release.complete(const VaultRefreshTemporaryFailure());
            }
          });
          final a = make((token) {
            arrived.complete(token);
            return release.future;
          });
          final b = make((_) async => fail('competitor sent a refresh'));
          const character = 43;
          final auth = _success(
            await a.activate(
              character: character,
              holder: _server,
              expectedGeneration: 0,
              refreshToken: _initial,
            ),
          );
          final before = await _raw(session, character);
          final result = a.bearer(auth);
          expect(await arrived.future, _initial);
          expect(await b.bearer(auth), _failure(VaultFailureReason.busy));
          expect(
            await b.readBearer(auth),
            _failure(VaultFailureReason.refreshRequired),
          );
          release.complete(
            VaultRefreshSuccess(
              VaultBearer(_access, now.add(const Duration(minutes: 1))),
              replacementRefreshToken: _rotated,
            ),
          );
          expect(_success(await result).token, _access);
          final after = await _raw(session, character);
          expect(after, isNot(before));
          for (final row in [before, after]) {
            for (final secret in [_initial, _rotated, _access, key]) {
              expect(row, isNot(contains(secret)));
            }
          }
          expect(_success(await b.bearer(auth)).token, _access);
          now = now.add(const Duration(minutes: 1));
          final restarted = make((token) async {
            expect(token, _rotated);
            return const VaultRefreshInvalidGrant();
          });
          expect(
            await restarted.bearer(auth),
            _failure(VaultFailureReason.reLoginRequired),
          );
          expect(
            await b.bearer(auth),
            _failure(VaultFailureReason.reLoginRequired),
          );
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );

      test('database completion failure withholds bearer and does not expose raw diagnostics', () async {
        const character = 44;
        final a = make((_) async {
          await session.db.unsafeExecute('''
ALTER TABLE esi_token_vault ADD CONSTRAINT vault_fixture_fail_completion
CHECK ("characterId" <> 44 OR "leaseUntil" IS NOT NULL) NOT VALID
''');
          return VaultRefreshSuccess(
            VaultBearer(_access, now.add(const Duration(minutes: 1))),
            replacementRefreshToken: _rotated,
          );
        });
        final auth = _success(
          await a.activate(
            character: character,
            holder: _server,
            expectedGeneration: 0,
            refreshToken: _initial,
          ),
        );
        addTearDown(
          () => session.db.unsafeExecute(
            'ALTER TABLE esi_token_vault DROP CONSTRAINT IF EXISTS vault_fixture_fail_completion',
          ),
        );
        final result = await a.bearer(auth);
        expect(result, _failure(VaultFailureReason.unavailable));
        expect('$result', isNot(contains('vault_fixture_fail_completion')));
        expect('$result', isNot(contains(_access)));
        expect('$result', isNot(contains(_rotated)));
        expect('$result', isNot(contains(key)));
        final b = make((_) async => fail('unexpected exchange'));
        expect(
          await b.readBearer(auth),
          _failure(VaultFailureReason.refreshRequired),
        );
      }, timeout: const Timeout(Duration(minutes: 3)));
    },
    rollbackDatabase: RollbackDatabase.disabled,
    configOverride: (config) => config.copyWith(
      redis: RedisConfig(enabled: false, host: 'localhost', port: 8091),
    ),
  );
}

Future<String> _raw(Session session, int character) async {
  final rows = await session.db.unsafeQuery(
    'SELECT to_jsonb(v)::text FROM esi_token_vault AS v WHERE "characterId" = @id',
    parameters: QueryParameters.named({'id': character}),
  );
  return rows.single.single! as String;
}

T _success<T>(VaultResult<T> result) => switch (result) {
  VaultSuccess(:final value) => value,
  VaultFailure(:final reason) => fail('Expected success, got $reason'),
};

Matcher _failure(VaultFailureReason reason) => isA<VaultFailure<Object?>>()
    .having((value) => value.reason, 'reason', reason);
