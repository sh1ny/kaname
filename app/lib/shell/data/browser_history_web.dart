/// The web platform's browser history.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'browser_history.dart';

/// The browser history of this platform: the page's `window.history`.
BrowserHistory? createPlatformBrowserHistory() => _WindowHistory();

final class _WindowHistory implements BrowserHistory {
  _WindowHistory() : loadedOnTaggedEntry = _tagged(web.window.history.state);

  @override
  void back() => web.window.history.back();

  /// The key of the tag in the entry's state, beside the Flutter engine's
  /// own keys, which it reads by name and so leaves this one alone.
  static const _tagKey = 'kanameTag';

  @override
  final bool loadedOnTaggedEntry;

  static bool _tagged(JSAny? state) => switch (state.dartify()) {
    {_tagKey: true} => true,
    _ => false,
  };

  @override
  void tagCurrentEntry() {
    final history = web.window.history;
    if (history.state.dartify() case final Map<Object?, Object?> state) {
      history.replaceState({...state, _tagKey: true}.jsify(), '');
    }
  }
}
