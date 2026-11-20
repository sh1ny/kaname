@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/l10n/generated/app_localizations.dart';
import 'package:kaname_app/server/data/server_address.dart';
import 'package:kaname_app/shell/data/browser_history.dart';
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
import '../support/fake_browser_history.dart';
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

  Future<ShellHarness> pump(
    WidgetTester tester, {
    Size size = _wide,
    String location = '/home',
    BrowserHistory? browserHistory,
  }) async {
    final harness = await pumpShell(
      tester,
      location: location,
      browserHistory: browserHistory,
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
    return harness;
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

/// Lets the shell report no overflow in a window too short for it, the
/// search panel being the subject; an overflow in the panel still fails.
void ignoreShellOverflow() {
  final reported = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString();
    if (text.contains('overflowed') &&
        !text.contains('quick_search_panel.dart')) {
      return;
    }
    reported?.call(details);
  };
  addTearDown(() => FlutterError.onError = reported);
}

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

  testWidgets('a swap keeps the shown results until the next keystroke', (
    tester,
  ) async {
    final copyN1 = fixtureBundle(
      101,
      extraTypes: {600: 'Rifter Navy Issue', 601: 'Drifter', 602: 'Rifter Two'},
    );
    final rig = Rig(kept: copyN, target: _server);
    await rig.pump(tester);
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
    await typeQuery(tester, 'rifter');
    expect(inPanel(find.text('Rifter Navy Issue')), findsOneWidget);
    expect(inPanel(find.text('Rifter Two')), findsNothing);

    // Build N+1 is announced, downloaded and swapped in while the results
    // of build N are shown.
    rig.source.current.emit(
      BundleAnnounced(
        epoch: 'E1',
        revision: 2,
        bundle: copyN1.identity,
        size: copyN1.bytes.length,
        formatMajor: bundleFormatMajor,
      ),
    );
    await tester.pumpAndSettle();
    rig.downloader.last.complete(copyN1.bytes);
    await tester.pumpAndSettle();

    expect(inPanel(find.text('Rifter Navy Issue')), findsOneWidget);
    expect(inPanel(find.text('Rifter Two')), findsNothing);

    await typeQuery(tester, 'rifter ');
    expect(inPanel(find.text('Rifter Two')), findsOneWidget);
  });

  testWidgets('crossing the breakpoint and back clears the query and its '
      'results together', (tester) async {
    await Rig(kept: copyN).pump(tester, size: _narrow);
    await tester.tap(find.byKey(QuickSearchKeys.openButton));
    await tester.pumpAndSettle();
    await typeQuery(tester, 'rifter');
    expect(inPanel(find.text('Rifter')), findsOneWidget);

    setWindowSize(tester, _wide);
    await tester.pumpAndSettle();
    setWindowSize(tester, _narrow);
    await tester.pumpAndSettle();

    // The narrow search is closed, as every query was cleared with the
    // field that held it.
    expect(find.byKey(QuickSearchKeys.openButton), findsOneWidget);
    expect(find.byKey(QuickSearchKeys.panel), findsNothing);
    await tester.tap(find.byKey(QuickSearchKeys.openButton));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      isEmpty,
    );
    expect(find.byKey(QuickSearchKeys.panel), findsNothing);
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

  testWidgets('arrows scroll the highlighted row fully into view', (
    tester,
  ) async {
    final many = fixtureBundle(
      100,
      extraTypes: {for (var i = 0; i < 30; i++) 700 + i: 'Rifter $i'},
    );
    await Rig(kept: many).pump(tester, size: _narrow);
    await tester.tap(find.byKey(QuickSearchKeys.openButton));
    await tester.pumpAndSettle();
    await typeQuery(tester, 'rifter');

    for (var i = 0; i < 20; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    final panel = tester.getRect(find.byKey(QuickSearchKeys.panel));
    final row = tester.getRect(find.byKey(QuickSearchKeys.result(19)));
    expect(row.bottom, lessThanOrEqualTo(panel.bottom), reason: 'not clipped');

    for (var i = 0; i < 19; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    final first = tester.getRect(find.byKey(QuickSearchKeys.result(0)));
    expect(first.top, greaterThanOrEqualTo(panel.top));
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

  testWidgets('the narrow search results stay above the on-screen keyboard '
      'in a short window', (tester) async {
    const short = Size(800, 480);
    const keyboard = 220.0;
    final many = fixtureBundle(
      100,
      extraTypes: {for (var i = 0; i < 30; i++) 700 + i: 'Rifter $i'},
    );
    await Rig(kept: many).pump(tester, size: short);
    tester.view.viewInsets = FakeViewPadding(
      bottom: keyboard * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.tap(find.byKey(QuickSearchKeys.openButton));
    await tester.pumpAndSettle();
    await typeQuery(tester, 'rifter');
    expect(find.byKey(QuickSearchKeys.result(0)), findsOneWidget);

    final panel = tester.getRect(find.byKey(QuickSearchKeys.panel));
    expect(
      panel.bottom,
      lessThanOrEqualTo(short.height - keyboard),
      reason:
          'every result can be scrolled into the part the keyboard '
          'leaves',
    );
  });

  testWidgets('Escape closes the narrow search with focus on the bottom '
      'navigation too, and returns focus to the button', (tester) async {
    await Rig(kept: copyN).pump(tester, size: _narrow);
    await tester.tap(find.byKey(QuickSearchKeys.openButton));
    await tester.pumpAndSettle();
    // Focus moves from the search to a bottom-navigation item.
    final item = tester.element(
      find
          .descendant(
            of: find
                .descendant(
                  of: find.byKey(ShellKeys.bar('settings')),
                  matching: find.byType(Focus),
                )
                .last,
            matching: find.byWidgetPredicate((_) => true),
          )
          .first,
    );
    Focus.of(item, createDependency: false).requestFocus();
    await tester.pump();
    expect(fieldHasFocus(tester), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(QuickSearchKeys.field), findsNothing);
    expect(
      tester
          .widget<ShellIconButton>(find.byKey(QuickSearchKeys.openButton))
          .focusNode!
          .hasPrimaryFocus,
      isTrue,
    );
  });

  testWidgets('with less than three rows of room above the keyboard, the '
      'last result still scrolls fully into view', (tester) async {
    const short = Size(800, 375);
    const keyboard = 260.0;
    ignoreShellOverflow();
    final many = fixtureBundle(
      100,
      extraTypes: {for (var i = 0; i < 30; i++) 700 + i: 'Rifter $i'},
    );
    await Rig(kept: many).pump(tester, size: short);
    tester.view.viewInsets = FakeViewPadding(
      bottom: keyboard * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.tap(find.byKey(QuickSearchKeys.openButton));
    await tester.pumpAndSettle();
    await typeQuery(tester, 'rifter');

    for (var i = 0; i < 31; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final panel = tester.getRect(find.byKey(QuickSearchKeys.panel));
    expect(panel.bottom, lessThanOrEqualTo(short.height - keyboard));
    final last = find.byKey(QuickSearchKeys.result(30));
    expect(last, findsOneWidget);
    expect(tester.getRect(last).bottom, lessThanOrEqualTo(panel.bottom));
  });

  testWidgets('with little room above the keyboard, the no-bundle reason '
      'scrolls into view and nothing in the panel overflows', (tester) async {
    const short = Size(800, 375);
    const keyboard = 260.0;
    ignoreShellOverflow();
    await Rig().pump(tester, size: short);
    tester.view.viewInsets = FakeViewPadding(
      bottom: keyboard * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.tap(find.byKey(QuickSearchKeys.openButton));
    await tester.pumpAndSettle();
    await typeQuery(tester, 'jita');

    final reason = inPanel(find.text('No server is configured.'));
    expect(reason, findsOneWidget);
    await tester.ensureVisible(reason);
    await tester.pumpAndSettle();
    final panel = tester.getRect(find.byKey(QuickSearchKeys.panel));
    expect(panel.bottom, lessThanOrEqualTo(short.height - keyboard));
    expect(tester.getRect(reason).bottom, lessThanOrEqualTo(panel.bottom));
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

  testWidgets('back closes the narrow search over a nested page, returns '
      'focus and leaves the page in place', (tester) async {
    final harness = await Rig(kept: copyN)
        .pump(tester, size: _narrow, location: '/settings/licences');
    String path() => harness.router.routeInformationProvider.value.uri.path;
    expect(path(), '/settings/licences');
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
    expect(path(), '/settings/licences', reason: 'the page stays');
    expect(
      harness.router.routeInformationProvider.value.uri.toString(),
      '/settings/licences',
      reason: 'the search marker is gone',
    );

    // With search closed, the next Back pops the page as usual.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(path(), '/settings');
  });

  group('in a browser', () {
    late FakeBrowserHistory history;
    late ShellHarness harness;
    String location() =>
        harness.router.routeInformationProvider.value.uri.toString();
    bool buttonFocused(WidgetTester tester) => tester
        .widget<ShellIconButton>(find.byKey(QuickSearchKeys.openButton))
        .focusNode!
        .hasPrimaryFocus;

    // Settings, then Licences over it, then the narrow search opened.
    Future<void> openOverLicences(WidgetTester tester) async {
      history = FakeBrowserHistory(tester);
      harness = await Rig(kept: copyN).pump(
        tester,
        size: _narrow,
        location: '/settings',
        browserHistory: history,
      );
      harness.router.go('/settings/licences');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(QuickSearchKeys.openButton));
      await tester.pumpAndSettle();
      await typeQuery(tester, 'jita');
      expect(history.entries, [
        '/settings',
        '/settings/licences',
        '/settings/licences?search',
      ], reason: 'opening the search adds its own history entry');
      expect(history.currentTagged, isTrue, reason: 'a reload keeps it');
    }

    testWidgets('the first Back closes the narrow search and returns focus, '
        'the second leaves the page', (tester) async {
      await openOverLicences(tester);

      await history.pressBack();
      await tester.pumpAndSettle();

      expect(find.byKey(QuickSearchKeys.field), findsNothing);
      expect(find.byKey(QuickSearchKeys.panel), findsNothing);
      expect(buttonFocused(tester), isTrue);
      expect(location(), '/settings/licences', reason: 'the page stays');
      expect(find.byType(LicensePage), findsOneWidget);

      await history.pressBack();
      await tester.pumpAndSettle();
      expect(location(), '/settings');
    });

    testWidgets('Escape steps back over the search entry, so the next Back '
        'leaves the page', (tester) async {
      await openOverLicences(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(QuickSearchKeys.field), findsNothing);
      expect(buttonFocused(tester), isTrue);
      expect(history.backCalls, 1);
      expect(history.current, '/settings/licences');
      expect(location(), '/settings/licences');

      await history.pressBack();
      await tester.pumpAndSettle();
      expect(location(), '/settings', reason: 'no dead search entry is left');
    });

    testWidgets('after Back and Forward reopen the search, closing it steps '
        'back, so the next Back leaves the page', (tester) async {
      await openOverLicences(tester);
      await history.pressBack();
      await tester.pumpAndSettle();
      await history.pressForward();
      await tester.pumpAndSettle();
      expect(find.byKey(QuickSearchKeys.field), findsOneWidget);

      await tester.tap(find.byKey(QuickSearchKeys.closeButton));
      await tester.pumpAndSettle();

      expect(find.byKey(QuickSearchKeys.field), findsNothing);
      expect(history.backCalls, 1);
      expect(location(), '/settings/licences');
      await history.pressBack();
      await tester.pumpAndSettle();
      expect(location(), '/settings', reason: 'no repeated page entry');
    });

    testWidgets('widening the window with the search open steps back over '
        'its entry', (tester) async {
      await openOverLicences(tester);

      setWindowSize(tester, _wide);
      await tester.pumpAndSettle();

      expect(history.backCalls, 1);
      expect(location(), '/settings/licences');
      await history.pressBack();
      await tester.pumpAndSettle();
      expect(location(), '/settings', reason: 'no repeated page entry');
    });

    testWidgets('a branch switched away from with the search open comes '
        'back unmarked, its entry right after the other page', (tester) async {
      await openOverLicences(tester);

      await tester.tap(find.byKey(ShellKeys.bar('home')));
      await tester.pumpAndSettle();
      expect(find.byKey(QuickSearchKeys.field), findsNothing);
      await tester.tap(find.byKey(ShellKeys.bar('settings')));
      await tester.pumpAndSettle();

      expect(location(), '/settings/licences', reason: 'the branch is kept');
      expect(find.byKey(QuickSearchKeys.field), findsNothing);
      expect(history.current, '/settings/licences');
      expect(history.backCalls, 0);
      await history.pressBack();
      await tester.pumpAndSettle();
      expect(location(), '/home');
    });

    testWidgets('returning to a branch whose search was open, from a branch '
        'whose search is open, closes the search on the unmarked page', (
      tester,
    ) async {
      await openOverLicences(tester);
      await tester.tap(find.byKey(ShellKeys.bar('home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(QuickSearchKeys.openButton));
      await tester.pumpAndSettle();
      expect(location(), '/home?search');

      await tester.tap(find.byKey(ShellKeys.bar('settings')));
      await tester.pumpAndSettle();

      expect(find.byKey(QuickSearchKeys.field), findsNothing);
      expect(location(), '/settings/licences');
      expect(history.current, '/settings/licences');
      expect(history.backCalls, 0);
    });

    testWidgets('a marked page loaded on a wide window is unmarked, and '
        'narrowing then opens no search', (tester) async {
      history = FakeBrowserHistory(tester);
      harness = await Rig(kept: copyN)
          .pump(tester, location: '/settings?search', browserHistory: history);
      expect(history.entries, ['/settings']);

      setWindowSize(tester, _narrow);
      await tester.pumpAndSettle();

      expect(find.byKey(QuickSearchKeys.field), findsNothing);
      expect(history.backCalls, 0);
      expect(location(), '/settings');
    });

    testWidgets('a shared link with the marker opens the page unmarked with '
        'the search closed, and adds no history entry', (tester) async {
      history = FakeBrowserHistory(tester);
      harness = await Rig(kept: copyN).pump(
        tester,
        size: _narrow,
        location: '/settings?search',
        browserHistory: history,
      );

      expect(find.byKey(QuickSearchKeys.field), findsNothing);
      expect(history.entries, ['/settings']);
      expect(history.backCalls, 0);
      expect(location(), '/settings');
    });

    testWidgets('a reloaded page with the search open keeps its history, and '
        'closing the search steps back to the same page', (tester) async {
      history = FakeBrowserHistory(
        tester,
        restored: ['/home', '/settings', '/settings?search'],
        restoredTagged: true,
      );
      harness = await Rig(kept: copyN).pump(
        tester,
        size: _narrow,
        location: '/settings?search',
        browserHistory: history,
      );
      expect(find.byKey(QuickSearchKeys.field), findsOneWidget);
      expect(history.entries, ['/home', '/settings', '/settings?search']);
      expect(
        history.currentTagged,
        isTrue,
        reason:
            'the router\'s first report replaced the entry, so the tag '
            'is put back for the next reload',
      );

      await tester.tap(find.byKey(QuickSearchKeys.closeButton));
      await tester.pumpAndSettle();

      expect(find.byKey(QuickSearchKeys.field), findsNothing);
      expect(history.backCalls, 1);
      expect(location(), '/settings');
      await history.pressBack();
      await tester.pumpAndSettle();
      expect(location(), '/home', reason: 'no repeated page entry');
    });

    testWidgets('a reload of a marked entry the bar did not tag opens the '
        'page unmarked with the search closed', (tester) async {
      history = FakeBrowserHistory(
        tester,
        restored: ['/home', '/settings?search'],
      );
      harness = await Rig(kept: copyN).pump(
        tester,
        size: _narrow,
        location: '/settings?search',
        browserHistory: history,
      );

      expect(find.byKey(QuickSearchKeys.field), findsNothing);
      expect(history.entries, ['/home', '/settings']);
      await history.pressBack();
      await tester.pumpAndSettle();
      expect(location(), '/home');
    });

    testWidgets('a reloaded page with the search open on a wide window steps '
        'back over its entry', (tester) async {
      history = FakeBrowserHistory(
        tester,
        restored: ['/home', '/settings', '/settings?search'],
        restoredTagged: true,
      );
      harness = await Rig(kept: copyN)
          .pump(tester, location: '/settings?search', browserHistory: history);

      expect(history.backCalls, 1);
      expect(location(), '/settings');
      expect(history.current, '/settings');
    });
  });

  testWidgets('Escape on the close button closes the narrow search and '
      'returns focus', (tester) async {
    await Rig(kept: copyN).pump(tester, size: _narrow);
    await tester.tap(find.byKey(QuickSearchKeys.openButton));
    await tester.pumpAndSettle();
    await typeQuery(tester, 'jita');
    // Focus leaves the field for the close button.
    Focus.of(
      tester.element(
        find.descendant(
          of: find.byKey(QuickSearchKeys.closeButton),
          matching: find.byType(Icon),
        ),
      ),
    ).requestFocus();
    await tester.pumpAndSettle();
    expect(find.byKey(QuickSearchKeys.field), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
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
