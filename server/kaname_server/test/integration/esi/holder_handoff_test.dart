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
const _other = 416;
const _owner = 'VEVTVCBPTkxZ';

void main() {
  late InProcessPod pod;
  late Session session;
  late SsoViewer pilot;
  late EsiTokenVault vault;
  late SsoCharacterGate gate;
  late SsoHandoff handoff;
  late DateTime clock;

  Future<SsoViewer> signViewer(int character) async {
    final identity = await SsoIdentityRow.db.insertRow(
      session,
      SsoIdentityRow(
        characterId: character,
        characterName: 'Pilot',
        owner: _owner,
        blocked: false,
      ),
    );
    final account = await MemberAccountRow.db.insertRow(
      session,
      MemberAccountRow(mainIdentityId: identity.id!),
    );
    final linked = await SsoIdentityRow.db.updateRow(
      session,
      identity.copyWith(accountId: account.id),
    );
    final login = await SsoSessionRow.db.insertRow(
      session,
      SsoSessionRow(
        digest: 'fixture-$character',
        identityId: linked.id!,
        accountId: account.id!,
        expiresAt: clock.add(const Duration(days: 1)),
      ),
    );
    return (
      accountId: account.id!,
      accountExcluded: null,
      admin: false,
      identity: linked,
      sessionId: login.id!,
    );
  }

  setUp(() async {
    pod = await InProcessPod.start();
    addTearDown(pod.stop);
    session = await pod.pod.createSession(enableLogging: false);
    addTearDown(session.close);
    clock = DateTime.utc(2026, 11, 25, 10);
    pilot = await signViewer(_character);
    vault = createServerEsiVault(
      pod.pod,
      readKey: () => base64Encode(List.filled(32, 19)),
      refresh: (_, _) async => fail('handoff must not send refresh'),
    );
    final sessions = SsoSessions(now: () => clock);
    gate = sessions.gate;
    handoff = SsoHandoff(sessions: sessions, vault: vault, now: () => clock);
  });

  Future<VaultAuthorization> holdOnServer({int character = _character}) async {
    final value = await vault.activate(
      character: character,
      holder: ServerSsoGrants.holder,
      expectedGeneration: 0,
      refreshToken: 'synthetic-refresh',
    );
    final auth = (value as VaultSuccess<VaultAuthorization>).value;
    await SsoHolderRow.db.insertRow(
      session,
      SsoHolderRow(
        characterId: character,
        phase: 'serverHeld',
        generation: 1,
        vaultGeneration: auth.generation,
      ),
    );
    return auth;
  }

  Future<SsoHolderRow?> assigned() =>
      ServerSsoGrants.assignment(session, _character);

  /// The holder fields a closure may or may not change.
  Future<Object> closure([int character = _character]) async {
    final row = (await ServerSsoGrants.assignment(session, character))!;
    return (
      row.phase,
      row.generation,
      row.proofDigest,
      row.takeClosures,
      row.lastTakeClosureAt,
    );
  }

  Future<SsoHandoffResult> reconcile(String proof, int epoch) =>
      handoff.takeIntent(session, pilot, proof, epoch, reconcile: true);

  test('revocation before holder admission starts no holder action', () async {
    await holdOnServer();
    await SsoSessionRow.db.deleteWhere(
      session,
      where: (t) => t.id.equals(pilot.sessionId),
    );
    expect(await handoff.take(session, pilot, _one), SsoHandoffStatus.blocked);
    expect((await assigned())?.phase, 'serverHeld');
    expect(await handoff.prepareTake(session, pilot), isNull);
  });

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

  test(
    'A newer vault generation leaves server reauthorization possible',
    () async {
      final original = await holdOnServer();
      // Vault commit succeeded, but the server stopped before updating the assignment.
      final renewed = await vault.activate(
        character: _character,
        holder: ServerSsoGrants.holder,
        expectedGeneration: original.generation,
        refreshToken: 'fresh-synthetic-grant',
      ) as VaultSuccess<VaultAuthorization>;
      expect(
        await handoff.take(session, pilot, _one),
        SsoHandoffStatus.blocked,
      );
      final stale = (await assigned())!;
      expect(
        (
          stale.phase,
          stale.generation,
          stale.vaultGeneration,
          stale.proofDigest,
        ),
        ('serverHeld', 1, original.generation, null),
      );
      // A fresh server authorization can replace the stale generation.
      await SsoHolderRow.db.updateRow(
        session,
        stale.copyWith(vaultGeneration: renewed.value.generation),
      );
      expect(
        await handoff.take(session, pilot, _one),
        isA<SsoDeviceReservation>(),
      );
    },
  );

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
    final reconstructed = SsoHandoff(
      sessions: SsoSessions(now: () => clock),
      vault: vault,
      now: () => clock,
    );
    expect(
      await reconstructed.take(session, pilot, _one),
      isA<SsoDeviceReservation>(),
    );
    expect(
      await reconstructed.take(session, pilot, _two),
      SsoHandoffStatus.blocked,
    );
  });

  test(
    'A recorded take stays pending if its source generation changed',
    () async {
      final original = await holdOnServer();
      final source = (await assigned())!;
      // Reconstruct the durable state after the take wrote its proof but before
      // parking completed. Then simulate a vault generation that no longer matches.
      await SsoHolderRow.db.updateRow(
        session,
        source.copyWith(
          phase: 'toDevice',
          generation: source.generation + 1,
          proofDigest: ssoDigest(_one),
        ),
      );
      final newer = await vault.activate(
        character: _character,
        holder: ServerSsoGrants.holder,
        expectedGeneration: original.generation,
        refreshToken: 'fresh-synthetic-grant',
      );
      expect(newer, isA<VaultSuccess<VaultAuthorization>>());

      expect(
        await handoff.take(session, pilot, _one),
        SsoHandoffStatus.pending,
      );
      final pending = (await assigned())!;
      expect(pending.phase, 'toDevice');
      expect(pending.proofDigest == ssoDigest(_one), isTrue);
    },
  );

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

  test('A joining device can retry after the server activates', () async {
    final owner = ssoDigest('$_character:$_owner');
    expect(
      await handoff.joinStandalone(session, pilot, _one, owner),
      SsoHandoffStatus.released,
    );
    final row = (await assigned())!;
    await SsoHolderRow.db.updateRow(
      session,
      row.copyWith(phase: 'serverHeld', vaultGeneration: 1),
    );
    expect(
      await handoff.joinStandalone(session, pilot, _one, owner),
      SsoHandoffStatus.released,
    );
    expect(
      await handoff.joinStandalone(session, pilot, _two, owner),
      SsoHandoffStatus.blocked,
    );
    expect((await assigned())?.phase, 'serverHeld');
  });

  test('A new closure can commit at the cooldown boundary', () async {
    await holdOnServer();
    final start = clock;
    expect(await reconcile(_one, 1), SsoHandoffStatus.notAccepted);
    final first = await closure();
    expect(first, ('serverHeld', 1, null, 1, start));

    clock = start.add(
      const Duration(seconds: 60) - const Duration(microseconds: 1),
    );
    expect(await reconcile(_two, 2), SsoHandoffStatus.pending);
    expect(await closure(), first);

    clock = start.add(const Duration(seconds: 60));
    expect(await reconcile(_two, 2), SsoHandoffStatus.notAccepted);
    expect(await closure(), ('serverHeld', 1, null, 2, clock));
  });

  test('Repeated closures stay pending after restart and do not limit another character', () async {
    await holdOnServer();
    final other = await signViewer(_other);
    await holdOnServer(character: _other);
    final start = clock;
    expect(await reconcile(_one, 1), SsoHandoffStatus.notAccepted);
    final closed = await closure();

    clock = start.add(const Duration(seconds: 30));
    final restarted = SsoHandoff(
      sessions: SsoSessions(now: () => clock),
      vault: vault,
      now: () => clock,
    );
    for (final proof in [_one, _two, _two]) {
      expect(
        await restarted.takeIntent(session, pilot, proof, 2, reconcile: true),
        SsoHandoffStatus.pending,
      );
    }
    // A start the source would refuse cannot confirm non-acceptance either.
    await SsoHolderRow.db.updateRow(
      session,
      (await assigned())!.copyWith(vaultGeneration: null),
    );
    expect(
      await restarted.takeIntent(session, pilot, _two, 2, reconcile: false),
      SsoHandoffStatus.pending,
    );
    expect(await closure(), closed);

    expect(
      await restarted.takeIntent(session, other, _one, 1, reconcile: true),
      SsoHandoffStatus.notAccepted,
    );
    expect(await closure(_other), ('serverHeld', 1, null, 1, clock));
  });

  test(
    'Waiting for the holder row does not consume the cooldown',
    timeout: const Timeout(Duration(minutes: 5)),
    () async {
      await holdOnServer();
      final start = clock;
      final locked = Completer<void>();
      final unlock = Completer<void>();
      addTearDown(() {
        if (!unlock.isCompleted) unlock.complete();
      });
      final holder = pod.pod.withSession(
        (db) => db.db.transaction((transaction) async {
          await db.db.unsafeQuery(
            'SELECT id FROM esi_holder_assignment '
            'WHERE "characterId" = @character FOR UPDATE',
            parameters: QueryParameters.named({'character': _character}),
            transaction: transaction,
          );
          locked.complete();
          await unlock.future;
        }),
        enableLogging: false,
      );
      await locked.future;

      var finished = false;
      final closing = reconcile(_one, 1)
        ..whenComplete(() => finished = true).ignore();
      // Poll the server until the closure waits on the held row lock.
      while (true) {
        final waiting = await session.db.unsafeQuery('''
SELECT count(*) FROM pg_stat_activity
WHERE datname = current_database() AND wait_event_type = 'Lock'
  AND query LIKE '%esi_holder_assignment%'
''');
        if ((waiting.single.single! as int) > 0) break;
        if (finished) fail('The closure finished without waiting for the row.');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final lockedAt = start.add(const Duration(minutes: 2));
      clock = lockedAt;
      unlock.complete();
      await holder;
      expect(await closing, SsoHandoffStatus.notAccepted);
      final first = await closure();
      expect(first, ('serverHeld', 1, null, 1, lockedAt));

      // The request began at start, but the cooldown runs from the lock.
      clock = lockedAt.add(const Duration(seconds: 59));
      expect(await reconcile(_two, 2), SsoHandoffStatus.pending);
      // An exact replay is answered from the committed row.
      expect(await reconcile(_one, 1), SsoHandoffStatus.notAccepted);
      expect(await closure(), first);

      clock = lockedAt.add(const Duration(seconds: 60));
      expect(await reconcile(_two, 2), SsoHandoffStatus.notAccepted);
    },
  );

  test('The cooldown does not block an eligible start', () async {
    await holdOnServer();
    final start = clock;
    expect(await reconcile(_two, 1), SsoHandoffStatus.notAccepted);

    clock = start.add(const Duration(seconds: 1));
    expect(await handoff.prepareTake(session, pilot), 2);
    final started = await handoff.takeIntent(
      session,
      pilot,
      _one,
      2,
      reconcile: false,
    );
    expect(started, isA<SsoDeviceReservation>());
    final reserved = await closure();
    expect(reserved, ('deviceReserved', 2, ssoDigest(_one), 1, start));

    // A later reconcile replays the accepted take and cannot close it.
    final replayed = await reconcile(_one, 2);
    expect(
      (replayed as SsoDeviceReservation).generation,
      (started as SsoDeviceReservation).generation,
    );
    expect(await reconcile(_two, 2), SsoHandoffStatus.notAccepted);
    expect(await closure(), reserved);
  });
}
