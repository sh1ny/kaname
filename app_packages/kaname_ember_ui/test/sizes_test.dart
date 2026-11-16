import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

/// The rendered height of the Material that paints [control].
Size _size(WidgetTester tester, Finder control) => tester.getSize(
  find.descendant(of: control, matching: find.byType(Material)).first,
);

void main() {
  testWidgets('chips are 24px tall and styled controls keep their sizes', (
    tester,
  ) async {
    for (final (name, theme) in [
      ('Ember dark', EmberTheme.dark()),
      ('Ember light', EmberTheme.light()),
    ]) {
      final menu = MenuController();
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(name),
          theme: theme,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Default'),
                  ),
                  FilledButton(onPressed: () {}, child: const Text('Primary')),
                  TextButton(onPressed: () {}, child: const Text('Quiet')),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
                  FilterChip(
                    label: const Text('Chip'),
                    selected: true,
                    onSelected: (_) {},
                  ),
                  const SizedBox(
                    width: 200,
                    child: TextField(
                      decoration: InputDecoration(labelText: 'Name'),
                    ),
                  ),
                  MenuAnchor(
                    controller: menu,
                    menuChildren: [
                      MenuItemButton(
                        onPressed: () {},
                        child: const Text('Rename'),
                      ),
                    ],
                    child: const SizedBox(width: 10, height: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      menu.open();
      await tester.pumpAndSettle();

      expect(
        _size(tester, find.byType(FilterChip)).height,
        EmberSize.chip,
        reason: '$name: chip height',
      );
      for (final type in [OutlinedButton, FilledButton, TextButton]) {
        expect(
          _size(tester, find.byType(type)).height,
          EmberSize.control,
          reason: '$name: $type height',
        );
      }
      expect(
        _size(tester, find.byType(IconButton)),
        const Size.square(EmberSize.control),
        reason: '$name: icon button size',
      );
      expect(
        _size(tester, find.byType(MenuItemButton)).height,
        EmberSize.row,
        reason: '$name: menu item height',
      );
      expect(
        tester.getSize(find.byType(InputDecorator)).height,
        44.0,
        reason: '$name: text field height',
      );
    }
  });
}
