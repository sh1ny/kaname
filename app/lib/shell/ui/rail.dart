import 'package:flutter/material.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../logic/slot_registry.dart';
import 'nav_item.dart';
import 'shell_keys.dart';

/// The icon rail: the module slots from the top, Settings at the foot.
///
/// Destination `i` of the registry is item `i`; [onSelected] gets that index.
class ShellRail extends StatelessWidget {
  /// Creates the rail.
  const ShellRail({
    required this.registry,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  /// The registry the items come from.
  final SlotRegistry registry;

  /// The selected destination's index, or null when none is selected.
  final int? selectedIndex;

  /// Called with the destination's index when an item is activated.
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = EmberColors.of(context);
    Widget item(int index, ModuleSlot slot) => Padding(
      padding: const EdgeInsets.only(bottom: EmberSpace.sm),
      child: ShellNavItem(
        key: ShellKeys.rail(slot.id),
        icon: slot.icon,
        label: slot.label(l10n),
        selected: selectedIndex == index,
        onPressed: () => onSelected(index),
      ),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.primaryNavigation,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.canvas,
          border: Border(right: BorderSide(color: colors.hairline)),
        ),
        child: SizedBox(
          width: EmberSize.rail,
          child: FocusTraversalGroup(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                EmberSpace.sm,
                EmberSpace.sm,
                EmberSpace.sm,
                0,
              ),
              child: Column(
                children: [
                  for (final (index, slot) in registry.slots.indexed)
                    item(index, slot),
                  const Spacer(),
                  item(registry.slots.length, registry.settings),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
