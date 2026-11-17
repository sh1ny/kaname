import 'package:flutter/widgets.dart';

/// Keys that name the shell's controls, so tests and focus code can find them.
abstract final class ShellKeys {
  /// The top bar's inspector toggle.
  static const Key inspectorToggle = Key('shell.inspectorToggle');

  /// The inspector's own close control.
  static const Key inspectorClose = Key('shell.inspectorClose');

  /// The narrow top bar's sidebar drawer toggle.
  static const Key drawerToggle = Key('shell.drawerToggle');

  /// The scrim behind the inspector sheet.
  static const Key inspectorScrim = Key('shell.inspectorScrim');

  /// The scrim behind the sidebar drawer.
  static const Key drawerScrim = Key('shell.drawerScrim');

  /// The focus scope of the main column, the fallback when focus loses its
  /// opener.
  static const Key mainFocus = Key('shell.mainFocus');

  /// The rail item of the slot with [id].
  static Key rail(String id) => Key('shell.rail.$id');

  /// The bottom-bar item of the slot with [id].
  static Key bar(String id) => Key('shell.bar.$id');
}
