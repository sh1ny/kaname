import 'dart:async';

import 'package:kaname_server/src/esi/esi_call_log_endpoint.dart';
import 'package:kaname_server/src/esi/esi_call_log_store.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../test_tools/serverpod_test_tools.dart';

const _operation = 'GetCharactersCharacterIdSkills';

typedef _Pilot = ({int account, int character, int session});

void main() {
  withServerpod('Scoped ESI receipt projections', (sessions, endpoints) {
    late Session session;
    late _Pilot first;
    late _Pilot second;
    late DateTime now;

    TestSessionBuilder signed(_Pilot viewer, {bool admin = false}) =>
        sessions.copyWith(
          authentication: AuthenticationOverride.authenticationInfo(
            viewer.account.toString(),
            {if (admin) Scope.admin},
            authId: viewer.session.toString(),
          ),
        );

    Future<_Pilot> addPilot(int character) => session.db.transaction((
      transaction,
    ) async {
      final identity = await SsoIdentityRow.db.insertRow(
        session,
        SsoIdentityRow(
          characterId: character,
          owner: 'b3duZXI=',
          characterName: 'Pilot',
          blocked: false,
        ),
        transaction: transaction,
      );
      final account = await MemberAccountRow.db.insertRow(
        session,
        MemberAccountRow(mainIdentityId: identity.id!),
        transaction: transaction,
      );
      await SsoIdentityRow.db.updateRow(
        session,
        identity.copyWith(accountId: account.id),
        transaction: transaction,
      );
      final signed = await SsoSessionRow.db.insertRow(
        session,
        SsoSessionRow(
          digest: 'test-session-$character',
          accountId: account.id!,
          identityId: identity.id!,
          expiresAt: now.add(const Duration(days: 1)),
        ),
        transaction: transaction,
      );
      return (account: account.id!, character: character, session: signed.id!);
    });

    Future<void> receipt(_Pilot viewer, DateTime at) async {
      await EsiCallLogRow.db.insertRow(
        session,
        EsiCallLogRow(
          recordedAt: at,
          operation: _operation,
          outcome: 'success',
          status: 200,
          cost: 2,
          latencyMicros: 10,
          memberId: viewer.account,
          characterId: viewer.character,
        ),
      );
    }

    setUp(() async {
      now = DateTime.now().toUtc();
      session = sessions.build();
      addTearDown(session.close);
      await session.db.unsafeExecute('DELETE FROM esi_call_log_seal');
      first = await addPilot(511);
      second = await addPilot(512);
      addTearDown(() async {
        final cleanup = sessions.build();
        try {
          await EsiCallLogRow.db.deleteWhere(
            cleanup,
            where: (t) => t.characterId.between(511, 516),
          );
          await cleanup.db.unsafeExecute('''
            DELETE FROM esi_session WHERE "identityId" IN
              (SELECT id FROM esi_identity WHERE "characterId" BETWEEN 511 AND 516)
          ''');
          await cleanup.db.unsafeExecute('''
            UPDATE esi_identity SET "accountId" = NULL
            WHERE "characterId" BETWEEN 511 AND 516
          ''');
          await cleanup.db.unsafeExecute('''
            DELETE FROM member_account WHERE "mainIdentityId" IN
              (SELECT id FROM esi_identity WHERE "characterId" BETWEEN 511 AND 516)
          ''');
          await SsoIdentityRow.db.deleteWhere(
            cleanup,
            where: (t) => t.characterId.between(511, 516),
          );
        } finally {
          await cleanup.close();
        }
      });
    });

    test('A member pages through their own calls', () async {
      for (var i = 0; i < 101; i++) {
        await receipt(first, now.subtract(Duration(seconds: i)));
      }
      await receipt(second, now);
      final page = await endpoints.esiCallLog.ownRows(signed(first), null);
      expect(page.rows, hasLength(100));
      expect(page.rows.map((r) => r.characterId).toSet(), {'511'});
      final older = await endpoints.esiCallLog.ownRows(
        signed(first),
        page.next,
      );
      expect(older.rows.single.characterId, '511');
      expect(
        older.rows.single.recordedAt.isBefore(page.rows.last.recordedAt),
        isTrue,
      );
      expect(older.next, isNull);
    });

    test('An admin reads both views', () async {
      final yesterday = now.subtract(const Duration(days: 2));
      await receipt(first, now);
      await receipt(second, yesterday);
      for (var id = 513; id < 517; id++) {
        await receipt(await addPilot(id), yesterday);
      }
      final admin = signed(first, admin: true);
      expect(
        (await endpoints.esiCallLog.ownRows(
          admin,
          null,
        )).rows.single.characterId,
        '511',
      );
      final totals = await endpoints.esiCallLog.routeCounts(admin);
      expect(totals.rows.single.operation, _operation);
      expect(totals.rows.single.total, 5);
      expect(totals.rows.single.errors, 0);
    });

    test('An anonymous or forged viewer requests data', () async {
      await receipt(first, now);
      final denied = await endpoints.esiCallLog.ownRows(sessions, null);
      expect(denied.status, 'denied');
      expect(denied.rows, isEmpty);
      final borrowed = (await endpoints.esiCallLog.ownRows(
        signed(first),
        null,
      )).rows.single.cursor;
      expect(
        (await endpoints.esiCallLog.ownRows(signed(second), borrowed)).rows,
        isEmpty,
      );
      expect(
        (await endpoints.esiCallLog.routeCounts(signed(second))).status,
        'denied',
      );
    });

    test('Log reads reach the server work limit', () async {
      final reader = EsiCallLogReads(EsiCallLogStore());
      final viewers = [
        for (final pilot in [
          first,
          second,
          await addPilot(513),
          await addPilot(514),
          await addPilot(515),
        ])
          signed(pilot).build(),
      ];
      for (final viewer in viewers) {
        addTearDown(viewer.close);
      }
      final pending = [
        for (final viewer in viewers.take(4)) reader.own(viewer, null),
      ];
      final refused = [
        reader.own(viewers.first, null),
        reader.own(viewers.last, null),
      ];
      expect((await Future.wait(refused)).map((page) => page.status), [
        'busy',
        'busy',
      ]);
      expect(
        (await Future.wait(pending)).map((page) => page.status),
        List.filled(4, 'ok'),
      );
      expect((await reader.own(viewers.last, null)).status, 'ok');
    });

    test('Admins read the same released window', () async {
      final at = DateTime.utc(2026, 11, 25, 9);
      var clock = at;
      final store = EsiCallLogStore(now: () => clock);
      final reader = EsiCallLogReads(store);
      final admin = signed(first, admin: true).build();
      final other = signed(second, admin: true).build();
      addTearDown(admin.close);
      addTearDown(other.close);
      for (final pilot in [
        first,
        second,
        await addPilot(513),
        await addPilot(514),
        await addPilot(515),
      ]) {
        await receipt(pilot, at.subtract(const Duration(days: 2)));
      }
      final before = await reader.totals(admin);
      expect(before.rows.single.total, 5);
      await receipt(second, at);
      expect((await reader.totals(other)).rows.single.total, 5);
      clock = at.add(const Duration(days: 1));
      expect((await reader.totals(other)).rows.single.total, 6);
    });

    test('newer seal refuses prior results for owners waiters and cache hits before admission', () async {
      var clock = DateTime.utc(2026, 11, 25, 9);
      final store = EsiCallLogStore(now: () => clock);
      final owner = signed(first, admin: true).build();
      final waiter = signed(second, admin: true).build();
      addTearDown(owner.close);
      addTearDown(waiter.close);
      for (final pilot in [
        first,
        second,
        await addPilot(513),
        await addPilot(514),
        await addPilot(515),
      ]) {
        await receipt(pilot, clock.subtract(const Duration(days: 2)));
      }

      for (final warmCache in [false, true]) {
        final paused = Completer<void>();
        final resume = Completer<void>();
        final expected = warmCache ? 1 : 2;
        var checks = 0;
        var fence = !warmCache;
        final reader = EsiCallLogReads(
          store,
          readSeal: (admitting) async {
            if (fence) {
              if (++checks == expected) paused.complete();
              await resume.future;
            }
            return store.currentSeal(admitting);
          },
        );
        if (warmCache) {
          final admitted = await reader.totals(owner);
          expect(admitted.rows.single.total, 5);
          fence = true;
        }
        final responses = [
          reader.totals(owner),
          if (!warmCache) reader.totals(waiter),
        ];
        try {
          await Future.any([
            paused.future,
            for (final response in responses)
              response.then((_) => fail('response did not await admission')),
          ]);
          clock = clock.add(const Duration(days: 1));
          await store.sealWindow(session);
        } finally {
          resume.complete();
        }
        for (final page in await Future.wait(responses)) {
          expect(page.status, 'unavailable');
          expect(page.rows, isEmpty);
        }
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  }, rollbackDatabase: RollbackDatabase.disabled);
}
