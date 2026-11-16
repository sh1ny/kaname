import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import 'support/focus_check.dart';

/// One styled control in the focus scene.
typedef _Control = ({
  String name,
  Finder finder,
  FocusIndicator indicator,
  Duration settle,
});

/// The two Ember themes under test.
final _themes = <({String name, ThemeData data, EmberColors colors})>[
  (name: 'Ember dark', data: EmberTheme.dark(), colors: EmberColors.dark),
  (name: 'Ember light', data: EmberTheme.light(), colors: EmberColors.light),
];

/// Places [child] on whole logical pixels inside a boundary that covers the
/// screen, so the checker can read the pixels the controls paint.
Widget _scene(GlobalKey boundary, ThemeData theme, Widget child) =>
    RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        theme: theme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Padding(padding: const EdgeInsets.all(24), child: child),
          ),
        ),
      ),
    );

/// Every styled control except the menu item, in tab order.
Widget _controls() => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (final control in <Widget>[
      SizedBox(
        width: 120,
        child: OutlinedButton(
          key: const Key('default'),
          onPressed: () {},
          child: const Text('Default'),
        ),
      ),
      SizedBox(
        width: 120,
        child: FilledButton(
          key: const Key('primary'),
          onPressed: () {},
          child: const Text('Primary'),
        ),
      ),
      SizedBox(
        width: 120,
        child: TextButton(
          key: const Key('quiet'),
          onPressed: () {},
          child: const Text('Quiet'),
        ),
      ),
      IconButton(
        key: const Key('icon'),
        onPressed: () {},
        icon: const Icon(Icons.add),
      ),
      SizedBox(
        width: 96,
        child: FilterChip(
          key: const Key('chip'),
          label: const Text('Chip'),
          selected: false,
          onSelected: (_) {},
        ),
      ),
      const SizedBox(
        key: Key('field'),
        width: 200,
        child: TextField(decoration: InputDecoration(labelText: 'Name')),
      ),
    ])
      Padding(padding: const EdgeInsets.only(bottom: 16), child: control),
  ],
);

/// The controls of [_controls], with the Material that paints each shape.
List<_Control> _controlList(WidgetTester tester) {
  Finder shape(String key, Type type) => find
      .descendant(of: find.byKey(Key(key)), matching: find.byType(type))
      .first;
  Finder material(String key) => shape(key, Material);
  return [
    (
      name: 'Default button',
      finder: material('default'),
      indicator: FocusIndicator.outsideRing,
      settle: Duration.zero,
    ),
    (
      name: 'Primary button',
      finder: material('primary'),
      indicator: FocusIndicator.outsideRing,
      settle: Duration.zero,
    ),
    (
      name: 'Quiet button',
      finder: material('quiet'),
      indicator: FocusIndicator.outsideRing,
      settle: Duration.zero,
    ),
    (
      name: 'Icon button',
      finder: material('icon'),
      indicator: FocusIndicator.outsideRing,
      settle: Duration.zero,
    ),
    (
      name: 'Chip',
      finder: material('chip'),
      indicator: FocusIndicator.outsideRing,
      settle: const Duration(milliseconds: 75),
    ),
    (
      name: 'Text field',
      finder: shape('field', InputDecorator),
      indicator: FocusIndicator.borderWithHalo,
      settle: const Duration(milliseconds: 167),
    ),
  ];
}

FocusProbe _probe(
  WidgetTester tester,
  _Control control,
  ({String name, ThemeData data, EmberColors colors}) theme,
) => (
  control: control.name,
  theme: theme.name,
  indicator: control.indicator,
  rect: tester.getRect(control.finder),
  focus: theme.colors.focus,
  surface: theme.colors.canvas,
  halo: control.indicator == FocusIndicator.borderWithHalo
      ? theme.colors.accentSoft
      : null,
);

Future<void> _tab(WidgetTester tester, Duration settle) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
  if (settle > Duration.zero) await tester.pump(settle);
}

/// Moves focus down one item of the open menu. An open Material menu keeps
/// focus in its own scope, so Tab does not reach its items; arrow keys do, as
/// DESIGN.md has it.
Future<void> _arrow(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  await tester.pump();
}

