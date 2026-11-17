import 'package:flutter/widgets.dart';

import 'shell_keys.dart';

/// The main column: the current destination, which the frame mounts once and
/// keeps mounted across breakpoints and panel changes.
///
/// It owns the focus node the frame falls back to when an opener is gone.
class ShellMain extends StatelessWidget {
  /// Creates the main column around [child].
  const ShellMain({required this.focusNode, required this.child, super.key});

  /// The column's focus node, the focus fallback.
  final FocusNode focusNode;

  /// The destination's navigator.
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
    key: ShellKeys.mainFocus,
    focusNode: focusNode,
    skipTraversal: true,
    child: child,
  );
}
