/// Native platforms have no browser history.
library;

import 'browser_history.dart';

/// The browser history of this platform: none.
BrowserHistory? createPlatformBrowserHistory() => null;
