import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaname_app/esi_sso/ui/esi_account_section.dart';
import 'package:kaname_app/l10n/generated/app_localizations.dart';
import 'package:kaname_app/server/data/server_address.dart';
import 'package:kaname_app/server/logic/server_status.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

void main() {
  testWidgets('Skills refusals preserve their reasons and retry times', (
    tester,
  ) async {
    var status = 503;
    final clock = DateTime(2026, 11, 25, 15, 28);
    var refusal = <String, Object?>{};
    var reads = 0;
    final client = MockClient((request) async {
      const pilot = {
        'characterId': '410',
        'characterName': 'Pilot',
        'memberId': '1',
        'admin': false,
        'holder': 'serverHeld',
      };
      switch (request.url.pathSegments.last) {
        case 'begin':
          return http.Response(
            jsonEncode({
              'attemptId': 'a' * 43,
              'authorizationUrl': 'https://login.eveonline.com/authorize',
            }),
            200,
          );
        case 'complete':
          return http.Response(
            jsonEncode({...pilot, 'session': 'b' * 43}),
            200,
          );
        case 'viewer':
          return http.Response(jsonEncode(pilot), 200);
        case 'skills':
          reads++;
          return http.Response(jsonEncode(refusal), status);
        default:
          fail('unexpected request');
      }
    });
    addTearDown(client.close);
    await http.runWithClient(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverTargetProvider.overrideWithValue(
              ConfiguredServer(Uri.parse('https://kaname.test/api/')),
            ),
          ],
          child: MaterialApp(
            theme: EmberTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: EsiAccountSection(now: () => clock),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Sign in to server'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish sign-in'));
      await tester.pumpAndSettle();
      const reasons = {
        'budget': 'EVE’s rate limit does not allow this request yet.',
        'stopped': 'EVE calls are paused because a request limit was reached.',
        'queueFull': 'The EVE request queue is full.',
        'waitExpired': 'This request expired while waiting to be sent.',
        'negativeCached':
            'EVE recently refused this read or reported it missing.',
        'notDue': 'The current EVE data is not due to be refreshed.',
        'outage': 'EVE requests are paused while Tranquility is unavailable.',
        'stateUnavailable':
            'Kaname could not confirm a safe slot for this EVE request.',
        'corpBusy': 'Another caller is already checking this corporation data.',
        'scopeCapacity': 'Kaname is tracking too many EVE request limits.',
        'routeConflict': 'EVE reported conflicting limits for this request.',
        'invalidContext':
            'The current request or account could not be used safely.',
        'stateRecovering':
            'One request is already checking this EVE rate limit.',
      };
      Future<void> read() async {
        final button = find.text('Read skills on server');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      for (final entry in reasons.entries) {
        refusal = {'status': 'refused', 'reason': entry.key};
        await read();
        expect(find.text(entry.value), findsOneWidget);
        expect(find.textContaining('Retry after'), findsNothing);
      }
      refusal = {
        'status': 'refused',
        'reason': 'stateRecovering',
        'retryAt': clock
            .add(const Duration(seconds: 30))
            .millisecondsSinceEpoch,
      };
      await read();
      expect(find.textContaining('3:28:30'), findsOneWidget);
      refusal['retryAt'] = 0;
      await read();
      expect(find.text('You can try again now.'), findsOneWidget);
      refusal = {'status': 'refused', 'reason': 'untrusted opaque text'};
      await read();
      expect(find.textContaining('untrusted opaque text'), findsNothing);
      expect(
        find.text('Kaname could not complete the EVE request.'),
        findsOneWidget,
      );
      status = 429;
      refusal = {'status': 'busy'};
      await read();
      expect(
        find.text('Kaname is busy. Try the skills read again shortly.'),
        findsOneWidget,
      );
      expect(find.text(reasons['stateRecovering']!), findsNothing);
      status = 503;
      refusal = {'status': 'unavailable'};
      await read();
      expect(
        find.text('Kaname could not complete the EVE request.'),
        findsOneWidget,
      );
      expect(reads, reasons.length + 5);
    }, () => client);
  });
}
