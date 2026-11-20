/// The browser's session history, where the app has one.
library;

export 'browser_history_io.dart'
    if (dart.library.js_interop) 'browser_history_web.dart';

/// Steps the browser's session history.
abstract interface class BrowserHistory {
  /// Goes back one entry, as the browser's own Back button does. The router
  /// learns of the new location from the browser afterwards.
  void back();

  /// Whether the page loaded on an entry carrying the tag of
  /// [tagCurrentEntry]: one reopened by a reload, or by Back or Forward from
  /// another site. It is read when the history is created, before the
  /// router's first report replaces the entry's state and so its tag.
  bool get loadedOnTaggedEntry;

  /// Tags the current entry as one the app made for itself. The tag stays
  /// with the entry until the router replaces it.
  void tagCurrentEntry();
}
