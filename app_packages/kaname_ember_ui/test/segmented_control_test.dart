import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

enum _Room { system, dark, light }

/// Shows a control with three options whose value lives in the test, so a
/// pick rebuilds it as a caller would.
Future<List<_Room>> _pump(
  WidgetTester tester, {
  _Room initial = _Room.system,
}) async {
  final picks = <_Room>[];
  var value = initial;
  await tester.pumpWidget(
    MaterialApp(
      theme: EmberTheme.dark(),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => EmberSegmentedControl<_Room>(
            semanticLabel: 'Theme',
            value: value,
            onChanged: (picked) {
              picks.add(picked);
              setState(() => value = picked);
            },
            segments: [
              for (final room in _Room.values)
                EmberSegment(
                  value: room,
                  label: room.name,
                  key: Key('room.${room.name}'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  return picks;
}

void main() {
  testWidgets('tapping an option picks its value', (tester) async {
    final picks = await _pump(tester);
    await tester.tap(find.byKey(const Key('room.light')));
    await tester.pump();
    expect(picks, [_Room.light]);
  });

  testWidgets('Enter and Space pick the focused option', (tester) async {
    final picks = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(picks, [_Room.dark, _Room.light]);
  });

  testWidgets('the control and each option carry their semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, initial: _Room.dark);
    expect(find.bySemanticsLabel('Theme'), findsOneWidget);
    for (final room in _Room.values) {
      expect(
        tester.getSemantics(find.byKey(Key('room.${room.name}'))),
        matchesSemantics(
          label: room.name,
          isButton: true,
          hasSelectedState: true,
          isSelected: room == _Room.dark,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
    }
    handle.dispose();
  });
}
