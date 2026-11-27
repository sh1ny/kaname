import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaname_app/esi_sso/data/account_types.dart';
import 'package:kaname_app/esi_sso/data/call_log_client.dart';
import 'package:kaname_app/esi_sso/data/desktop_platform.dart';
import 'package:kaname_app/esi_sso/logic/account.dart';
import 'package:kaname_app/esi_sso/logic/call_log.dart';
import 'package:kaname_app/esi_sso/ui/call_log_panel.dart';
import 'package:kaname_app/esi_sso/ui/esi_account_section.dart';
import 'package:kaname_app/l10n/generated/app_localizations.dart';
import 'package:kaname_app/server/data/server_address.dart';
import 'package:kaname_app/server/logic/server_status.dart';
import 'package:kaname_client/kaname_client.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

const _next = 'Next characters';
const _unlink = 'Unlink';
const _recover = 'Revoke old session';

void main() {
  testWidgets('connected Settings shows account main and signing alt', (
    tester,
  ) async {
    final server = _Server();
    await http.runWithClient(() async {
      await _open(tester);
      expect(find.text('Link character'), findsNothing);
      await _signIn(tester);
      expect(server.rosterRequests, hasLength(1));
      expect(server.rosterRequests.single.url.origin, 'https://kaname.test');
      expect(
        server.rosterRequests.single.headers['authorization'],
        'Bearer ${'b' * 43}',
      );
      expect(server.rosterRequests.single.followRedirects, isFalse);
      expect(find.text('Main: Main Pilot'), findsOneWidget);
      expect(find.text('Signed in as: Alt Pilot'), findsOneWidget);
      expect(find.text('Link character'), findsOneWidget);
      expect(find.text('Make main'), findsOneWidget);
      expect(find.text(_unlink), findsOneWidget);
      await _tap(tester, 'Link character');
      await _tap(tester, 'Finish linking');
      expect(find.text('Character linked.'), findsOneWidget);
      expect(find.text('Signed in as: Alt Pilot'), findsOneWidget);
      expect(
        server.linkRequests.map((request) => request.url.pathSegments.last),
        ['begin', 'complete'],
      );
      expect(
        server.linkRequests.map((request) => request.headers['authorization']),
        everyElement('Bearer ${'b' * 43}'),
      );
      expect(server.rosterRequests, hasLength(2));
    }, () => MockClient(server.call));
  });

  for (final changeOrigin in [false, true]) {
    testWidgets(
      changeOrigin
          ? 'old roster reply cannot cross an origin change'
          : 'old roster reply cannot cross sign-out',
      (tester) async {
        final server = _Server();
        await http.runWithClient(() async {
          final scope = await _open(tester);
          await _signIn(tester);
          await _tap(tester, _next, settle: false);
          expect(server.nextPageCalls, 1);
          if (changeOrigin) {
            scope
                .read(_target.notifier)
                .change('https://other.kaname.test/api/');
          } else {
            await scope.read(accountProvider.notifier).signOut();
          }
          server.next.complete(_page(stale: true));
          await tester.pumpAndSettle();
          expect(find.text('Stale second page'), findsNothing);
          expect(find.text('Main: Main Pilot'), findsNothing);
          expect(find.text('Sign in to server'), findsOneWidget);
        }, () => MockClient(server.call));
      },
    );
  }

  testWidgets('confirmed self-unlink signs out without reusing the bearer', (
    tester,
  ) async {
    final server = _Server(self: true);
    await http.runWithClient(() async {
      await _open(tester);
      await _signIn(tester);
      await _tap(tester, _unlink, settle: false);
      expect(find.text('Main: Main Pilot'), findsNothing);
      expect(find.text('My calls'), findsNothing);
      server.selfReply.complete();
      await tester.pumpAndSettle();
      expect(find.text('Sign in to server'), findsOneWidget);
      expect(find.text('Main: Main Pilot'), findsNothing);
      expect(server.revocations, isEmpty);
    }, () => MockClient(server.call));
  });

  testWidgets(
    'confirmed unlink drops an older second page on the same bearer',
    (tester) async {
      final server = _Server();
      await http.runWithClient(() async {
        await _open(tester);
        await _signIn(tester);
        await _tap(tester, _next, settle: false);
        expect(server.nextPageCalls, 1);
        await _tap(tester, _unlink);
        server.next.complete(_page(stale: true));
        await tester.pumpAndSettle();
        expect(server.unlinkCalls, 1);
        expect(find.text('Stale second page'), findsNothing);
        expect(find.text('Main: Main Pilot'), findsOneWidget);
        expect(find.text(_next), findsNothing);
      }, () => MockClient(server.call));
    },
  );

  testWidgets('ambiguous unlink fences roster replies until fresh sign-in', (
    tester,
  ) async {
    final server = _Server(ambiguous: true);
    await http.runWithClient(() async {
      await _open(tester);
      await _signIn(tester);
      await _tap(tester, _next, settle: false);
      await _tap(tester, _unlink);
      server.next.complete(_page(stale: true));
      await tester.pumpAndSettle();
      expect(find.text('Stale second page'), findsNothing);
      expect(find.text('My calls'), findsNothing);
      expect(find.text('Sign in to server'), findsNothing);
      await _tap(tester, _recover);
      expect(find.text('Sign in to server'), findsOneWidget);
      await _signIn(tester);
      expect(find.text('Main: Main Pilot'), findsOneWidget);
      expect(find.text('Stale second page'), findsNothing);
      expect(server.unlinkCalls, 1);
    }, () => MockClient(server.call));
  });

  for (final replyPending in [false, true]) {
    testWidgets('returning to the original server requires recovery '
        'with unlink reply pending: $replyPending', (tester) async {
      final original = _Server(ambiguous: true);
      final other = _Server();
      final reply = original.unlinkReply = Completer<void>();
      await http.runWithClient(
        () async {
          final scope = await _open(tester);
          final target = scope.read(_target.notifier);
          try {
            await _signIn(tester);
            await _tap(tester, _unlink, settle: false);
            expect(original.unlinkCalls, 1);
            if (!replyPending) {
              reply.complete();
              await tester.pumpAndSettle();
            }
            target.change('https://other.kaname.test/api/');
            await tester.pumpAndSettle();
            await _signIn(tester);
            expect(
              other.rosterRequests.single.url.origin,
              'https://other.kaname.test',
            );
            expect(find.text('My calls'), findsOneWidget);

            target.change('https://kaname.test/api/');
            await tester.pumpAndSettle();
            expect(find.text('Sign in to server'), findsNothing);
            expect(find.text('Linked characters'), findsNothing);
            expect(find.text('My calls'), findsNothing);
            expect(original.rosterRequests, hasLength(1));
            await _tap(tester, _recover);
            expect(other.revocations, isEmpty);
            expect(original.revocations, ['Bearer ${'b' * 43}']);
            await _signIn(tester);
            expect(
              original.rosterRequests.last.headers['authorization'],
              'Bearer ${'c' * 43}',
            );
            if (replyPending) {
              reply.complete();
              await tester.pumpAndSettle();
            }
            expect(find.text('Main: Main Pilot'), findsOneWidget);
            expect(find.text('My calls'), findsOneWidget);
            expect(original.unlinkCalls, 1);
          } finally {
            if (!reply.isCompleted) reply.complete();
          }
        },
        () => MockClient(
          (request) => (request.url.host == 'kaname.test' ? original : other)
              .call(request),
        ),
      );
    });
  }

  testWidgets(
    'lost revocation acknowledgment requires same-session retry then fresh sign-in',
    (tester) async {
      final server = _Server(ambiguous: true, loseRevoke: true);
      await http.runWithClient(() async {
        await _open(tester);
        await _signIn(tester);
        await _tap(tester, _unlink);
        await _tap(tester, _recover);
        expect(find.text('Sign in to server'), findsNothing);
        expect(find.text('My calls'), findsNothing);
        await _tap(tester, _recover);
        expect(find.text('Main: Main Pilot'), findsNothing);
        expect(server.revocations, List.filled(2, 'Bearer ${'b' * 43}'));
        expect(server.unlinkCalls, 1);
        await _signIn(tester);
        expect(find.text('Main: Main Pilot'), findsOneWidget);
      }, () => MockClient(server.call));
    },
  );

  testWidgets('solo skills remain available while unlink recovery is pending', (
    tester,
  ) async {
    final server = _Server(ambiguous: true, loseRevoke: true);
    final desktop = _Solo();
    await http.runWithClient(() async {
      await _open(tester, desktop: desktop);
      await _signIn(tester);
      await _tap(tester, _unlink);
      await _tap(tester, _recover);
      await _tap(tester, 'Read skills in solo mode', settle: false);
      expect(desktop.reads, 1);
      expect(find.text('My calls'), findsNothing);
      expect(find.text('Linked characters'), findsNothing);

      // Exact revocation can finish while the unrelated local read is pending.
      await _tap(tester, _recover, settle: false);
      desktop.result.complete((
        AccountNotice.none,
        (count: 12, totalSp: 345),
        null,
      ));
      await tester.pumpAndSettle();
      expect(find.text('12 skills, 345 skill points'), findsOneWidget);
      expect(find.text('Sign in to server'), findsOneWidget);
      expect(find.text('My calls'), findsNothing);
      expect(server.revocations, List.filled(2, 'Bearer ${'b' * 43}'));
    }, () => MockClient(server.call));
  }, skip: !hasDesktopHolder);

  for (final ambiguous in [false, true]) {
    testWidgets(
      ambiguous
          ? 'lost unlink keeps own history empty until fresh sign-in'
          : 'unlink fences a pending old own-history reply',
      (tester) async {
        final server = _Server(ambiguous: ambiguous);
        final history = _HistoryRequests();
        await http.runWithClient(() async {
          final scope = await _open(tester, history: history);
          await _signIn(tester);
          final first = _historyPage('1', 'Old first page', next: true);
          await _tap(tester, 'My calls', settle: false);
          history.pages.single.complete(first);
          await tester.pumpAndSettle();
          expect(find.text('Old first page'), findsOneWidget);
          await _tap(tester, 'Older calls', settle: false);
          expect(history.requests.last.after?.toJson(), first.next!.toJson());
          await _tap(tester, _unlink);
          history.pages.last.complete(_historyPage('2', 'Old second page'));
          await tester.pumpAndSettle();
          expect(find.text('Old first page'), findsNothing);
          expect(find.text('Old second page'), findsNothing);
          expect(find.text('Older calls'), findsNothing);
          if (!ambiguous) return;

          expect(find.text('My calls'), findsNothing);
          await scope.read(callLogProvider.notifier).own();
          expect(history.requests, hasLength(2));
          await _tap(tester, _recover);
          expect(find.text('My calls'), findsNothing);
          await _signIn(tester);
          expect(find.text('Older calls'), findsNothing);
          await _tap(tester, 'My calls', settle: false);
          expect(history.requests.last, (bearer: 'c' * 43, after: null));
          history.pages.last.complete(_historyPage('3', 'Settled first page'));
          await tester.pumpAndSettle();
          expect(find.text('Settled first page'), findsOneWidget);
          expect(find.text('Old first page'), findsNothing);
          expect(find.text('Old second page'), findsNothing);
        }, () => MockClient(server.call));
      },
    );
  }
}

