/// How wide the window is, which decides the shell's regions.
///
/// Wider than [wideAbove] is wide; wider than [mediumAbove] and up to that is
/// medium; anything at or below [mediumAbove] is narrow (spec: app-shell →
/// the three window-size requirements).
enum ShellBreakpoint {
  /// More than 1080 logical pixels: rail, sidebar and a docked inspector.
  wide,

  /// 761 to 1080: rail and sidebar, with the inspector as an overlay sheet.
  medium,

  /// 760 or less: bottom bar, with the sidebar as a drawer.
  narrow;

  /// The widest a medium window gets.
  static const double wideAbove = 1080;

  /// The widest a narrow window gets.
  static const double mediumAbove = 760;

  /// The breakpoint for a window [width] in logical pixels.
  static ShellBreakpoint of(double width) => switch (width) {
    > wideAbove => wide,
    > mediumAbove => medium,
    _ => narrow,
  };

  /// Whether the inspector is shown as an overlay sheet.
  bool get inspectorIsSheet => this != wide;
}
