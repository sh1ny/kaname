import 'package:flutter/widgets.dart';

/// Keys that name the quick search's parts, so tests and focus code can find
/// them.
abstract final class QuickSearchKeys {
  /// The search field.
  static const Key field = Key('quickSearch.field');

  /// The button that opens the full-width search on narrow windows.
  static const Key openButton = Key('quickSearch.open');

  /// The button that closes the full-width search.
  static const Key closeButton = Key('quickSearch.close');

  /// The panel under the field: results, or the reason there are none.
  static const Key panel = Key('quickSearch.panel');

  /// The "Static data not loaded yet" message.
  static const Key notLoaded = Key('quickSearch.notLoaded');

  /// The notice that the app needs an update.
  static const Key notice = Key('quickSearch.notice');

  /// The result at [index], counting from 0.
  static Key result(int index) => Key('quickSearch.result.$index');
}
