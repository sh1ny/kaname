/// The browser's session history, where the app has one.
library;

export 'browser_history_io.dart'
    if (dart.library.js_interop) 'browser_history_web.dart';

/// Steps the browser's session history.
abstract interface class BrowserHistory {
  /// Goes back one entry, as the browser's own Back button does. The router
  /// learns of the new location from the browser afterwards.
  void back();

  /// Whether this page load reopened an entry already in the history, by a
  /// reload or by Back or Forward from another page, rather than navigating
  /// to a new one.
  bool get pageRestored;
}
