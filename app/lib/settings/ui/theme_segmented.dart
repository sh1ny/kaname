import 'package:flutter/material.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../data/theme_choice.dart';
import 'settings_keys.dart';

/// Ember's segmented control for the theme choice.
///
/// A pill track of 24px pill options; the selected one takes the segment
/// fill, Ink and the Seated shadow (DESIGN.md, "Segmented controls"). The
/// ember_ui package styles no segmented control and Material's
/// `SegmentedButton` cannot draw pills or the focus ring, so the control is
/// built here from [EmberFocusBorder]. Options take focus in order with Tab
/// and activate with Enter or Space.
class ThemeSegmented extends StatelessWidget {
  /// Creates the control showing [value], with each option named by [labels].
  const ThemeSegmented({
    required this.value,
    required this.labels,
    required this.onChanged,
    required this.groupLabel,
    super.key,
  });

  /// The selected choice.
  final ThemeChoice value;

  /// The text of each choice.
  final Map<ThemeChoice, String> labels;

  /// Called with the choice the person picks.
  final ValueChanged<ThemeChoice> onChanged;

  /// The screen-reader name of the whole control.
  final String groupLabel;

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    return Semantics(
      container: true,
      label: groupLabel,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.raised,
            border: Border.all(color: colors.hairline),
            borderRadius: BorderRadius.circular(EmberRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final choice in ThemeChoice.values)
                  _SegmentOption(
                    key: SettingsKeys.themeOption(choice),
                    label: labels[choice]!,
                    selected: choice == value,
                    onSelected: () => onChanged(choice),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentOption extends StatefulWidget {
  const _SegmentOption({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  State<_SegmentOption> createState() => _SegmentOptionState();
}

class _SegmentOptionState extends State<_SegmentOption> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selected = widget.selected;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: widget.label,
      onTap: widget.onSelected,
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onSelected();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onSelected,
          child: Container(
            height: EmberSize.segment,
            padding: const EdgeInsets.symmetric(horizontal: EmberSpace.md),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: selected
                  ? colors.segmentOn
                  : (_hovered ? colors.hover : null),
              shadows: selected
                  ? (dark ? EmberShadows.seatedDark : EmberShadows.seatedLight)
                  : null,
              shape: EmberFocusBorder.pill(
                focus: colors.focus,
                ring: _focused ? 1 : 0,
              ),
            ),
            child: Text(
              widget.label,
              style: EmberType.control.copyWith(
                color: selected ? colors.ink : colors.inkSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
