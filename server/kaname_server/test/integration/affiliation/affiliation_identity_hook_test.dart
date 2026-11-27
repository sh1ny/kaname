import 'dart:async';
import 'dart:convert';

import 'package:jose/jose.dart';
import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:kaname_server/src/affiliation/affiliation_runtime.dart';
import 'package:kaname_server/src/affiliation/affiliation_store.dart';
import 'package:kaname_server/src/esi/esi_call_log_store.dart';
import 'package:kaname_server/src/esi/member_accounts.dart';
import 'package:kaname_server/src/esi/server_sso.dart';
import 'package:kaname_server/src/esi/sso_sessions.dart';
import 'package:kaname_server/src/generated/future_calls.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:serverpod/protocol.dart' show FutureCallEntry;
import 'package:serverpod/serverpod.dart';
// ignore: implementation_imports
import 'package:serverpod/src/server/serverpod.dart'
    show ServerpodInternalMethods;
import 'package:test/test.dart';

import 'affiliation_fixture.dart';

const _startup = (boot: 'current', slot: 0);
const _hangGuard = Timeout(Duration(minutes: 3));

void main() {
  late JsonWebKey signing;
  late AffiliationFixture f;
  late DateTime deadline;
  late CcpJwtVerifier verifier;

  setUpAll(() => signing = JsonWebKey.generate('RS256', keyBitLength: 2048));
  setUp(() async {
    f = await AffiliationFixture.open();
    deadline = f.now.add(const Duration(minutes: 20));
    String key(String part) =>
        (signing.toJson()[part] as String).replaceAll('=', '');
    verifier = CcpJwtVerifier(
      now: () => f.now,
      loadKeys: () async => [
        {
          'kty': 'RSA',
          'kid': 'fixture',
          'use': 'sig',
          'alg': 'RS256',
          'n': key('n'),
          'e': key('e'),
        },
      ],
    );
  });

  Future<CcpVerifiedIdentity> claims(int character, {DateTime? expiry}) async {
    final token = JsonWebSignatureBuilder()
      ..stringContent = jsonEncode({
        'iss': 'login.eveonline.com',
        'aud': ['fixture-app', 'EVE Online'],
        'sub': 'CHARACTER:EVE:$character',
        'name': 'Character $character',
        'owner': 'verified-owner',
        'exp': (expiry ?? deadline).millisecondsSinceEpoch ~/ 1000,
      })
      ..addRecipient(
        JsonWebKey.fromJson({...signing.toJson(), 'kid': 'fixture'}),
        algorithm: 'RS256',
      );
    return (await verifier.verify(
      token.build().toCompactSerialization(),
      clientId: 'fixture-app',
    )) as CcpVerifiedIdentity;
  }

  Future<MemberActor> actor(
    SsoSessions sessions,
    Session s,
    Map<String, Object?> auth,
  ) async {
    final viewer = (await sessions.viewer(s, auth['session']! as String))!;
    return (
      account: viewer.accountId,
      session: viewer.sessionId,
      character: viewer.identity.characterId,
    );
  }

  test(
    'configured SSO enqueues first-known work only with execution enabled',
    () async {
      final env = {
        'KANAME_ESI_SSO_CLIENT_ID': 'fixture-app',
        'KANAME_ESI_SSO_CLIENT_SECRET': 'fixture-confidential',
        'KANAME_ESI_SSO_REDIRECT_URI': 'https://kaname.test/auth/esi/callback',
        'KANAME_ESI_VAULT_KEY': base64Encode(List.filled(32, 42)),
      };
      // Installed SSO uses the real clock. No deadline in this test can
      // expire while the test is running, regardless of runner speed.
      final expiry = DateTime.utc(2100);
      final main = await claims(101, expiry: expiry);
      final alt = await claims(102, expiry: expiry);
      for (final execute in [true, false]) {
        final pod = await startComposedAffiliation(
          environment: env,
          execute: execute,
        );
        final sessions = ServerSso.of(pod)!.sessions;
        await _holdEnqueueBudget(
          () => pod.withSession((s) async {
            final auth = (await sessions.signIn(s, main, expiry))!;
            expect(await sessions.signIn(s, main, expiry), isNotNull);
            final member = await actor(sessions, s, auth);
            final accounts = MemberAccounts(sessions, EsiCallLogStore());
            expect(
              await accounts.link(s, member, alt, expiry, () => f.now),
              isTrue,
            );
            expect(
              await accounts.link(s, member, alt, expiry, () => f.now),
              isTrue,
            );
            final queued = await FutureCallEntry.db.find(
              s,
              where: (row) =>
                  row.name.equals('AffiliationCallFirstKnownFutureCall'),
            );
            if (execute) {
              final ids = await SsoIdentityRow.db.find(s);
              expect(
                queued.map(
                  (row) =>
                      (jsonDecode(row.serializedObject!)
                          as Map<String, Object?>)['identityId'],
                ),
                unorderedEquals(ids.map((row) => row.id)),
              );
            } else {
              expect(queued, isEmpty);
            }
          }),
        );
      }
    },
    timeout: _hangGuard,
  );

  test('first sign-in and link commit before the one-off; auth does not wait for ESI', () async {
    await f.pod.futureCalls.cancel('kaname-affiliation:current:0');
    final entered = <int, Completer<void>>{
      101: Completer<void>(),
      102: Completer<void>(),
    };
    final release = Completer<void>();
    f.respond = (ids) async {
      entered[ids.single]!.complete();
      await release.future;
      return jsonReply(200, [
        {'character_id': ids.single, 'corporation_id': 42},
      ]);
    };
    final committed = <int>[];
    final sessions = SsoSessions(
      now: () => f.now,
      afterFirstIdentity: (id) async {
        final identity = await f.pod.withSession(
          (s) => SsoIdentityRow.db.findById(s, id),
        );
        expect(identity?.accountId, isNotNull);
        committed.add(identity!.characterId);
        await f.runtime!.enqueueFirstKnown(id);
      },
    );
    final manager = f.pod.futureCallManager!;
    await manager.start();
    try {
      await _holdEnqueueBudget(
        () => f.pod.withSession((s) async {
          final auth = (await sessions.signIn(s, await claims(101), deadline))!;
          await entered[101]!.future;
          expect(
            await MemberAccounts(sessions, EsiCallLogStore()).link(
              s,
              await actor(sessions, s, auth),
              await claims(102),
              deadline,
              () => f.now,
            ),
            isTrue,
          );
          await entered[102]!.future;
          expect(f.wire.map((call) => call.ids), [
            [101],
            [102],
          ]);
          expect(f.wire.map((call) => call.token), [null, null]);
          expect(committed, [101, 102]);
        }),
      );
    } finally {
      release.complete();
      await manager.stop(unregisterAll: false);
    }
    await f.pod.withSession((s) async {
      expect((await AffiliationStore(s).read(101))?.corporationId, 42);
      expect((await AffiliationStore(s).read(102))?.corporationId, 42);
    });
  }, timeout: _hangGuard);

  test('known or rolled-back identities cannot enqueue a one-off', () async {
    final enqueued = <int>[];
    final sessions = SsoSessions(
      now: () => f.now,
      afterFirstIdentity: (id) async {
        enqueued.add(id);
        await f.runtime!.enqueueFirstKnown(id);
      },
    );
    await _holdEnqueueBudget(
      () => f.pod.withSession((s) async {
        final login = await claims(101);
        final auth = (await sessions.signIn(s, login, deadline))!;
        expect(await sessions.signIn(s, login, deadline), isNotNull);
        expect(
          await MemberAccounts(sessions, EsiCallLogStore()).link(
            s,
            await actor(sessions, s, auth),
            login,
            deadline,
            () => f.now,
          ),
          isTrue,
        );
        // The existing signup path inserts the identity and account before it
        // inserts the session. Force the latter statement to roll back all three.
        await s.db.unsafeExecute(
          'ALTER TABLE esi_session ADD CHECK (false) NOT VALID',
        );
        final rollback = await claims(102);
        await expectLater(
          sessions.signIn(s, rollback, deadline),
          throwsA(isA<DatabaseQueryException>()),
        );
        expect(
          await SsoIdentityRow.db.findFirstRow(
            s,
            where: (row) => row.characterId.equals(102),
          ),
          isNull,
        );
        final identity = (await SsoIdentityRow.db.findFirstRow(
          s,
          where: (row) => row.characterId.equals(101),
        ))!;
        expect(enqueued, [identity.id]);
        expect(await f.queue(s), hasLength(2));
        expect(f.wire, isEmpty);
      }),
    );
  });

  test('failed enqueue or lookup leaves auth successful and the next sweep covers the identity', () async {
    var callbacks = 0;
    final sessions = SsoSessions(
      now: () => f.now,
      afterFirstIdentity: (id) async {
        if (callbacks++ == 0) throw StateError('synthetic enqueue failure');
        await f.runtime!.enqueueFirstKnown(id);
      },
    );
    final codes = <int>[];
    f.respond = (ids) async {
      final code = codes.isEmpty ? 500 : 200;
      codes.add(code);
      return jsonReply(code, [
        for (final id in ids) {'character_id': id, 'corporation_id': 42},
      ]);
    };
    await _holdEnqueueBudget(
      () => f.pod.withSession((s) async {
        await AffiliationRuntime.dispatchSweep(s, _startup);
        await f.pod.futureCalls.cancel('kaname-affiliation:current:0');
        for (final id in [101, 102]) {
          expect(
            await sessions.signIn(s, await claims(id), deadline),
            isNotNull,
          );
        }
        expect(await f.queue(s), hasLength(1));
        await f.pod.futureCallManager!.runScheduledFutureCalls();
        expect(await AffiliationStore(s).read(101), isNull);
        expect(await AffiliationStore(s).read(102), isNull);
        expect(codes, [500]);
        await f.clock.advance(const Duration(hours: 1));
        await AffiliationRuntime.dispatchSweep(s, (boot: 'current', slot: 1));
        expect(f.wire.map((call) => call.ids), [
          [102],
          [101, 102],
        ]);
        expect((await AffiliationStore(s).read(101))?.corporationId, 42);
        expect((await AffiliationStore(s).read(102))?.corporationId, 42);
      }),
    );
  });

  test(
    'a stalled enqueue does not hold auth or leak details in its warning',
    () async {
      final attempted = Completer<void>();
      final stalled = Completer<void>();
      final timer = Completer<_ManualBudget>();
      final messages = <String>[];
      final sessions = SsoSessions(
        now: () => f.now,
        afterFirstIdentity: (_) {
          attempted.complete();
          return stalled.future;
        },
        reportFirstIdentity: messages.add,
      );
      final login = await claims(101);
      await f.pod.withSession((s) async {
        final auth = runZoned(
          () => sessions.signIn(s, login, deadline),
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, callback) {
              if (attempted.isCompleted &&
                  duration == const Duration(seconds: 1)) {
                final manual = _ManualBudget(callback);
                timer.complete(manual);
                return manual;
              }
              return parent.createTimer(zone, duration, callback);
            },
          ),
        );
        try {
          await attempted.future;
          (await timer.future).fire();
          expect(await auth, isNotNull);
          expect(stalled.isCompleted, isFalse);
          expect(messages, [
            'affiliation: could not confirm first-known enqueue',
          ]);
          expect(
            await SsoIdentityRow.db.findFirstRow(
              s,
              where: (row) => row.characterId.equals(101),
            ),
            isNotNull,
          );
        } finally {
          stalled.complete();
          await auth;
        }
      }, enableLogging: false);
    },
    timeout: _hangGuard,
  );

  test('a successful identity commit during shutdown cannot enqueue', () async {
    final locked = Completer<void>();
    final release = Completer<void>();
    final authDone = Completer<void>();
    final sessions = SsoSessions(
      now: () => f.now,
      afterCharacterLock: (_) async {
        locked.complete();
        await release.future;
      },
      afterFirstIdentity: f.runtime!.enqueueFirstKnown,
    );
    f.pod.experimental.shutdownTasks.addTask(
      'wait-for-auth-test',
      () => authDone.future,
    );
    final login = await claims(101);
    final auth = f.pod.withSession((s) async {
      try {
        expect(await sessions.signIn(s, login, deadline), isNotNull);
        expect(
          await SsoIdentityRow.db.findFirstRow(
            s,
            where: (t) => t.characterId.equals(101),
          ),
          isNotNull,
        );
        expect((await f.queue(s)).map((row) => row.identifier), [
          'kaname-affiliation:current:0',
        ]);
      } finally {
        authDone.complete();
      }
    });
    await locked.future;
    final shutdown = f.shutdown();
    release.complete();
    try {
      await auth;
    } finally {
      await shutdown;
    }
    expect(f.wire, isEmpty);
  }, timeout: _hangGuard);
}

// These cases assert a completed enqueue, not expiry of the auth wait.
Future<void> _holdEnqueueBudget(Future<void> Function() body) => runZoned(
  body,
  zoneSpecification: ZoneSpecification(
    createTimer: (self, parent, zone, duration, callback) =>
        duration == const Duration(seconds: 1)
        ? _ManualBudget(callback)
        : parent.createTimer(zone, duration, callback),
  ),
);

final class _ManualBudget implements Timer {
  _ManualBudget(this._callback);

  final void Function() _callback;
  bool _active = true;
  int _tick = 0;

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;

  @override
  void cancel() => _active = false;

  void fire() {
    if (!_active) throw StateError('budget was already cancelled');
    _active = false;
    _tick++;
    _callback();
  }
}
