@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/l10n/generated/app_localizations.dart';
import 'package:kaname_app/server/data/server_address.dart';
import 'package:kaname_app/shell/ui/shell_icon_button.dart';
import 'package:kaname_app/shell/ui/shell_keys.dart';
import 'package:kaname_app/static_data/data/bundle_announcements.dart';
import 'package:kaname_app/static_data/data/bundle_store.dart';
import 'package:kaname_app/static_data/logic/quick_search.dart';
import 'package:kaname_app/static_data/logic/static_data_state.dart';
import 'package:kaname_app/static_data/ui/quick_search_keys.dart';
import 'package:kaname_app/static_data/ui/quick_search_panel.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';

import '../server/fake_server_health.dart';
import '../support/pump_shell.dart';
import 'support/bundle_fixture.dart';
import 'support/static_data_fakes.dart';

const _wide = Size(1280, 800);
const _narrow = Size(390, 800);

final _server = ConfiguredServer(Uri.parse('http://secret-host.example:8080/'));

/// What a search runs against: the fakes behind the static data.
final class Rig {
  Rig({BundleCopy? kept, this.target = const NoServer()})
    : store = FakeBundleStore(kept: kept);

  final ServerTarget target;
  final FakeBundleStore store;
  final FakeAnnouncementSource source = FakeAnnouncementSource();
  final FakeBundleDownloader downloader = FakeBundleDownloader();
  final FakeServerHealth health = FakeServerHealth();

  Future<void> pump(WidgetTester tester, {Size size = _wide}) async {
    await pumpShell(
      tester,
      size: size,
      target: target,
      health: health,
      bundleStore: store,
      bundleSource: source,
      bundleDownloader: downloader,
    );
    // The status bar's health check ends, so no timeout timer stays pending.
    if (health.calls > 0) health.fail('down');
    await tester.pumpAndSettle();
  }
}

/// Types [text] into the focused search field and waits out the debounce.
Future<void> typeQuery(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(QuickSearchKeys.field), text);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pumpAndSettle();
}

Finder inPanel(Finder finder) =>
    find.descendant(of: find.byKey(QuickSearchKeys.panel), matching: finder);

/// Whether the search field's editable text holds primary focus.
bool fieldHasFocus(WidgetTester tester) => tester
    .widget<EditableText>(find.byType(EditableText))
    .focusNode
    .hasPrimaryFocus;

