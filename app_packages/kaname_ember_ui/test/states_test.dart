import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import 'support/pixel_capture.dart';

/// The two Ember themes under test.
final _themes = <({String name, ThemeData data, EmberColors colors})>[
  (name: 'Ember dark', data: EmberTheme.dark(), colors: EmberColors.dark),
  (name: 'Ember light', data: EmberTheme.light(), colors: EmberColors.light),
];

Widget _app(ThemeData theme, Widget child, {GlobalKey? boundary}) {
  final app = MaterialApp(
    theme: theme,
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    ),
  );
  return boundary == null ? app : RepaintBoundary(key: boundary, child: app);
}

/// Scales every channel of [c] by [factor], as CSS `brightness()` does.
Color _brightness(Color c, double factor) => Color.from(
  alpha: c.a,
  red: (c.r * factor).clamp(0, 1),
  green: (c.g * factor).clamp(0, 1),
  blue: (c.b * factor).clamp(0, 1),
);

/// One control pressed and hovered: what it is, where its Material is, and the
/// fills it shows pressed and hovered.
typedef _Pressable = ({
  String name,
  Widget widget,
  Finder control,
  Color pressed,
  Color hovered,
});

List<_Pressable> _pressables(EmberColors c) => [
  (
    name: 'Default button',
    widget: OutlinedButton(onPressed: () {}, child: const Text('Default')),
    control: find.byType(OutlinedButton),
    pressed: c.press,
    hovered: c.hover,
  ),
  (
    name: 'Primary button',
    widget: FilledButton(onPressed: () {}, child: const Text('Primary')),
    control: find.byType(FilledButton),
    pressed: _brightness(c.accent, 0.93),
    hovered: _brightness(c.accent, 1.07),
  ),
  (
    name: 'Quiet button',
    widget: TextButton(onPressed: () {}, child: const Text('Quiet')),
    control: find.byType(TextButton),
    pressed: c.press,
    hovered: c.hover,
  ),
  (
    name: 'Icon button',
    widget: IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
    control: find.byType(IconButton),
    pressed: c.press,
    hovered: c.hover,
  ),
  (
    name: 'Menu item',
    widget: MenuItemButton(
      onPressed: () {},
      closeOnActivate: false,
      child: const Text('Rename'),
    ),
    control: find.byType(MenuItemButton),
    pressed: c.press,
    hovered: c.hover,
  ),
];

/// Fails when any ink feature of [context]'s Material paints a splash or
/// ripple, or when [control]'s ink well would tint its fill.
void _expectNoSplash(WidgetTester tester, Finder control) {
  final inkWell = find
      .descendant(of: control, matching: find.byType(InkWell))
      .first;
  final element = tester.element(inkWell);
  expect(
    Theme.of(element).splashFactory,
    same(NoSplash.splashFactory),
    reason: 'the theme sets the no-splash factory',
  );
  expect(
    tester.widget<InkWell>(inkWell).splashFactory,
    anyOf(isNull, same(NoSplash.splashFactory)),
  );
  final overlay = tester.widget<InkWell>(inkWell).overlayColor;
  for (final state in [
    WidgetState.hovered,
    WidgetState.pressed,
    WidgetState.focused,
  ]) {
    final colour = overlay?.resolve({state});
    expect(
      colour == null || colour.a == 0,
      isTrue,
      reason: 'the ink overlay is transparent while ${state.name}, was $colour',
    );
  }
  expect(Material.of(element) as RenderObject, isNot(paints..circle()));
}

/// The fill [control]'s own Material paints.
Color? _fill(WidgetTester tester, Finder control) => tester
    .widget<Material>(
      find.descendant(of: control, matching: find.byType(Material)).first,
    )
    .color;

