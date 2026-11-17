import 'package:flutter/material.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

/// One label-and-value line inside a Settings section.
///
/// The [value] wraps on a narrow window instead of overflowing; give it an
/// explicit [valueColor] to mark a state, always together with its text.
class SettingsRow extends StatelessWidget {
  /// Creates a row showing [label] and [value].
  const SettingsRow({
    required this.label,
    required this.value,
    this.valueColor,
    super.key,
  });

  /// What the row is about.
  final String label;

  /// The row's value, as text.
  final String value;

  /// The colour of [value]; Ink when null.
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: EmberSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: EmberType.body.copyWith(color: colors.inkSecondary),
            ),
          ),
          const SizedBox(width: EmberSpace.lg),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: EmberType.body.copyWith(color: valueColor ?? colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