void main() {
  final copyN = fixtureBundle(
    100,
    extraTypes: {600: 'Rifter Navy Issue', 601: 'Drifter'},
  );

  testWidgets('offline search finds Jita and sends no request', (tester) async {
    final rig = Rig(kept: copyN, target: _server);
    await rig.pump(tester);
    // The kept bundle is the one the server announces: nothing to download.
    rig.source.current.emit(
      BundleAnnounced(
        epoch: 'E1',
        revision: 1,
        bundle: copyN.identity,
        size: copyN.bytes.length,
        formatMajor: bundleFormatMajor,
      ),
    );
    await tester.pumpAndSettle();

    await typeQuery(tester, 'Jita');

    expect(inPanel(find.text('Jita')), findsOneWidget);
    expect(inPanel(find.text('The Forge')), findsOneWidget);
    expect(inPanel(find.text('Solar system')), findsOneWidget);
    expect(rig.downloader.started, isEmpty);
    expect(rig.source.subscribes, 1);
  });

  testWidgets('results wait 150 ms after the last keystroke', (tester) async {
    await (Rig(kept: copyN)).pump(tester);

    await tester.enterText(find.byKey(QuickSearchKeys.field), 'jit');
    await tester.pump(const Duration(milliseconds: 149));
    expect(find.byKey(QuickSearchKeys.panel), findsNothing);
    await tester.enterText(find.byKey(QuickSearchKeys.field), 'jita');
    await tester.pump(const Duration(milliseconds: 149));
    expect(find.byKey(QuickSearchKeys.panel), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(inPanel(find.text('Jita')), findsOneWidget);
  });

  testWidgets('no bundle shows localised reason without exception text', (
    tester,
  ) async {
    final rig = Rig(target: _server);
    await rig.pump(tester);
    rig.source.current.fail(
      'SocketException: refused by secret-host.example:8080',
    );
    await tester.pumpAndSettle();

    await typeQuery(tester, 'jita');

    expect(find.text('Static data not loaded yet'), findsOneWidget);
    expect(find.text('The server could not be reached.'), findsOneWidget);
    expect(find.textContaining('SocketException'), findsNothing);
    expect(find.textContaining('secret-host'), findsNothing);
    expect(find.textContaining('8080'), findsNothing);
    // The message is the whole panel: no empty result list.
    expect(find.text('No matches'), findsNothing);
    expect(find.byKey(QuickSearchKeys.result(0)), findsNothing);
  });

  testWidgets('every no-bundle reason has its own localised message', (
    tester,
  ) async {
    const reasons = <NoBundleReason, String>{
      Starting(): 'Starting up. Static data will load in a moment.',
      Downloading(): 'Static data is downloading.',
      NoServerConfigured(): 'No server is configured.',
      ServerUnreachable(): 'The server could not be reached.',
      ServerHasNoBundle(): 'The server has no static data yet.',
      BundleRefusedReason(): 'The downloaded static data could not be used.',
      AppUpdateNeededReason(): 'Update the app to load the latest static data.',
    };
    for (final MapEntry(:key, :value) in reasons.entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: EmberTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: QuickSearchPanel(state: SearchNotLoaded(key))),
        ),
      );
      expect(find.text('Static data not loaded yet'), findsOneWidget);
      expect(find.text(value), findsOneWidget, reason: '$key');
    }
  });

  testWidgets('app update notice shows while search still returns results', (
    tester,
  ) async {
    final rig = Rig(kept: copyN, target: _server);
    await rig.pump(tester);
    rig.source.current.emit(
      BundleAnnounced(
        epoch: 'E1',
        revision: 1,
        bundle: BundleIdentity(build: 101, sha256: 'ab' * 32),
        size: 10,
        formatMajor: bundleFormatMajor + 1,
      ),
    );
    await tester.pumpAndSettle();

    await typeQuery(tester, 'jita');

    expect(inPanel(find.text('Jita')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(QuickSearchKeys.notice),
        matching: find.textContaining('app'),
      ),
      findsOneWidget,
    );
    expect(rig.downloader.started, isEmpty);
  });

  testWidgets('keyboard search lists Rifter and arrows move', (tester) async {
    final semantics = tester.ensureSemantics();
    await Rig(kept: copyN).pump(tester);

    // From the inspector toggle, Shift+Tab reaches the search field.
    tester
        .widget<ShellIconButton>(find.byKey(ShellKeys.inspectorToggle))
        .focusNode!
        .requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(fieldHasFocus(tester), isTrue);
    tester.testTextInput.enterText('rifter');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(inPanel(find.text('Rifter')), findsOneWidget);
    expect(inPanel(find.text('Frigate')), findsWidgets);
    bool selected(int index) =>
        isSelectedNode(tester, find.byKey(QuickSearchKeys.result(index)));
    expect(selected(0), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect([selected(0), selected(1)], [true, false]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect([selected(0), selected(1)], [false, true]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect([selected(0), selected(1)], [true, false]);
    // Focus stays in the field while the arrows move.
    expect(fieldHasFocus(tester), isTrue);
    semantics.dispose();
  });

  testWidgets('narrow window opens full-width search, Escape returns focus', (
    tester,
  ) async {
    await Rig(kept: copyN).pump(tester, size: _narrow);

    expect(find.byKey(QuickSearchKeys.field), findsNothing);
    await tester.tap(find.byKey(QuickSearchKeys.openButton));
    await tester.pumpAndSettle();

    expect(find.byKey(QuickSearchKeys.field), findsOneWidget);
    expect(fieldHasFocus(tester), isTrue);
    expect(
      tester.getSize(find.byKey(QuickSearchKeys.field)).width,
      greaterThan(300),
    );
    await typeQuery(tester, 'jita');
    expect(tester.getSize(find.byKey(QuickSearchKeys.panel)).width, 390);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(QuickSearchKeys.field), findsNothing);
    expect(find.byKey(QuickSearchKeys.panel), findsNothing);
    final button = find.byKey(QuickSearchKeys.openButton);
    expect(button, findsOneWidget);
    expect(
      tester.widget<ShellIconButton>(button).focusNode!.hasPrimaryFocus,
      isTrue,
    );
  });

  testWidgets('empty or blank query shows no list', (tester) async {
    await Rig(kept: copyN).pump(tester);

    expect(find.byKey(QuickSearchKeys.panel), findsNothing);
    await typeQuery(tester, '   ');
    expect(find.byKey(QuickSearchKeys.panel), findsNothing);
    await typeQuery(tester, 'jita');
    expect(find.byKey(QuickSearchKeys.panel), findsOneWidget);
    await tester.enterText(find.byKey(QuickSearchKeys.field), '  ');
    await tester.pump();
    expect(find.byKey(QuickSearchKeys.panel), findsNothing);
  });

  testWidgets('back closes the narrow search and returns focus', (
    tester,
  ) async {
    await Rig(kept: copyN).pump(tester, size: _narrow);
    await tester.tap(find.byKey(QuickSearchKeys.openButton));
    await tester.pumpAndSettle();
    await typeQuery(tester, 'jita');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(QuickSearchKeys.field), findsNothing);
    expect(find.byKey(QuickSearchKeys.panel), findsNothing);
    expect(
      tester
          .widget<ShellIconButton>(find.byKey(QuickSearchKeys.openButton))
          .focusNode!
          .hasPrimaryFocus,
      isTrue,
    );
  });

  testWidgets('Escape clears the inline query and keeps focus', (tester) async {
    await Rig(kept: copyN).pump(tester);
    await typeQuery(tester, 'jita');
    expect(find.byKey(QuickSearchKeys.panel), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(QuickSearchKeys.panel), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(fieldHasFocus(tester), isTrue);
  });

  testWidgets('field, open button and results have screen-reader names', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await Rig(kept: copyN).pump(tester);
    expect(find.bySemanticsLabel('Search'), findsOneWidget);
    await typeQuery(tester, 'jita');
    expect(find.bySemanticsLabel('Search results'), findsOneWidget);
    expect(find.bySemanticsLabel('1 result'), findsOneWidget);

    await Rig(kept: copyN).pump(tester, size: _narrow);
    expect(find.bySemanticsLabel('Open search'), findsOneWidget);
    await tester.tap(find.byKey(QuickSearchKeys.openButton));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Close search'), findsOneWidget);
    semantics.dispose();
  });
}
