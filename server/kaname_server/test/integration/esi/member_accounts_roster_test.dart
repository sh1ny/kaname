import 'package:kaname_server/src/esi/member_roster_endpoint.dart';
import 'package:kaname_server/src/esi/sso_sessions.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Member roster admission', (sessions, _) {
    late int a;
    late int b;
    late Session first;
    late Session second;
    late Session unrelated;
    var firstCharacter = 40;

    setUp(() async {
      final db = sessions.build();
      addTearDown(db.close);
      final now = DateTime.utc(2026, 11, 27);
      firstCharacter += 2;
      SsoSessions(now: () => now).bind(db.serverpod);
      Future<int> account(int character) async {
        final identity = await SsoIdentityRow.db.insertRow(
          db,
          SsoIdentityRow(
            characterId: character,
            owner: 'fixture',
            characterName: 'Pilot',
            blocked: false,
          ),
        );
        final account = await MemberAccountRow.db.insertRow(
          db,
          MemberAccountRow(mainIdentityId: identity.id!),
        );
        await SsoIdentityRow.db.updateRow(
          db,
          identity.copyWith(accountId: account.id),
        );
        return account.id!;
      }

      Future<Session> signed(int account, String digest) async {
        final row = (await MemberAccountRow.db.findById(db, account))!;
        final auth = await SsoSessionRow.db.insertRow(
          db,
          SsoSessionRow(
            digest: digest,
            identityId: row.mainIdentityId,
            accountId: account,
            expiresAt: now.add(const Duration(hours: 1)),
          ),
        );
        final session = sessions
            .copyWith(
              authentication: AuthenticationOverride.authenticationInfo(
                account.toString(),
                {},
                authId: auth.id.toString(),
              ),
            )
            .build();
        addTearDown(session.close);
        return session;
      }

      a = await account(firstCharacter);
      b = await account(firstCharacter + 1);
      first = await signed(a, 'first-$a');
      second = await signed(a, 'second-$a');
      unrelated = await signed(b, 'third-$b');
    });

    test('free slots admit the next bounded page', () async {
      final endpoint = MemberRosterEndpoint();
      final page = await endpoint.page(first, null);
      expect(page.main?.characterId, firstCharacter.toString());
      expect(page.accountId, a.toString());
      expect(page.characters.single.characterId, firstCharacter.toString());
      final exhausted = await endpoint.page(first, firstCharacter.toString());
      expect(exhausted.status, MemberRosterStatus.ok);
      expect(exhausted.characters, isEmpty);
    });

    test('second session of one account gets busy without blocking another account', () async {
      final endpoint = MemberRosterEndpoint();
      final firstPage = endpoint.page(first, null);
      final duplicate = endpoint.page(second, null);
      final other = endpoint.page(unrelated, null);
      expect((await duplicate).status, MemberRosterStatus.busy);
      expect((await other).accountId, b.toString());
      expect((await firstPage).accountId, a.toString());
      expect((await endpoint.page(second, null)).status, MemberRosterStatus.ok);
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
