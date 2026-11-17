import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/shell/logic/inspector_notifier.dart';
import 'package:kaname_app/shell/ui/bottom_bar.dart';
import 'package:kaname_app/shell/ui/drawer.dart';
import 'package:kaname_app/shell/ui/empty_state.dart';
import 'package:kaname_app/shell/ui/inspector_dock.dart';
import 'package:kaname_app/shell/ui/inspector_sheet.dart';
import 'package:kaname_app/shell/ui/rail.dart';
import 'package:kaname_app/shell/ui/shell_keys.dart';
import 'package:kaname_app/shell/ui/shell_main.dart';
import 'package:kaname_app/shell/ui/sidebar.dart';
import 'package:kaname_app/shell/ui/status_bar.dart';
import 'package:kaname_app/shell/ui/top_bar.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../support/pump_shell.dart';
import '../support/state_probe.dart';

void main() {
  testWidgets('wide window shows top bar, rail, sidebar, main and status bar', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(1440, 900));

    expect(find.byType(ShellTopBar), findsOneWidget);
    expect(find.byType(ShellRail), findsOneWidget);
    expect(find.byType(ShellSidebar), findsOneWidget);
    expect(find.byType(ShellMain), findsOneWidget);
    expect(find.byType(ShellStatusBar), findsOneWidget);
    expect(find.byType(ShellBottomBar), findsNothing);
    expect(find.byType(ShellDrawer), findsNothing);
    expect(find.byType(InspectorDock), findsOneWidget);
    expect(tester.getSize(find.byType(InspectorDock)).width, 0);

    expect(tester.getSize(find.byType(ShellTopBar)).height, EmberSize.topBar);
    expect(
      tester.getSize(find.byType(ShellStatusBar)).height,
      EmberSize.statusBar,
    );
    expect(tester.getSize(find.byType(ShellRail)).width, EmberSize.rail);
    expect(tester.getSize(find.byType(ShellSidebar)).width, EmberSize.sidebar);
    expect(tester.getSize(find.byType(ShellTopBar)).width, 1440);
    expect(tester.getSize(find.byType(ShellStatusBar)).width, 1440);
  });

  testWidgets(
    'narrowing to 1000 turns the open inspector into a sheet and keeps main '
    'state',
    (tester) async {
      final harness = await pumpShell(
        tester,
        size: const Size(1440, 900),
        registry: probeRegistry(),
      );
      await tester.tap(find.byKey(const Key('probe.tap')));
      await tester.pump();
      final probe = tester.state<StateProbeState>(find.byType(StateProbe));
      expect(probe.taps, 1);

      harness.container.read(inspectorProvider.notifier).open();
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(InspectorDock)).width, 352);
      expect(find.byType(InspectorSheet), findsNothing);

      setWindowSize(tester, const Size(1000, 900));
      await tester.pumpAndSettle();

      expect(find.byType(ShellRail), findsOneWidget);
      expect(find.byType(ShellSidebar), findsOneWidget);
      expect(find.byType(InspectorDock), findsNothing);
      expect(find.byType(InspectorSheet), findsOneWidget);
      expect(
        tester.state<StateProbeState>(find.byType(StateProbe)),
        same(probe),
      );
      expect(find.text('probe 1'), findsOneWidget);
    },
  );

  testWidgets(
    'narrow window shows bottom bar with four destinations and no rail',
    (tester) async {
      await pumpShell(tester, size: const Size(390, 800));

      expect(find.byType(ShellBottomBar), findsOneWidget);
      expect(find.byType(ShellRail), findsNothing);
      expect(find.byType(ShellSidebar), findsNothing);
      expect(find.byType(ShellDrawer), findsNothing);

      final ids = ['home', 'personal', 'organisation', 'settings'];
      final labels = ['Home', 'Personal', 'Organisation', 'Settings'];
      double? previousX;
      for (var i = 0; i < ids.length; i++) {
        final item = find.byKey(ShellKeys.bar(ids[i]));
        expect(item, findsOneWidget, reason: ids[i]);
        expect(
          find.descendant(of: item, matching: find.text(labels[i])),
          findsOneWidget,
        );
        final x = tester.getCenter(item).dx;
        if (previousX != null) expect(x, greaterThan(previousX));
        previousX = x;
      }

      await tester.tap(find.byKey(ShellKeys.drawerToggle));
      await tester.pumpAndSettle();
      expect(find.byType(ShellDrawer), findsOneWidget);
      expect(find.byType(ShellSidebar), findsOneWidget);
    },
  );

  testWidgets('picking a bottom-bar destination closes the drawer', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(390, 800));
    await tester.tap(find.byKey(ShellKeys.drawerToggle));
    await tester.pumpAndSettle();
    expect(find.byType(ShellDrawer), findsOneWidget);

    await tester.tap(find.byKey(ShellKeys.bar('personal')));
    await tester.pumpAndSettle();

    expect(find.byType(ShellDrawer), findsNothing);
    expect(find.widgetWithText(EmptyState, 'Personal'), findsOneWidget);
  });
}
