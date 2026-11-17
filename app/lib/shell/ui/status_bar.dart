import 'package:flutter/material.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

/// The 28px status bar across the bottom of the window.
///
/// It holds [trailing] at its right end: a slot that later groups fill (the
/// server indicator).
class ShellStatusBar extends StatelessWidget {
  /// Creates the status bar.
  const ShellStatusBar({this.trailing, super.key});

  /// What to show at the right end, if anything.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.canvas,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: SizedBox(
        height: EmberSize.statusBar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: EmberSpace.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [?trailing],
          ),
        ),
      ),
    );
  }
}
