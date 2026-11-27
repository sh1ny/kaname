import 'dart:async';

import 'package:kaname_server/src/esi/member_roster_endpoint.dart';
import 'package:kaname_server/src/esi/sso_sessions.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../support/observe_postgres_lock.dart';
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
      final entered = Completer<void>();
      final resume = Completer<void>();
      final held = _ObservedPageSession(
        first,
        beforeTransaction: () async {
          entered.complete();
          await resume.future;
        },
      );
      final duplicate = _ObservedPageSession(second);
      addTearDown(held.close);
      addTearDown(duplicate.close);
      var firstSettled = false;
      final firstPage = endpoint.page(held, null).then((page) {
        firstSettled = true;
        return page;
      });
      try {
        await Future.any<void>([
          entered.future,
          firstPage.then((_) => fail('The first read skipped its barrier.')),
        ]);
        expect(
          (await endpoint.page(duplicate, null)).status,
          MemberRosterStatus.busy,
        );
        expect(duplicate.databaseAccesses, 0);
        final other = await endpoint.page(unrelated, null);
        expect(other.status, MemberRosterStatus.ok);
        expect(other.accountId, b.toString());
        expect(firstSettled, isFalse);
      } finally {
        resume.complete();
        await firstPage;
      }
      expect((await firstPage).accountId, a.toString());
      expect(
        (await endpoint.page(duplicate, null)).status,
        MemberRosterStatus.ok,
      );
    }, timeout: const Timeout(Duration(minutes: 3)));

    test(
      'a session that expires while its admission read waits is denied',
      () async {
        final db = sessions.build();
        addTearDown(db.close);
        final authority = SsoSessions();
        final id = int.parse(first.authenticated!.authId);
        await db.db.unsafeExecute(
          '''UPDATE esi_session SET "expiresAt" = TIMESTAMP 'infinity'
           WHERE id = @id::bigint''',
          parameters: QueryParameters.named({'id': id}),
        );
        expect(await authority.viewerById(db, id, a), isNotNull);

        final locked = Completer<int>();
        final resume = Completer<void>();
        final writer = db.db.transaction((tx) async {
          await db.db.unsafeExecute(
            'LOCK TABLE esi_session IN ACCESS EXCLUSIVE MODE',
            transaction: tx,
          );
          final holder =
              (await db.db.unsafeQuery(
                    'SELECT pg_backend_pid()',
                    transaction: tx,
                  )).single.single
                  as int;
          locked.complete(holder);
          await resume.future;
          await db.db.unsafeExecute(
            '''UPDATE esi_session SET "expiresAt" = clock_timestamp() AT TIME ZONE 'UTC'
             WHERE id = @id::bigint''',
            parameters: QueryParameters.named({'id': id}),
            transaction: tx,
          );
        });
        late Future<SsoViewer?> read;
        try {
          final holder = await Future.any<int>([
            locked.future,
            writer.then(
              (_) => fail('The writer settled before locking sessions.'),
            ),
          ]);
          // The expiry read may open a delete transaction of its own. Start
          // it outside the writer's transaction zone.
          read = authority.viewerById(first, id, a);
          await observePostgresLock(second, holder, read);
        } finally {
          resume.complete();
          await writer;
        }
        expect(await read, isNull);
        expect(await SsoSessionRow.db.findById(db, id), isNull);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}

/// Observes database access without replacing the session's Postgres queries.
final class _ObservedPageSession extends Session {
  _ObservedPageSession(Session source, {this.beforeTransaction})
    : super(
        server: source.server,
        enableLogging: false,
        endpoint: 'RosterTest',
      ) {
    updateAuthenticated(source.authenticated);
  }

  final Future<void> Function()? beforeTransaction;
  var databaseAccesses = 0;

  @override
  Database get db {
    final real = super.db;
    final before = beforeTransaction;
    return databaseAccesses++ == 0 && before != null
        ? _HeldPageTransaction(real, before)
        : real;
  }
}

/// Pauses entry into the first transaction without holding a database lock.
final class _HeldPageTransaction implements Database {
  _HeldPageTransaction(this._real, this._before);

  final Database _real;
  final Future<void> Function() _before;

  @override
  Future<R> transaction<R>(
    Future<R> Function(Transaction) action, {
    TransactionSettings? settings,
  }) async {
    await _before();
    return _real.transaction(action, settings: settings);
  }

  @override
  Object? noSuchMethod(Invocation invocation) => fail(
    'Expected the page to start a transaction, not ${invocation.memberName}.',
  );
}
