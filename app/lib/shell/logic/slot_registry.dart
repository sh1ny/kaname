import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../modules/home/ui/home_screen.dart';
import '../../modules/organisation/ui/organisation_screen.dart';
import '../../modules/personal/ui/personal_screen.dart';
import '../../settings/ui/settings_screen.dart';

/// Resolves a slot's localised label.
typedef SlotLabel = String Function(AppLocalizations l10n);

/// One top-level destination: what the rail, the bottom bar and the router
/// need to show and reach it.
final class ModuleSlot {
  /// Creates a slot.
  const ModuleSlot({
    required this.id,
    required this.path,
    required this.label,
    required this.icon,
    required this.builder,
  });

  /// The slot's unique id.
  final String id;

  /// The slot's unique route path, such as `/home`.
  final String path;

  /// The slot's label in the current locale.
  final SlotLabel label;

  /// The slot's icon in the rail and the bottom bar.
  final IconData icon;

  /// Builds the slot's screen, the root of its router branch.
  final WidgetBuilder builder;
}

/// The one registry every module slot comes from.
///
/// The shell builds its rail, its bottom bar and its router branches from this
/// list, in order, with [settings] after the module slots (at the rail's
/// foot).
///
/// C1: every module registers exactly one slot, with a unique id and route
/// path. The constructor refuses a duplicate id or path with a [StateError]
/// that names it, before any screen is built. Requirement: app-shell → Module
/// slots come from one registry.
final class SlotRegistry {
  /// Creates a registry of module [slots] plus the [settings] slot.
  ///
  /// Throws a [StateError] naming the duplicate when two slots (Settings
  /// included) share an id or a route path.
  SlotRegistry({required List<ModuleSlot> slots, required this.settings})
    : slots = List.unmodifiable(slots) {
    final ids = <String>{};
    final paths = <String>{};
    for (final slot in destinations) {
      if (!ids.add(slot.id)) {
        throw StateError(
          'Duplicate slot id "${slot.id}" in the slot registry.',
        );
      }
      if (!paths.add(slot.path)) {
        throw StateError(
          'Duplicate slot path "${slot.path}" in the slot registry '
          '(slot "${slot.id}").',
        );
      }
    }
  }

  /// The M0 registry: empty Home, Personal and Organisation slots, then
  /// Settings.
  factory SlotRegistry.m0() => SlotRegistry(
    slots: [
      ModuleSlot(
        id: 'home',
        path: '/home',
        label: (l10n) => l10n.navHome,
        // Placeholder icon; settled at the owner's look check.
        icon: Icons.home_outlined,
        builder: (_) => const HomeScreen(),
      ),
      ModuleSlot(
        id: 'personal',
        path: '/personal',
        label: (l10n) => l10n.navPersonal,
        icon: Icons.person_outline,
        builder: (_) => const PersonalScreen(),
      ),
      ModuleSlot(
        id: 'organisation',
        path: '/organisation',
        label: (l10n) => l10n.navOrganisation,
        icon: Icons.groups_outlined,
        builder: (_) => const OrganisationScreen(),
      ),
    ],
    settings: ModuleSlot(
      id: 'settings',
      path: '/settings',
      label: (l10n) => l10n.navSettings,
      icon: Icons.settings_outlined,
      builder: (_) => const SettingsScreen(),
    ),
  );

  /// The module slots, in rail order.
  final List<ModuleSlot> slots;

  /// The Settings slot, shown after the module slots.
  final ModuleSlot settings;

  /// Every destination in order: the module slots, then [settings].
  ///
  /// The router's branch index of a destination is its index here.
  List<ModuleSlot> get destinations => [...slots, settings];
}
