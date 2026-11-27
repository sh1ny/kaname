import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaname_app/esi_sso/data/call_log_client.dart';
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

  for (final ambiguous in [false, true]) {
    testWidgets(
      ambiguous
          ? 'lost unlink keeps own history empty until fresh sign-in'
          : 'unlink fences a pending old own-history reply',
      (tester) async {
        final server = _Server(ambiguous: ambiguous);
        final history = _History();
        await http.runWithClient(() async {
          final scope = await _open(tester, history: history);
          await _signIn(tester);
          final pending = scope.read(callLogProvider.notifier).own();
          history.next.complete(EsiCallLogPage(status: 'ok', rows: []));
          await pending;
          await tester.pumpAndSettle();
          final second = scope.read(callLogProvider.notifier).own();
          await _tap(tester, _unlink);
          history.next.complete(EsiCallLogPage(status: 'ok', rows: []));
          await second;
          await tester.pumpAndSettle();
          expect(scope.read(callLogProvider), isNot(isA<CallLogOwn>()));
          if (ambiguous) {
            expect(find.text('My calls'), findsNothing);
            final count = history.reads;
            await scope.read(callLogProvider.notifier).own();
            expect(history.reads, count);
          }
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
  _History? history,
}) async {
  final scope = ProviderContainer(
    overrides: [
      serverTargetProvider.overrideWith((ref) => ref.watch(_target)),
      desktopAccountProvider.overrideWith((_) async => null),
      if (history != null) callLogAccessProvider.overrideWithValue(history),
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

final class _Server {
  _Server({this.ambiguous = false, this.loseRevoke = false, this.self = false});

  final bool ambiguous;
  final bool loseRevoke;
  final bool self;
  final selfReply = Completer<void>();
  final next = Completer<MemberRosterPage>();
  final revocations = <String>[];
  final rosterRequests = <http.Request>[];
  final linkRequests = <http.Request>[];
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
        return _json({...pilot, 'session': 'b' * 43});
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

final class _History implements CallLogAccess {
  Completer<EsiCallLogPage> next = Completer<EsiCallLogPage>();
  int reads = 0;

  @override
  bool get admin => false;

  @override
  Future<EsiCallLogPage> own(EsiCallLogCursor? after) {
    reads++;
    next = Completer<EsiCallLogPage>();
    return next.future;
  }

  @override
  Future<EsiRouteCountPage> totals() async => fail('not an administrator');
}
