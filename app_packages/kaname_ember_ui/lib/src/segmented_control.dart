import 'package:flutter/material.dart';

import 'focus_ring.dart';
import 'generated/ember_tokens.dart';

/// One option of an [EmberSegmentedControl].
final class EmberSegment<T> {
  /// Creates an option that picks [value], showing [label]. [key] names the
  /// option's widget, so callers and tests can find it.
  const EmberSegment({required this.value, required this.label, this.key});

  /// The value this option picks.
  final T value;

  /// The option's text, also its screen-reader name.
  final String label;

  /// The key of the option's widget.
  final Key? key;
}

/// Ember's segmented control: one choice among a few options.
///
/// A pill track (Raised fill, Hairline border, 2px inset) of 24px pill
/// options in Ink Secondary; the selected option takes the segment fill, Ink
/// and the Seated shadow, and a hovered one the Hover fill (DESIGN.md,
/// "Segmented controls"). Material's `SegmentedButton` clips rectangular
/// segments, so neither the pills nor the focus ring could come from a theme.
///
/// Options take focus in order with Tab and pick their value with Enter or
/// Space. The focused option shows the 2px Focus ring 2px outside its pill
/// ([EmberFocusBorder.pill]), painted above the other options so a selected
/// or hovered neighbour never covers it. For screen readers the control is a
/// group named [semanticLabel], and each option a button named by its label,
/// with its selected state, in a mutually exclusive group.
///
/// The control keeps no value of its own: [onChanged] reports a pick, and the
/// caller passes the new [value] back.
class EmberSegmentedControl<T> extends StatefulWidget {
  /// Creates a control showing [segments], with [value] selected.
  const EmberSegmentedControl({
    required this.segments,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    super.key,
  });

  /// The options, in order.
  final List<EmberSegment<T>> segments;

  /// The selected value.
  final T value;

  /// Called with the value of the option the person picks.
  final ValueChanged<T> onChanged;

  /// The screen-reader name of the whole control.
  final String semanticLabel;

  @override
  State<EmberSegmentedControl<T>> createState() =>
      _EmberSegmentedControlState<T>();
}

class _EmberSegmentedControlState<T> extends State<EmberSegmentedControl<T>> {
  int? _focused;
  int? _hovered;

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.raised,
          border: Border.all(color: colors.hairline),
          borderRadius: BorderRadius.circular(EmberRadius.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          // The rings are a second row laid out like the options and painted
          // above them, so a selected or hovered neighbour, painted after the
          // focused option, cannot cover the focused option's ring.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, segment) in widget.segments.indexed)
                    _option(segment, i, colors, dark),
                ],
              ),
              IgnorePointer(
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (i, segment) in widget.segments.indexed)
                        _ring(segment, i, colors),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _option(
    EmberSegment<T> segment,
    int i,
    EmberColors colors,
    bool dark,
  ) {
    final selected = segment.value == widget.value;
    void pick() => widget.onChanged(segment.value);
    return Semantics(
      key: segment.key,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      enabled: true,
      label: segment.label,
      onTap: pick,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (on) => setState(
          () => _focused = on ? i : (_focused == i ? null : _focused),
        ),
        onShowHoverHighlight: (on) => setState(
          () => _hovered = on ? i : (_hovered == i ? null : _hovered),
        ),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              pick();
              return null;
            },
          ),
        },
        // The label is the option's name already; its text adds nothing.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: pick,
          child: _box(
            decoration: ShapeDecoration(
              color: selected
                  ? colors.segmentOn
                  : (_hovered == i ? colors.hover : null),
              shadows: selected
                  ? (dark ? EmberShadows.seatedDark : EmberShadows.seatedLight)
                  : null,
              shape: const StadiumBorder(),
            ),
            label: ExcludeSemantics(
              child: Text(
                segment.label,
                style: EmberType.control.copyWith(
                  color: selected ? colors.ink : colors.inkSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The ring of option [i]: the option's box with an invisible label, so it
  /// takes the option's exact size, painting only the Focus ring.
  Widget _ring(EmberSegment<T> segment, int i, EmberColors colors) => _box(
    decoration: ShapeDecoration(
      shape: EmberFocusBorder.pill(
        focus: colors.focus,
        ring: _focused == i ? 1 : 0,
      ),
    ),
    label: Opacity(
      opacity: 0,
      child: Text(segment.label, style: EmberType.control),
    ),
  );

  /// The pill box every option and its ring share.
  Widget _box({required Decoration decoration, required Widget label}) =>
      Container(
        height: EmberSize.segment,
        padding: const EdgeInsets.symmetric(horizontal: EmberSpace.md),
        alignment: Alignment.center,
        decoration: decoration,
        child: label,
      );
}
