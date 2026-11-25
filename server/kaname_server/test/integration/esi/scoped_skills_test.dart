import 'dart:convert';
import 'dart:typed_data';

import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:kaname_esi_vault/kaname_esi_vault.dart';
import 'package:kaname_server/src/esi/server_esi_vault.dart';
import 'package:kaname_server/src/esi/sso_skills.dart';
import 'package:test/test.dart';

import '../support/in_process_pod.dart';

void main() {
  late InProcessPod pod;
  late EsiTokenVault vault;
  late _Wire wire;
  late EsiScheduler scheduler;
  late VaultAuthorization auth;

  setUp(() async {
    final now = DateTime.utc(2026, 11, 25);
    pod = await InProcessPod.start();
    addTearDown(pod.stop);
    vault = createServerEsiVault(
      pod.pod,
      now: () => now,
      readKey: () => base64Encode(List.filled(32, 47)),
      refresh: (_, _) async => fail('unexpected refresh'),
    );
    const holder = (kind: VaultHolderKind.server, id: 'fixture');
    auth = (await vault.activate(
      character: 415,
      holder: holder,
      expectedGeneration: 0,
      refreshToken: 'fake-refresh',
      bearer: VaultBearer(
        'synthetic-access',
        now.add(const Duration(hours: 1)),
      ),
    ) as VaultSuccess<VaultAuthorization>).value;
    wire = _Wire();
    scheduler = EsiScheduler(
      state: MemorySchedulerState(),
      send: wire.send,
      key: List.filled(32, 11),
      now: () => now,
    );
  });

  test('Scoped read in both modes', () async {
    final (reply, failure) = await readScheduledSkills(
      vault: vault,
      authorization: auth,
      application: 'client',
      member: 7,
      client: (principal) =>
          scheduler.client(EsiPriority.interactive, principal: principal),
    );
    expect((reply as EsiSuccess<CharactersSkills>).body.totalSp, 1200);
    expect(failure, isNull);
    expect(wire.last?.target.path, '/characters/415/skills');
    expect(wire.bearer, 'synthetic-access');
  });

  test('No authority or no scope', () async {
    await vault.park(auth);
    final (reply, failure) = await readScheduledSkills(
      vault: vault,
      authorization: auth,
      application: 'client',
      member: 7,
      client: (principal) =>
          scheduler.client(EsiPriority.interactive, principal: principal),
    );
    expect(reply, isNull);
    expect(failure, VaultFailureReason.notHolder);
    expect(wire.last, isNull);
  });
}

final class _Wire {
  EsiRequest? last;
  String? bearer;

  Future<WireOutcome> send(
    EsiRequest request,
    String? token,
    String? validator,
  ) async {
    last = request;
    bearer = token;
    return WireResponse(
      EsiResponse(
        status: 200,
        body: Uint8List.fromList(utf8.encode('{"skills":[],"total_sp":1200}')),
      ),
    );
  }
}
