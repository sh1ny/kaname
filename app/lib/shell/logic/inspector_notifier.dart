import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Owns whether the inspector is open (`true`) or closed.
///
/// The state lives here, not in a widget, so a change between the docked and
/// the overlay inspector re-renders the same open or closed inspector instead
/// of resetting it. It is the sole writer of that state.
class InspectorNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Opens the inspector.
  void open() => state = true;

  /// Closes the inspector.
  void close() => state = false;

  /// Opens the inspector when closed, closes it when open.
  void toggle() => state = !state;
}

/// The inspector's open state.
final inspectorProvider = NotifierProvider<InspectorNotifier, bool>(
  InspectorNotifier.new,
);
