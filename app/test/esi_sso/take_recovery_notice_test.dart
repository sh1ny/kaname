import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaname_app/esi_sso/data/account_types.dart';
import 'package:kaname_app/esi_sso/data/desktop_platform.dart';
import 'package:kaname_app/esi_sso/logic/account.dart';
import 'package:kaname_app/esi_sso/ui/esi_account_section.dart';
import 'package:kaname_app/l10n/generated/app_localizations.dart';
import 'package:kaname_app/server/data/server_address.dart';
import 'package:kaname_app/server/logic/server_status.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

const _take = 'Take holder to this device';
const _return = 'Park device and return holder';

void main() {
  testWidgets(
    'Settings offers a new Take after the original take did not go through',
    (tester) async {
      final desktop = _RecoveringDesktop(AccountNotice.takeNotAccepted);
      await http.runWithClient(() async {
        await _openSettings(tester, desktop);
        final before = _buttonLabels(tester);

        await tester.tap(find.text(_take));
        await tester.pumpAndSettle();

        expect(desktop.takes, 1);
        expect(
          find.text(
            'The take did not go through. You can start a new take if the character is free.',
          ),
          findsOneWidget,
        );
        expect(_liveRegionHolds('did not go through'), isTrue);
        expect(find.text(_take), findsOneWidget);
        // The rolled-back row is gone, so only existing controls remain.
        expect(find.text(_return), findsNothing);
        expect(before.containsAll(_buttonLabels(tester)), isTrue);
      }, _viewerClient);
    },
    skip: !hasDesktopHolder,
  );

  testWidgets('Settings explains that retry may not settle a pending take', (
    tester,
  ) async {
    final desktop = _RecoveringDesktop(AccountNotice.takeUnconfirmed);
    await http.runWithClient(() async {
      await _openSettings(tester, desktop);
      final before = _buttonLabels(tester);

      await tester.tap(find.text(_take));
      await tester.pumpAndSettle();

      expect(desktop.takes, 1);
      expect(
        find.text(
          'The take is still unconfirmed. Another retry may not settle it.',
        ),
        findsOneWidget,
      );
      expect(_liveRegionHolds('still unconfirmed'), isTrue);
      expect(
        find.text('Handoff is pending. Resume on the original device.'),
        findsOneWidget,
      );
      // The pending local take keeps its controls and gains no new one.
      expect(find.text(_return), findsOneWidget);
      expect(_buttonLabels(tester), before);
    }, _viewerClient);
  }, skip: !hasDesktopHolder);
}

/// Serves sign-in and viewer refreshes for a server-held pilot.
http.Client _viewerClient() {
  const pilot = {
    'characterId': '410',
    'characterName': 'Pilot',
    'memberId': '1',
    'admin': false,
    'holder': 'serverHeld',
  };
  final client = MockClient((request) async {
    if (request.url.pathSegments case [..., 'memberRoster', 'page']) {
      return http.Response('{"status":"ok","characters":[]}', 200);
    }
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
        return http.Response(jsonEncode({...pilot, 'session': 'b' * 43}), 200);
      case 'viewer':
        return http.Response(jsonEncode(pilot), 200);
      default:
        fail('unexpected request');
    }
  });
  addTearDown(client.close);
  return client;
}

/// Opens Settings and signs in, leaving the Take control visible.
Future<void> _openSettings(
  WidgetTester tester,
  _RecoveringDesktop desktop,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        serverTargetProvider.overrideWithValue(
          ConfiguredServer(Uri.parse('https://kaname.test/api/')),
        ),
        desktopAccountProvider.overrideWith((_) async => desktop),
      ],
      child: MaterialApp(
        theme: EmberTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: EsiAccountSection()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sign in to server'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Finish sign-in'));
  await tester.pumpAndSettle();
  expect(find.text(_take), findsOneWidget);
}

Set<String> _buttonLabels(WidgetTester tester) => {
  for (final button in tester.widgetList<ButtonStyleButton>(
    find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  ))
    if (button.child case Text(:final data?)) data,
};

bool _liveRegionHolds(String text) => find
    .ancestor(
      of: find.textContaining(text),
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
    )
    .evaluate()
    .isNotEmpty;

/// A desktop account whose take returns one fixed recovery notice.
final class _RecoveringDesktop implements DesktopAccount {
  _RecoveringDesktop(this._notice);

  final AccountNotice _notice;
  var takes = 0;

  /// The local take the user retries, left by an earlier attempt.
  AccountPilot? _pilot = const AccountPilot(
    characterId: '410',
    name: 'Pilot',
    holder: 'taking',
  );

  @override
  String? get clientId => 'fixture-native';

  @override
  AccountPilot? get pilot => _pilot;

  @override
  bool permitsServerGrant(String characterId) => true;

  @override
  bool ownsReservationFor(String origin, String characterId) => false;

  @override
  Future<AccountNotice> take(HolderRemote remote) async {
    takes++;
    // A committed rollback removes the temporary row; a pending take keeps
    // it.
    if (_notice == AccountNotice.takeNotAccepted) _pilot = null;
    return _notice;
  }

  @override
  Future<AccountNotice> returnTo(HolderRemote remote) =>
      fail('Return must not run');

  @override
  AccountNotice configure(String clientId) => fail('unexpected configure');

  @override
  Future<AccountNotice> identify() => fail('unexpected identify');

  @override
  Future<AccountNotice> authorizeSkills() => fail('unexpected authorize');

  @override
  Future<AccountNotice> disableSkills() => fail('unexpected disable');

  @override
  Future<SkillsRead> skills() => fail('unexpected skills read');

  @override
  void cancel() {}

  @override
  Future<void> close() async {}
}