final _target = NotifierProvider<_Target, ServerTarget>(_Target.new);

final class _Target extends Notifier<ServerTarget> {
  @override
  ServerTarget build() =>
      ConfiguredServer(Uri.parse('https://kaname.test/api/'));

  void change(String uri) => state = ConfiguredServer(Uri.parse(uri));
}

Future<ProviderContainer> _open(
  WidgetTester tester, {
  DesktopAccount? desktop,
  _HistoryRequests? history,
}) async {
  final scope = ProviderContainer(
    overrides: [
      serverTargetProvider.overrideWith((ref) => ref.watch(_target)),
      desktopAccountProvider.overrideWith((_) async => desktop),
      if (history != null)
        callLogAccessProvider.overrideWith((ref) {
          final session = ref.watch(connectedAccountSessionProvider);
          final target = ref.watch(serverTargetProvider);
          final bearer = target is ConfiguredServer
              ? session?.bearerFor(target.uri)
              : null;
          return bearer == null ? null : _History(history, bearer);
        }),
    ],
  );
  addTearDown(scope.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: scope,
      child: MaterialApp(
        theme: EmberTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [EsiAccountSection(), CallLogPanel()]),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return scope;
}

Future<void> _signIn(WidgetTester tester) async {
  await _tap(tester, 'Sign in to server');
  await _tap(tester, 'Finish sign-in');
}

Future<void> _tap(
  WidgetTester tester,
  String label, {
  bool settle = true,
}) async {
  final finder = find.text(label);
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

http.Response _json(Object payload, [int code = 200]) =>
    http.Response(jsonEncode(payload), code);

MemberRosterPage _page({
  bool removed = false,
  bool stale = false,
  bool self = false,
}) {
  final main = MemberCharacter(
    characterId: '410',
    name: 'Main Pilot',
    blocked: false,
  );
  final signer = MemberCharacter(
    characterId: '411',
    name: 'Alt Pilot',
    blocked: false,
  );
  final other = MemberCharacter(
    characterId: '412',
    name: 'Another Alt',
    blocked: false,
  );
  return MemberRosterPage(
    status: MemberRosterStatus.ok,
    accountId: '1',
    main: main,
    signing: signer,
    characters: stale
        ? [
            MemberCharacter(
              characterId: '450',
              name: 'Stale second page',
              blocked: false,
            ),
          ]
        : [main, if (!removed) self ? signer : other],
    next: removed || stale || self ? null : '412',
  );
}

EsiCallLogPage _historyPage(String id, String operation, {bool next = false}) {
  final time = DateTime.utc(2026, 11, 27);
  final cursor = EsiCallLogCursor(recordedAt: time, id: id);
  return EsiCallLogPage(
    status: 'ok',
    next: next ? cursor : null,
    rows: [
      EsiCallLogReceipt(
        cursor: cursor,
        recordedAt: time,
        characterId: '411',
        operation: operation,
        outcome: 'success',
        latencyMicros: 1,
      ),
    ],
  );
}

final class _Server {
  _Server({this.ambiguous = false, this.loseRevoke = false, this.self = false});

  final bool ambiguous;
  final bool loseRevoke;
  final bool self;
  final selfReply = Completer<void>();
  Completer<void>? unlinkReply;
  final next = Completer<MemberRosterPage>();
  final revocations = <String>[];
  final rosterRequests = <http.Request>[];
  final linkRequests = <http.Request>[];
  int signIns = 0;
  int nextPageCalls = 0;
  int unlinkCalls = 0;

  Future<http.Response> call(http.Request request) async {
    const pilot = {
      'characterId': '411',
      'characterName': 'Alt Pilot',
      'memberId': '1',
      'admin': false,
    };
    switch (request.url.pathSegments) {
      case ['api', 'memberRoster', 'page']:
        rosterRequests.add(request);
        final arguments = jsonDecode(request.body) as Map<String, Object?>;
        if (arguments['after'] != null) {
          nextPageCalls++;
          return _json((await next.future).toJson());
        }
        return _json(_page(removed: unlinkCalls != 0, self: self).toJson());
      case ['api', 'memberAccount', 'unlink']:
        final args = jsonDecode(request.body) as Map<String, Object?>;
        expect(args['characterId'], self ? '411' : '412');
        unlinkCalls++;
        await unlinkReply?.future;
        if (ambiguous) throw http.ClientException('lost reply');
        if (self) await selfReply.future;
        return _json(
          MemberAccountMutation(
            status: self
                ? MemberAccountStatus.selfUnlinked
                : MemberAccountStatus.unlinked,
          ).toJson(),
        );
    }
    switch (request.url.pathSegments.last) {
      case 'begin':
        if ((jsonDecode(request.body) as Map<String, Object?>)['link'] ==
            true) {
          linkRequests.add(request);
        }
        return _json({
          'attemptId': 'a' * 43,
          'authorizationUrl': 'https://login.eveonline.com/authorize',
        });
      case 'complete':
        if ((jsonDecode(request.body) as Map<String, Object?>)['link'] ==
            true) {
          linkRequests.add(request);
          return _json({'status': 'linked'});
        }
        return _json({...pilot, 'session': (++signIns == 1 ? 'b' : 'c') * 43});
      case 'viewer':
        return _json(pilot);
      case 'sign-out':
        revocations.add(request.headers['authorization']!);
        if (loseRevoke && revocations.length == 1) {
          throw http.ClientException('lost acknowledgment');
        }
        return _json({'status': 'signedOut'});
      default:
        fail('unexpected request: ${request.url.path}');
    }
  }
}

final class _HistoryRequests {
  final requests = <({String bearer, EsiCallLogCursor? after})>[];
  final pages = <Completer<EsiCallLogPage>>[];
}

final class _History implements CallLogAccess {
  _History(this._log, this._bearer);

  final _HistoryRequests _log;
  final String _bearer;

  @override
  bool get admin => false;

  @override
  Future<EsiCallLogPage> own(EsiCallLogCursor? after) {
    _log.requests.add((bearer: _bearer, after: after));
    final page = Completer<EsiCallLogPage>();
    _log.pages.add(page);
    return page.future;
  }

  @override
  Future<EsiRouteCountPage> totals() async => fail('not an administrator');
}

final class _Solo implements DesktopAccount {
  final result = Completer<SkillsRead>();
  var reads = 0;

  @override
  final clientId = 'solo-fixture';

  @override
  final pilot = const AccountPilot(
    characterId: '999',
    name: 'Solo Pilot',
    holder: 'solo',
  );

  @override
  Future<SkillsRead> skills() {
    reads++;
    return result.future;
  }

  @override
  bool permitsServerGrant(String characterId) => true;

  @override
  bool ownsReservationFor(String origin, String characterId) => false;

  @override
  AccountNotice configure(String clientId) => fail('unexpected configure');

  @override
  Future<AccountNotice> identify() => fail('unexpected identify');

  @override
  Future<AccountNotice> authorizeSkills() => fail('unexpected authorize');

  @override
  Future<AccountNotice> disableSkills() => fail('unexpected disable');

  @override
  Future<AccountNotice> take(HolderRemote remote) => fail('unexpected take');

  @override
  Future<AccountNotice> returnTo(HolderRemote remote) =>
      fail('unexpected return');

  @override
  void cancel() {}

  @override
  Future<void> close() async {}
}
