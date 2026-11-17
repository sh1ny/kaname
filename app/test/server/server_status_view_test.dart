import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/server/data/server_address.dart';
import 'package:kaname_app/server/ui/server_keys.dart';
import 'package:kaname_client/kaname_client.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../support/pump_shell.dart';
import 'fake_server_health.dart';

final _configured = ConfiguredServer(Uri.parse('http://127.0.0.1:8080/api/'));

Finder _inRow(Key row, String text) =>
    find.descendant(of: find.byKey(row), matching: find.text(text));

void main() {
  testWidgets('all up shows connected and version, Postgres up, Redis up', (
    tester,
  ) async {
    final fake = FakeServerHealth();
    await pumpShell(
      tester,
      location: '/settings',
      size: const Size(1440, 900),
      target: _configured,
      health: fake,
    );
    expect(find.text('Checking server'), findsOneWidget);

    fake.answer(
      HealthReport(
        version: '0.1.0',
        postgres: DependencyStatus.up,
        redis: DependencyStatus.up,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(ServerKeys.indicator),
        matching: find.text('Server connected'),
      ),
      findsOneWidget,
    );
    expect(_inRow(ServerKeys.version, '0.1.0'), findsOneWidget);
    expect(_inRow(ServerKeys.postgres, 'Up'), findsOneWidget);
    expect(_inRow(ServerKeys.redis, 'Up'), findsOneWidget);
  });

  testWidgets('Redis down shows text and error colour', (tester) async {
    final fake = FakeServerHealth();
    await pumpShell(
      tester,
      location: '/settings',
      size: const Size(1440, 900),
      target: _configured,
      health: fake,
    );
    fake.answer(
      HealthReport(
        version: '0.1.0',
        postgres: DependencyStatus.up,
        redis: DependencyStatus.down,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(ServerKeys.indicator),
        matching: find.text('Server connected with a dependency down'),
      ),
      findsOneWidget,
    );
    expect(_inRow(ServerKeys.postgres, 'Up'), findsOneWidget);
    final down = _inRow(ServerKeys.redis, 'Down');
    expect(down, findsOneWidget, reason: 'text, not colour alone');
    final context = tester.element(down);
    final style = tester.widget<Text>(down).style;
    expect(style?.color, Theme.of(context).colorScheme.error);
    expect(style?.color, EmberColors.of(context).errInk);
  });
}
