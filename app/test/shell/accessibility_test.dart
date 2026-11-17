import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/shell/logic/inspector_notifier.dart';
import 'package:kaname_app/shell/ui/nav_item.dart';
import 'package:kaname_app/shell/ui/shell_icon_button.dart';
import 'package:kaname_app/shell/ui/shell_keys.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../support/pump_shell.dart';

const _railIds = ['home', 'personal', 'organisation', 'settings'];

/// Which rail item holds primary focus, or null.
String? _focusedRailId(WidgetTester tester) {
  final focused = FocusManager.instance.primaryFocus;
  for (final id in _railIds) {
    final icon = find.descendant(
      of: find.byKey(ShellKeys.rail(id)),
      matching: find.byType(Icon),
    );
    if (Focus.of(tester.element(icon)) == focused) return id;
  }
  return null;
}

bool _showsRing(WidgetTester tester, String id) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byKey(ShellKeys.rail(id)),
        matching: find.byType(DecoratedBox),
      ),
    )
    .any(
      (box) =>
          box.decoration is ShapeDecoration &&
          (box.decoration as ShapeDecoration).shape is EmberFocusBorder &&
          ((box.decoration as ShapeDecoration).shape as EmberFocusBorder)
                  .ring ==
              1,
    );

void main() {
  testWidgets('rail items take focus in order with the ring and selected '
      'semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpShell(tester, size: const Size(1440, 900));

    // Start from the top bar: the page's own focus scope holds no control,
    // so Tab from it goes nowhere.
    tester
        .widget<ShellIconButton>(find.byKey(ShellKeys.inspectorToggle))
        .focusNode!
        .requestFocus();
    await tester.pump();

    final order = <String>[];
    for (var i = 0; i < 12 && order.length < _railIds.length; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final id = _focusedRailId(tester);
      if (id == null) continue;
      order.add(id);
      expect(_showsRing(tester, id), isTrue, reason: '$id shows the ring');
      for (final other in _railIds.where((o) => o != id)) {
        expect(_showsRing(tester, other), isFalse, reason: other);
      }
    }
    expect(order, _railIds);

    expect(
      tester.getSemantics(find.byKey(ShellKeys.rail('home'))),
      isSemantics(
        label: 'Home',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(ShellKeys.rail('personal'))),
      isSemantics(
        label: 'Personal',
        isButton: true,
        isSelected: false,
        hasSelectedState: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('every icon-only shell control has a semantic label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    void expectLabelled(Finder controls, {required String where}) {
      expect(controls, findsWidgets, reason: where);
      for (var i = 0; i < controls.evaluate().length; i++) {
        final node = tester.getSemantics(controls.at(i));
        expect(
          node.label.trim().isNotEmpty,
          isTrue,
          reason: '$where: control $i (${controls.at(i)}) has no label',
        );
      }
    }

    final controls = find.byWidgetPredicate(
      (w) => w is IconButton || w is ShellNavItem,
    );

    final wide = await pumpShell(tester, size: const Size(1440, 900));
    wide.container.read(inspectorProvider.notifier).open();
    await tester.pumpAndSettle();
    expectLabelled(controls, where: 'wide, inspector open');
    expect(find.byKey(ShellKeys.inspectorClose), findsOneWidget);

    setWindowSize(tester, const Size(390, 800));
    await tester.pumpAndSettle();
    expectLabelled(controls, where: 'narrow, inspector open');
    expect(find.byKey(ShellKeys.drawerToggle), findsOneWidget);

    semantics.dispose();
  });
}
