import 'dart:convert';

import 'package:kaname_esi_vault/kaname_esi_vault.dart';
import 'package:kaname_server/src/esi/server_esi_vault.dart';
import 'package:test/test.dart';

import '../support/in_process_pod.dart';

const _holder = (kind: VaultHolderKind.server, id: 'test-server');
const _initial = 'synthetic-initial-refresh';
const _rotated = 'synthetic-rotated-refresh';
const _access = 'synthetic-access';

void main() {
  late InProcessPod pod;
  late DateTime now;
  late String key;
  setUp(() async {
    now = DateTime.utc(2026, 11, 25);
    key = base64Encode(List.filled(32, 0x53));
    pod = await InProcessPod.start();
    addTearDown(pod.stop);
  });

  test('Definitive refresh verification rejection', () async {
    var calls = 0;
    final vault = createServerEsiVault(
      pod.pod,
      now: () => now,
      readKey: () => key,
      refresh: (authorization, token) async {
        expect(authorization.character, 46);
        expect(token, _initial);
        calls++;
        return const VaultRefreshUnverifiedGrant();
      },
    ).vault;
    final activated = await vault.activate(
      character: 46,
      holder: _holder,
      expectedGeneration: 0,
      refreshToken: _initial,
    );
    final authorization = (activated as VaultSuccess<VaultAuthorization>).value;
    for (var check = 0; check < 2; check++) {
      expect(
        await vault.bearer(authorization),
        isA<VaultFailure<VaultBearer>>().having(
          (e) => e.reason,
          'reason',
          VaultFailureReason.reLoginRequired,
        ),
      );
    }
    expect(calls, 1);
    expect(
      (await vault.inspect(46) as VaultSuccess).value!.status,
      VaultStatus.dead,
    );
  });

  test('Successful login and later refresh', () async {
    final vault = createServerEsiVault(
      pod.pod,
      now: () => now,
      readKey: () => key,
      refresh: (authorization, token) async {
        expect(authorization.generation, 1);
        expect(token, _initial);
        return VaultRefreshSuccess(
          VaultBearer(_access, now.add(const Duration(minutes: 10))),
          replacementRefreshToken: _rotated,
        );
      },
    ).vault;
    final activated = await vault.activate(
      character: 46,
      holder: _holder,
      expectedGeneration: 0,
      refreshToken: _initial,
    );
    final authorization = (activated as VaultSuccess<VaultAuthorization>).value;
    expect(
      await vault.bearer(authorization),
      isA<VaultSuccess<VaultBearer>>().having(
        (r) => r.value.token,
        'access token',
        _access,
      ),
    );
    final rows = await pod.pod.withSession(
      (session) => session.db.unsafeQuery(
        'SELECT to_jsonb(v)::text FROM esi_token_vault AS v WHERE "characterId"=46',
      ),
      enableLogging: false,
    );
    final persisted = rows.single.single.toString();
    for (final sentinel in [key, _initial, _rotated, _access]) {
      expect(persisted, isNot(contains(sentinel)));
    }
  });
}
