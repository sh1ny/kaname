import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/shell/logic/inspector_notifier.dart';
import 'package:kaname_app/shell/ui/inspector_dock.dart';
import 'package:kaname_app/shell/ui/inspector_panel.dart';
import 'package:kaname_app/shell/ui/inspector_sheet.dart';
import 'package:kaname_app/shell/ui/shell_icon_button.dart';
import 'package:kaname_app/shell/ui/shell_keys.dart';
import 'package:kaname_app/shell/ui/shell_main.dart';

import '../support/pump_shell.dart';
import '../support/state_probe.dart';

FocusNode _nodeOf(WidgetTester tester, Key key) =>
    tester.widget<ShellIconButton>(find.byKey(key)).focusNode!;

double _mainWidth(WidgetTester tester) =>
    tester.getSize(find.byType(ShellMain)).width;

void main() {
  testWidgets('medium width opens the inspector as a sheet over a scrim', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(900, 700));
    final before = _mainWidth(tester);
    expect(find.byType(InspectorSheet), findsNothing);

    await tester.tap(find.byKey(ShellKeys.inspectorToggle));
    await tester.pumpAndSettle();

    expect(find.byType(InspectorSheet), findsOneWidget);
    expect(find.byKey(ShellKeys.inspectorScrim), findsOneWidget);
    expect(find.byType(InspectorDock), findsNothing);
    expect(tester.getSize(find.byType(InspectorPanel)).width, 352);
    expect(
      tester.getTopRight(find.byType(InspectorPanel)).dx,
      900,
      reason: 'the sheet comes from the right',
    );
    expect(_mainWidth(tester), before);
  });

  testWidgets('tapping the scrim closes the sheet and keeps main', (
    tester,
  ) async {
    await pumpShell(
      tester,
      size: const Size(900, 700),
      registry: probeRegistry(),
    );
    await tester.tap(find.byKey(const Key('probe.tap')));
    await tester.pump();
    final probe = tester.state<StateProbeState>(find.byType(StateProbe));
    await tester.tap(find.byKey(ShellKeys.inspectorToggle));
    await tester.pumpAndSettle();
    expect(find.byType(InspectorSheet), findsOneWidget);

    final scrim = find.byKey(ShellKeys.inspectorScrim);
    await tester.tapAt(tester.getTopLeft(scrim) + const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(InspectorSheet), findsNothing);
    expect(find.byKey(ShellKeys.inspectorScrim), findsNothing);
    expect(tester.state<StateProbeState>(find.byType(StateProbe)), same(probe));
    expect(find.text('probe 1'), findsOneWidget);
  });

  testWidgets('closing returns focus to the toggle and keeps main state', (
    tester,
  ) async {
    await pumpShell(
      tester,
      size: const Size(1440, 900),
      registry: probeRegistry(),
    );
    await tester.tap(find.byKey(const Key('probe.tap')));
    await tester.pump();
    final probe = tester.state<StateProbeState>(find.byType(StateProbe));
    final toggle = _nodeOf(tester, ShellKeys.inspectorToggle);

    toggle.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(InspectorPanel), findsOneWidget);
    final close = _nodeOf(tester, ShellKeys.inspectorClose);
    expect(close.hasPrimaryFocus, isTrue, reason: 'focus moves into the panel');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(InspectorDock)).width, 0);
    expect(toggle.hasPrimaryFocus, isTrue);
    expect(tester.state<StateProbeState>(find.byType(StateProbe)), same(probe));
    expect(find.text('probe 1'), findsOneWidget);
  });

  testWidgets('closing with the opener gone focuses main without error', (
    tester,
  ) async {
    final harness = await pumpShell(tester, size: const Size(1440, 900));
    final railIcon = find.descendant(
      of: find.byKey(ShellKeys.rail('home')),
      matching: find.byType(Icon),
    );
    Focus.of(tester.element(railIcon)).requestFocus();
    await tester.pump();

    harness.container.read(inspectorProvider.notifier).open();
    await tester.pumpAndSettle();

    // The rail, the opener, leaves the tree at this width.
    setWindowSize(tester, const Size(390, 800));
    await tester.pumpAndSettle();
    expect(find.byKey(ShellKeys.rail('home')), findsNothing);

    await tester.tap(find.byKey(ShellKeys.inspectorClose));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final main = tester.widget<Focus>(find.byKey(ShellKeys.mainFocus));
    expect(main.focusNode!.hasPrimaryFocus, isTrue);
    expect(harness.container.read(inspectorProvider), isFalse);
  });

  testWidgets('inspector reaches 352 at 200ms, not before', (tester) async {
    await pumpShell(tester, size: const Size(1440, 900));
    double width() => tester.getSize(find.byType(InspectorDock)).width;
    expect(width(), 0);

    await tester.tap(find.byKey(ShellKeys.inspectorToggle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(width(), greaterThan(0));
    expect(width(), lessThan(352));

    await tester.pump(const Duration(milliseconds: 100));
    expect(width(), 352);
  });

  testWidgets('disableAnimations opens the inspector on the next frame', (
    tester,
  ) async {
    await pumpShell(
      tester,
      size: const Size(1440, 900),
      disableAnimations: true,
    );

    await tester.tap(find.byKey(ShellKeys.inspectorToggle));
    await tester.pump();

    expect(tester.getSize(find.byType(InspectorDock)).width, 352);
  });
}
