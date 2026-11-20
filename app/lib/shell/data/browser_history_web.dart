/// The web platform's browser history.
library;

import 'package:web/web.dart' as web;

import 'browser_history.dart';

/// The browser history of this platform: the page's `window.history`.
BrowserHistory? createPlatformBrowserHistory() => const _WindowHistory();

final class _WindowHistory implements BrowserHistory {
  const _WindowHistory();

  @override
  void back() => web.window.history.back();
}
