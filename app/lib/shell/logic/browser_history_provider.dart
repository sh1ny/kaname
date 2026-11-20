/// The browser history the shell steps back through.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/browser_history.dart';

/// The platform's browser history; null where there is none (native
/// platforms). Tests override it with a fake.
final browserHistoryProvider = Provider<BrowserHistory?>(
  (ref) => createPlatformBrowserHistory(),
);
