import 'dart:async';
import 'dart:convert';

import 'package:kaname_esi_vault/kaname_esi_vault.dart';
import 'package:kaname_server/src/esi/server_esi_vault.dart';
import 'package:kaname_server/src/esi/server_sso_grants.dart';
import 'package:kaname_server/src/esi/sso_handoff.dart';
import 'package:kaname_server/src/esi/sso_sessions.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../support/in_process_pod.dart';

const _one = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _two = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _character = 415;
const _owner = 'VEVTVCBPTkxZ';

void main() {
  late InProcessPod pod;
  late Session session;
  late SsoIdentityRow pilot;
  late EsiTokenVault vault;
  late SsoCharacterGate gate;
  late SsoHandoff handoff;

  setUp(() async {
    pod = await InProcessPod.start();
    addTearDown(pod.stop);
    session = await pod.pod.createSession(enableLogging: false);
    addTearDown(session.close);
    pilot = await SsoIdentityRow.db.insertRow(
      session,
      SsoIdentityRow(
        characterId: _character,
        characterName: 'Pilot',
        owner: _owner,
        blocked: false,
      ),
    );
    vault = createServerEsiVault(
      pod.pod,
      readKey: () => base64Encode(List.filled(32, 19)),
      refresh: (_, _) async => fail('handoff must not send refresh'),
    );
    gate = SsoCharacterGate();
    handoff = SsoHandoff(gate: gate, vault: vault);
  });

  Future<VaultAuthorization> holdOnServer() async {
    final value = await vault.activate(
      character: _character,
      holder: ServerSsoGrants.holder,
      expectedGeneration: 0,
      refreshToken: 'synthetic-refresh',
    );
    final auth = (value as VaultSuccess<VaultAuthorization>).value;
    await SsoHolderRow.db.insertRow(
      session,
      SsoHolderRow(
        characterId: _character,
        phase: 'serverHeld',
        generation: 1,
        vaultGeneration: auth.generation,
      ),
    );
    return auth;
  }

  Future<SsoHolderRow?> assigned() =>
      ServerSsoGrants.assignment(session, _character);

  test('Take a server-held character solo', () async {
    final original = await holdOnServer();
    final answer = await handoff.take(session, pilot, _one);
    expect(answer, isA<SsoDeviceReservation>());
    expect((await assigned())?.phase, 'deviceReserved');
    expect(
      (await vault.readBearer(original) as VaultFailure).reason,
      VaultFailureReason.notHolder,
    );
    expect(
      (answer as SsoDeviceReservation).ownerFingerprint,
      ssoDigest('$_character:$_owner'),
    );
  });

  test('Return a device-held character to the server', () async {
    await holdOnServer();
    final reservation =
        await handoff.take(session, pilot, _one) as SsoDeviceReservation;
    expect(
      await handoff.release(session, pilot, _one, reservation.generation),
      SsoHandoffStatus.released,
    );
    expect((await assigned())?.phase, 'serverReserved');
    expect(
      await handoff.release(session, pilot, _one, reservation.generation),
      SsoHandoffStatus.released,
    );
    expect(await handoff.take(session, pilot, _two), SsoHandoffStatus.blocked);
  });

  test(
    'A device can retry a lost release reply after server activation',
    () async {
      await holdOnServer();
      final reservation =
          await handoff.take(session, pilot, _one) as SsoDeviceReservation;
      await handoff.release(session, pilot, _one, reservation.generation);
      final parked = await vault.inspect(_character);
      if (parked
          is! VaultSuccess<
            ({VaultAuthorization authorization, VaultStatus status})?
          >) {
        fail('the previous generation could not be read');
      }
      final renewed = await vault.activate(
        character: _character,
        holder: ServerSsoGrants.holder,
        expectedGeneration: parked.value!.authorization.generation,
        refreshToken: 'fresh-synthetic-grant',
      );
      final authorization = (renewed as VaultSuccess<VaultAuthorization>).value;
      final row = (await assigned())!;
      await SsoHolderRow.db.updateRow(
        session,
        row.copyWith(
          phase: 'serverHeld',
          vaultGeneration: authorization.generation,
        ),
      );

      expect(
        await handoff.release(session, pilot, _one, reservation.generation),
        SsoHandoffStatus.released,
      );
      expect(
        await handoff.release(session, pilot, _two, reservation.generation),
        SsoHandoffStatus.blocked,
      );
      expect(
        await handoff.release(session, pilot, _one, reservation.generation - 1),
        SsoHandoffStatus.blocked,
      );
      expect((await assigned())?.phase, 'serverHeld');
    },
  );

  test('Mismatch, replay or competing destination', () async {
    await holdOnServer();
    final reservation =
        await handoff.take(session, pilot, _one) as SsoDeviceReservation;
    expect(await handoff.take(session, pilot, _two), SsoHandoffStatus.blocked);
    expect(
      await handoff.release(session, pilot, _one, reservation.generation - 1),
      SsoHandoffStatus.blocked,
    );
    expect(
      await handoff.release(session, pilot, _two, reservation.generation),
      SsoHandoffStatus.blocked,
    );
    expect((await assigned())?.phase, 'deviceReserved');
  });

  test('Interruption at handoff', () async {
    await holdOnServer();
    final reached = Completer<void>();
    final finish = Completer<void>();
    addTearDown(() {
      if (!finish.isCompleted) finish.complete();
    });
    final admitted = gate.runDispatch(_character, () async {
      reached.complete();
      await finish.future;
      return true;
    });
    await reached.future;
    expect(await handoff.take(session, pilot, _one), SsoHandoffStatus.pending);
    expect((await assigned())?.phase, 'toDevice');
    expect(
      await gate.run(_character, () async => fail('new call must not enter')),
      isNull,
    );
    finish.complete();
    await admitted;
    final reconstructed = SsoHandoff(gate: SsoCharacterGate(), vault: vault);
    expect(
      await reconstructed.take(session, pilot, _one),
      isA<SsoDeviceReservation>(),
    );
    expect(
      await reconstructed.take(session, pilot, _two),
      SsoHandoffStatus.blocked,
    );
  });

  test('Original device cannot prove it parked', () async {
    await holdOnServer();
    final reservation =
        await handoff.take(session, pilot, _one) as SsoDeviceReservation;
    expect(
      await handoff.release(session, pilot, _two, reservation.generation),
      SsoHandoffStatus.blocked,
    );
    expect(
      await handoff.joinStandalone(
        session,
        pilot,
        _two,
        ssoDigest('$_character:$_owner'),
      ),
      SsoHandoffStatus.blocked,
    );
    expect((await assigned())?.phase, 'deviceReserved');
  });

  test('A standalone device joins the server', () async {
    final owner = ssoDigest('$_character:$_owner');
    expect(
      await handoff.joinStandalone(session, pilot, _one, ssoDigest('other')),
      SsoHandoffStatus.blocked,
    );
    expect(await assigned(), isNull);
    expect(
      await handoff.joinStandalone(session, pilot, _one, owner),
      SsoHandoffStatus.released,
    );
    expect((await assigned())?.phase, 'serverReserved');
    expect(
      await handoff.joinStandalone(session, pilot, _two, owner),
      SsoHandoffStatus.blocked,
    );
  });
}