void main() {
  testWidgets(
    'buttons, icon buttons and menu items paint no splash and change state on '
    'the next frame',
    (tester) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      for (final theme in _themes) {
        for (final item in _pressables(theme.colors)) {
          final menu = MenuController();
          final label = '${item.name} in ${theme.name}';
          await tester.pumpWidget(
            _app(
              theme.data,
              item.widget is MenuItemButton
                  ? MenuAnchor(
                      controller: menu,
                      menuChildren: [item.widget],
                      child: const SizedBox(width: 10, height: 10),
                    )
                  : item.widget,
            ),
          );
          // Settle MaterialApp's own theme animation when the theme changed.
          await tester.pumpAndSettle();
          if (item.widget is MenuItemButton) {
            menu.open();
            await tester.pumpAndSettle();
          }
          final centre = tester.getCenter(item.control);

          await mouse.moveTo(centre);
          await mouse.down(centre);
          await tester.pump();
          expect(
            _fill(tester, item.control),
            item.pressed,
            reason: '$label shows its pressed fill on the next frame',
          );
          _expectNoSplash(tester, item.control);

          await mouse.up();
          await tester.pump();
          expect(
            _fill(tester, item.control),
            item.hovered,
            reason: '$label shows its hovered fill on the next frame',
          );
          _expectNoSplash(tester, item.control);
        }
      }
    },
  );

  testWidgets(
    "text field border and chip fill reach Ember colours after Material's "
    'transition, no splash',
    (tester) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      for (final theme in _themes) {
        final c = theme.colors;
        final boundary = GlobalKey();
        final selected = ValueNotifier(false);
        await tester.pumpWidget(
          _app(
            theme.data,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  key: Key('field'),
                  width: 200,
                  child: TextField(
                    decoration: InputDecoration(labelText: 'Name'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 96,
                  child: ValueListenableBuilder(
                    valueListenable: selected,
                    builder: (context, value, _) => FilterChip(
                      key: const Key('chip'),
                      label: const Text('Chip'),
                      selected: value,
                      onSelected: (v) => selected.value = v,
                    ),
                  ),
                ),
              ],
            ),
            boundary: boundary,
          ),
        );

        // Text field: focus it, wait out the 167ms border transition.
        final field = tester.getRect(find.byType(InputDecorator));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 167));
        var pixels = await capturePixels(tester, boundary);
        final border = pixels.at(field.center.dx.round(), field.top.round());
        expect(
          _same(border, c.focus),
          isTrue,
          reason:
              '${theme.name}: focused field border should be Focus '
              '${c.focus}, was $border',
        );
        expect(
          find.byType(InkWell).evaluate().isEmpty ||
              Theme.of(tester.element(find.byType(InputDecorator)))
                      .splashFactory ==
                  NoSplash.splashFactory,
          isTrue,
        );

        // Chip: hover paints no fill; selecting it fills with Ember Glow.
        final chip = tester.getRect(
          find
              .descendant(
                of: find.byKey(const Key('chip')),
                matching: find.byType(Material),
              )
              .first,
        );
        final probe = (chip.center.dx.round(), chip.top.round() + 3);
        await mouse.moveTo(chip.center);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        pixels = await capturePixels(tester, boundary);
        expect(
          _same(pixels.at(probe.$1, probe.$2), c.canvas),
          isTrue,
          reason:
              '${theme.name}: a hovered unselected chip keeps the canvas '
              'fill, was ${pixels.at(probe.$1, probe.$2)}',
        );
        await mouse.moveTo(Offset.zero);
        await tester.pump();

        selected.value = true;
        await tester.pumpAndSettle();
        pixels = await capturePixels(tester, boundary);
        final fill = pixels.at(probe.$1, probe.$2);
        expect(
          _same(fill, Color.alphaBlend(c.accentSoft, c.canvas)),
          isTrue,
          reason:
              '${theme.name}: a selected chip fills with Ember Glow over '
              'the canvas, was $fill',
        );
        _expectNoSplash(tester, find.byKey(const Key('chip')));
      }
    },
  );

  testWidgets('text field value uses the Ember body sans style in Ink', (
    tester,
  ) async {
    for (final theme in _themes) {
      await tester.pumpWidget(
        _app(
          theme.data,
          SizedBox(
            width: 200,
            child: TextField(
              controller: TextEditingController(text: 'Aria Vale'),
              decoration: const InputDecoration(labelText: 'Pilot'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final style = tester
          .widget<EditableText>(find.byType(EditableText))
          .style;
      expect(
        style.fontFamily,
        EmberType.body.fontFamily,
        reason: '${theme.name}: the value is set in the sans family',
      );
      expect(style.fontSize, EmberType.body.fontSize);
      expect(
        style.color,
        theme.colors.ink,
        reason: '${theme.name}: the value is Ink',
      );
    }
  });
}

bool _same(Color a, Color b) =>
    (a.r - b.r).abs() * 255 <= 3 &&
    (a.g - b.g).abs() * 255 <= 3 &&
    (a.b - b.b).abs() * 255 <= 3;
