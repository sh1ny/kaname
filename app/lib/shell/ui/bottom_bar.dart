import 'package:flutter/material.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../logic/slot_registry.dart';
import 'nav_item.dart';
import 'shell_keys.dart';

/// The bottom navigation bar of narrow windows: every registry destination,
/// Settings last, each with an icon and its label.
///
/// C9: the bar is sized for the M0 slots (four items across a phone's width).
/// What it does past about five slots (scroll, an overflow item, or a "more"
/// destination) is a deliberate gap for the first change that registers a
/// fifth module; until then the items simply share the width.
class ShellBottomBar extends StatelessWidget {
  /// Creates the bottom bar.
  const ShellBottomBar({
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
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.primaryNavigation,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.canvas,
          border: Border(top: BorderSide(color: colors.hairline)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(EmberSpace.xs),
          child: FocusTraversalGroup(
            child: Row(
              children: [
                for (final (index, slot) in registry.destinations.indexed)
                  Expanded(
                    child: ShellNavItem(
                      key: ShellKeys.bar(slot.id),
                      icon: slot.icon,
                      label: slot.label(l10n),
                      selected: selectedIndex == index,
                      showLabel: true,
                      onPressed: () => onSelected(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
