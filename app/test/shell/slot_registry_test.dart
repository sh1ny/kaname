import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/l10n/generated/app_localizations.dart';
import 'package:kaname_app/shell/logic/slot_registry.dart';

ModuleSlot _slot(String id, String path) => ModuleSlot(
  id: id,
  path: path,
  label: (_) => id,
  icon: Icons.circle_outlined,
  builder: (_) => const SizedBox(),
);

Matcher _stateErrorNaming(String text) => throwsA(
  isA<StateError>().having((e) => e.message, 'message', contains(text)),
);

void main() {
  test('M0 registry lists Home, Personal, Organisation with Settings at the '
      'foot', () {
    final registry = SlotRegistry.m0();
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(registry.slots.map((s) => s.id), [
      'home',
      'personal',
      'organisation',
    ]);
    expect(registry.slots.map((s) => s.path), [
      '/home',
      '/personal',
      '/organisation',
    ]);
    expect(registry.slots.map((s) => s.label(l10n)), [
      'Home',
      'Personal',
      'Organisation',
    ]);
    expect(registry.settings.id, 'settings');
    expect(registry.settings.path, '/settings');
    expect(registry.settings.label(l10n), 'Settings');
    expect(registry.destinations.last, same(registry.settings));
    expect(registry.destinations, hasLength(4));
  });

  test('duplicate id or path throws naming the duplicate', () {
    final settings = _slot('settings', '/settings');

    expect(
      () => SlotRegistry(
        slots: [_slot('a', '/a'), _slot('a', '/b')],
        settings: settings,
      ),
      _stateErrorNaming('"a"'),
    );
    expect(
      () => SlotRegistry(
        slots: [_slot('a', '/shared'), _slot('b', '/shared')],
        settings: settings,
      ),
      _stateErrorNaming('"/shared"'),
    );
    // Settings counts too.
    expect(
      () => SlotRegistry(slots: [_slot('settings', '/x')], settings: settings),
      _stateErrorNaming('"settings"'),
    );
  });
}