/// Opens a menu of three items and returns the finders for each item's Material.
Future<List<Finder>> _openMenu(
  WidgetTester tester,
  GlobalKey boundary,
  ThemeData theme,
) async {
  final menu = MenuController();
  await tester.pumpWidget(
    _scene(
      boundary,
      theme,
      MenuAnchor(
        controller: menu,
        menuChildren: [
          for (final label in ['Rename', 'Duplicate', 'Archive'])
            MenuItemButton(
              key: Key(label),
              onPressed: () {},
              child: Text(label),
            ),
        ],
        child: const SizedBox(width: 10, height: 10),
      ),
    ),
  );
  menu.open();
  await tester.pumpAndSettle();
  return [
    for (final label in ['Rename', 'Duplicate', 'Archive'])
      find
          .descendant(
            of: find.byKey(Key(label)),
            matching: find.byType(Material),
          )
          .first,
  ];
}

void main() {
  testWidgets('tab to each control paints its Focus indicator in both themes', (
    tester,
  ) async {
    for (final theme in _themes) {
      final boundary = GlobalKey();
      await tester.pumpWidget(_scene(boundary, theme.data, _controls()));
      for (final control in _controlList(tester)) {
        await _tab(tester, control.settle);
        await expectFocusIndicator(
          tester,
          boundary,
          _probe(tester, control, theme),
        );
      }

      final menuBoundary = GlobalKey();
      final items = await _openMenu(tester, menuBoundary, theme.data);
      await _arrow(tester);
      final menuItem = (
        name: 'Menu item',
        finder: items.first,
        indicator: FocusIndicator.insideRing,
        settle: Duration.zero,
      );
      await expectFocusIndicator(
        tester,
        menuBoundary,
        _probe(tester, menuItem, theme),
      );
    }
  });

  testWidgets('focus leaving a control removes its indicator', (tester) async {
    for (final theme in _themes) {
      final boundary = GlobalKey();
      await tester.pumpWidget(_scene(boundary, theme.data, _controls()));
      final controls = _controlList(tester);
      for (var i = 0; i < controls.length; i++) {
        await _tab(tester, controls[i].settle);
        // The control holds focus, so its indicator is there to be removed.
        await expectFocusIndicator(
          tester,
          boundary,
          _probe(tester, controls[i], theme),
        );
        if (i == 0) continue;
        // Focus has just left controls[i - 1]; wait out that control's own
        // transition, then it must paint no indicator.
        await tester.pump(controls[i - 1].settle);
        await expectNoFocusIndicator(
          tester,
          boundary,
          _probe(tester, controls[i - 1], theme),
        );
      }

      final menuBoundary = GlobalKey();
      final items = await _openMenu(tester, menuBoundary, theme.data);
      await _arrow(tester);
      final first = (
        name: 'Menu item',
        finder: items.first,
        indicator: FocusIndicator.insideRing,
        settle: Duration.zero,
      );
      await expectFocusIndicator(
        tester,
        menuBoundary,
        _probe(tester, first, theme),
      );
      await _arrow(tester);
      await expectNoFocusIndicator(
        tester,
        menuBoundary,
        _probe(tester, first, theme),
      );
    }
  });

  testWidgets(
    'focus check fails naming control and theme for an unstyled control',
    (tester) async {
      final boundary = GlobalKey();
      await tester.pumpWidget(
        _scene(
          boundary,
          ThemeData(),
          SizedBox(
            width: 120,
            child: TextButton(onPressed: () {}, child: const Text('Save')),
          ),
        ),
      );
      await _tab(tester, Duration.zero);
      final material = find
          .descendant(
            of: find.byType(TextButton),
            matching: find.byType(Material),
          )
          .first;
      final probe = (
        control: 'Default button',
        theme: 'Material (unstyled)',
        indicator: FocusIndicator.outsideRing,
        rect: tester.getRect(material),
        focus: EmberColors.dark.focus,
        surface: Colors.white,
        halo: null,
      );
      await expectLater(
        expectFocusIndicator(tester, boundary, probe),
        throwsA(
          isA<TestFailure>().having(
            (f) => f.message,
            'message',
            allOf(contains('Default button'), contains('Material (unstyled)')),
          ),
        ),
      );
    },
  );
}
