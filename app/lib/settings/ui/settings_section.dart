import 'package:flutter/material.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

/// A titled Settings section: a heading over a Shelf panel holding [children].
class SettingsSection extends StatelessWidget {
  /// Creates a section named [title] around [children].
  const SettingsSection({
    required this.title,
    required this.children,
    super.key,
  });

  /// The section's heading.
  final String title;

  /// The section's content, stacked with a 14px gap.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: EmberType.uiHeading.copyWith(color: colors.ink),
          ),
        ),
        const SizedBox(height: EmberSpace.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.panel,
            border: Border.all(color: colors.hairline),
            borderRadius: BorderRadius.circular(EmberRadius.l),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}
